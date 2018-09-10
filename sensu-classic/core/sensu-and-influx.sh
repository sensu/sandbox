############################################
#            Sensu Core Sandbox            #
############################################
#              !!!WARNING!!!               #
#         NOT FOR PRODUCTION USE           #
############################################

#!/bin/sh
IPADDR=$(/sbin/ip -o -4 addr list enp0s8  | awk '{print $4}' | cut -d/ -f1)

# Make sure we have all the package repos we need!
sudo yum install epel-release nano vi yum-utils openssl httpd -y
sudo yum groupinstall 'Development Tools' -y

# Set up zero-dependency erlang
echo ' [rabbitmq-erlang]
name=rabbitmq-erlang
baseurl=https://dl.bintray.com/rabbitmq/rpm/erlang/20/el/7
gpgcheck=1
gpgkey=https://www.rabbitmq.com/rabbitmq-release-signing-key.asc
repo_gpgcheck=0
enabled=1' | sudo tee /etc/yum.repos.d/rabbitmq-erlang.repo
sudo yum install erlang -y

# Install rabbitmq
sudo yum install https://dl.bintray.com/rabbitmq/rabbitmq-server-rpm/rabbitmq-server-3.6.12-1.el7.noarch.rpm -y

# Set up Sensu's repository
echo '[sensu]
name=sensu
baseurl="https://repositories.sensuapp.org/yum/$releasever/$basearch/"
gpgcheck=0
enabled=1' | sudo tee /etc/yum.repos.d/sensu.repo

# Add the InfluxDB YUM repository
echo '[influxdb]
name = InfluxDB Repository - RHEL $releasever
baseurl = https://repos.influxdata.com/rhel/$releasever/$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key' | tee /etc/yum.repos.d/influxdb.repo

# Add the Grafana YUM repository
echo '[grafana]
name=grafana
baseurl=https://packagecloud.io/grafana/stable/el/7/$basearch
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt' | tee /etc/yum.repos.d/grafana.repo

# Install Redis
sudo yum install redis influxdb grafana -y
systemctl stop firewalld
systemctl disable firewalld

# Install Sensu and Uchiwa
sudo yum install sensu uchiwa -y

# Provide minimal transport configuration (used by client, server and API)
echo '{
  "transport": {
    "name": "rabbitmq"
  }
}' | sudo tee /etc/sensu/transport.json

# Move Grafana to port 4000
sed -i 's/^;http_port = 3000/http_port = 4000/' /etc/grafana/grafana.ini

# Ensure config file permissions are correct and set up Grafana configuration
sudo chown -R sensu:sensu /etc/sensu
cp -r /vagrant/files/grafana/* /etc/grafana/
chown -R grafana:grafana /etc/grafana

# Set up InfluxDB configuration to enable Graphite API endpoint
rm /etc/influxdb/influxdb.conf
cp /vagrant/files/influxdb/influxdb.conf /etc/influxdb/influxdb.conf

# Install more tools
sudo yum install curl jq -y

# Provide Minimal uchiwa conifguration, pointing at API on localhost

echo '{
  "sensu": [
    {
      "name": "sensu-core-sandbox",
      "host": "127.0.0.1",
      "port": 4567
    }
  ],
  "uchiwa": {
    "host": "0.0.0.0",
    "port": 3000
  }
 }' |sudo tee /etc/sensu/uchiwa.json

# Configure Sensu to use rabbitmq

echo '{
  "rabbitmq": {
    "host": "127.0.0.1",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "secret",
    "heartbeat": 30,
    "prefetch": 50
  }
}' | sudo tee /etc/sensu/conf.d/rabbitmq.json

# Configure minimal Redis configuration for Sensu

echo '{
  "redis": {
    "host": "127.0.0.1",
    "port": 6379
  }
}' | sudo tee /etc/sensu/conf.d/redis.json

# Start up rabbitmq services
sudo systemctl start rabbitmq-server

# Add rabbitmq vhost configurations
sudo rabbitmqctl add_vhost /sensu
sudo rabbitmqctl add_user sensu secret
sudo rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"

# Going to do some general setup stuff
cd /etc/sensu/conf.d
mkdir {checks,filters,mutators,handlers,templates}

#Start up other services
sudo systemctl start sensu-{server,api}.service
sudo systemctl start redis.service
sudo systemctl start uchiwa
sudo systemctl enable uchiwa
sudo systemctl enable redis.service
sudo systemctl enable rabbitmq-server
sudo systemctl enable sensu-{server,api}.service
systemctl start influxdb
chkconfig influxdb on
systemctl start grafana-server
systemctl enable grafana-server.service

# Create the InfluxDB database
influx -execute "CREATE DATABASE sensu;"

# Create two Grafana dashboards
curl -XPOST -H 'Content-Type: application/json' -d@/vagrant/files/grafana/dashboard-http.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db
curl -XPOST -H 'Content-Type: application/json' -d@/vagrant/files/grafana/dashboard-disk.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db

echo -e "=================
Sensu is now up and running!
Access the dashboard at $IPADDR:3000
Access Grafana at $IPADDR:4000
================="
