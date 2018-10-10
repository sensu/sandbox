############################################
#               Sensu Sandbox              #
############################################
#              !!!WARNING!!!               #
#         NOT FOR PRODUCTION USE           #
############################################
IPS=$(hostname -I)
IPADDR=$( echo ${IPS[0]} | sed 's/^[ \t]*//;s/[ \t]*$//')

# Clean stale provision data
rm -f /var/lib/grafana/grafana.db
rm -rf /var/lib/grafana/sessions/*
rm -rf /etc/sensu/*

cp /vagrant_files/etc/yum.repos.d/sensu-core.repo /etc/yum.repos.d/sensu-core.repo

if [ ! -f $HOME/.vagrant_env ] ; then
  echo "storing vagrant env state"
  touch $HOME/.vagrant_env
  if [ ! -z ${SE_USER+x} ]; then 
    echo "SE_USER=${SE_USER}" >> $HOME/.vagrant_env
  fi
  if [ ! -z ${SE_PASS+x} ]; then 
    echo "SE_PASS=${SE_PASS}" >> $HOME/.vagrant_env
  fi

  if [ ! -z ${ENABLE_SENSU_SANDBOX_PORT_FORWARDING+x} ]; then
    echo "ENABLE_SENSU_SANDBOX_PORT_FORWARDING=${ENABLE_SENSU_SANDBOX_PORT_FORWARDING}" >> $HOME/.vagrant_env
  fi
fi



if [ -f $HOME/.vagrant_env ] ; then
  source $HOME/.vagrant_env
  echo "Using saved provisioning state:"
  echo "ENABLE_SENSU_SANDBOX_PORT_FORWARDING=${ENABLE_SENSU_SANDBOX_PORT_FORWARDING}"
  echo "SE_USER=${SE_USER}" 
  echo "SE_PASS=${SE_PASS}"
fi

# Set up Sensu's repository
if [ -z ${SE_USER+x} ]; then 
  hostnamectl set-hostname sensu-core-sandbox
  HOSTNAME=`hostname`
  VERSION="Core"
  VER="Core"
  echo "Preparing Sensu Core Sandbox"
else
  hostnamectl set-hostname sensu-enterprise-sandbox
  HOSTNAME=`hostname`
  VERSION="Enterprise"
  VER="Ent"
  echo "Preparing Sensu Enterprise Sandbox"
echo "Hostname: $HOSTNAME"

# Add the Sensu Enterprise YUM repository
echo "[sensu-enterprise]
name=sensu-enterprise
baseurl=http://$SE_USER:$SE_PASS@enterprise.sensuapp.com/yum/noarch/
gpgcheck=0
enabled=1" | tee /etc/yum.repos.d/sensu-enterprise.repo

# Add the Sensu Enterprise Dashboard YUM repository
echo "[sensu-enterprise-dashboard]
name=sensu-enterprise-dashboard
baseurl=http://$SE_USER:$SE_PASS@enterprise.sensuapp.com/yum/\$basearch/
gpgcheck=0
enabled=1" | tee /etc/yum.repos.d/sensu-enterprise-dashboard.repo

fi

# Add the InfluxDB YUM repository
cp /vagrant_files/etc/yum.repos.d/influxdb.repo /etc/yum.repos.d/influxdb.repo

# Add the Grafana YUM repository
cp /vagrant_files/etc/yum.repos.d/grafana.repo /etc/yum.repos.d/grafana.repo

# Add the EPEL repositories (for installing Redis)
echo "Adding EPEL package repository"
[[ "$(rpm -qa | grep epel-release)" ]] || rpm -Uvh https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm

# Import GPG keys
echo "Importing GPG keys for package signatures"
rpm --import https://repos.influxdata.com/influxdb.key
rpm --import https://packagecloud.io/gpg.key
rpm --import https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7

systemctl stop firewalld
systemctl disable firewalld

# Install Needed Yum Packages
echo "Installing needed rpm packages with yum"
yum install -q -y ca-certificates curl jq nano nc vim ntp redis influxdb grafana nagios-plugins-ssh
yum groupinstall -q -y "Development Tools"
yum install -q -y https://dl.bintray.com/rabbitmq/rabbitmq-server-rpm/rabbitmq-server-3.6.12-1.el7.noarch.rpm


cd $HOME
cp /vagrant_files/.bash_profile /home/vagrant/
if [ -z ${SE_USER+x} ]; then 
  # If Core:
  # Install Sensu and Uchiwa
  echo "Installing Sensu Core"
  echo 'export PS1="\[\e[33m\][\[\e[m\]\[\e[31m\]sensu_core_sandbox\[\e[m\]\[\e[33m\]]\[\e[m\]\\$ "' >> /home/vagrant/.bash_profile
  yum install -q -y sensu uchiwa 
else

  # If Enterprise
  # install Sensu and Dashboard
  echo "Installing Sensu Enterprise"
  echo 'export PS1="\[\e[33m\][\[\e[m\]\[\e[31m\]sensu_enterprise_sandbox\[\e[m\]\[\e[33m\]]\[\e[m\]\\$ "' >> /home/vagrant/.bash_profile
  yum install -q -y sensu sensu-enterprise sensu-enterprise-dashboard
fi


# Set grafana to port 4000 to not conflict with uchiwa dashboard
sed -i 's/^;http_port = 3000/http_port = 4000/' /etc/grafana/grafana.ini

echo "Configuring Sensu"
# Copy Base Sensu configuration files
cp -r /vagrant_files/etc/sensu/* /etc/sensu/
cd /etc/sensu/conf.d
mkdir -p {checks,filters,mutators,handlers,templates}

# Copy Lesson specific configs.
if [ -z ${SANDBOX_LESSON+x} ]; then 
  echo "Using Base Sensu ${VER} Sandbox provisioning"
else
  echo "Using Sensu ${VER} Sandbox Lesson ${SANDBOX_LESSON} provisioning"
fi

# General Clean up of Sensu configuration 
chown -R sensu:sensu /etc/sensu

echo "Configuring services"
# Going to do some general setup stuff

# Update Redis "bind" and "protected-mode" configs to allow external connections
sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis.conf
sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis.conf

# Copy Grafana configs
cp -r /vagrant_files/etc/grafana/* /etc/grafana/
chown -R grafana:grafana /etc/grafana
chown -R grafana:grafana /var/lib/grafana

## Set up InfluxDB configuration to enable Graphite API endpoint
rm /etc/influxdb/influxdb.conf
cp /vagrant_files/etc/influxdb/influxdb.conf /etc/influxdb/influxdb.conf

# Start up rabbitmq services
systemctl start rabbitmq-server
systemctl enable rabbitmq-server 

# reset rabbit
rabbitmqctl stop_app
rabbitmqctl reset    # Be sure you really want to do this!
rabbitmqctl start_app

# Add rabbitmq vhost configurations
rabbitmqctl add_vhost /sensu
rabbitmqctl add_user sensu secret
rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"

#Start up redis 
systemctl restart redis.service
systemctl enable redis.service

# Flush redis
redis-cli FLUSHALL

systemctl restart influxdb
systemctl enable influxdb 
systemctl restart grafana-server
systemctl enable grafana-server

echo "Creating InfluxDB database"
# Create the InfluxDB database
influx -execute "DROP DATABASE sensu;"
influx -execute "CREATE DATABASE sensu;"

echo "Creating Grafana dashboards"
# Create two Grafana dashboards
if [ -z ${SE_USER+x} ]; then 
  curl -s -XPOST -H 'Content-Type: application/json' -d@/vagrant_files/etc/grafana/cc-dashboard-http.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db
  curl -s -XPOST -H 'Content-Type: application/json' -d@/vagrant_files/etc/grafana/cc-dashboard-disk.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db
else
  curl -s -XPOST -H 'Content-Type: application/json' -d@/vagrant_files/etc/grafana/ce-dashboard-http.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db
  curl -s -XPOST -H 'Content-Type: application/json' -d@/vagrant_files/etc/grafana/ce-dashboard-disk.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db
fi

echo "Starting Sensu Services"
if [ -z ${SE_USER+x} ]; then 
  systemctl restart sensu-{server,api}.service
  systemctl enable sensu-{server,api}.service
  systemctl restart uchiwa
  chkconfig uchiwa on
else
  systemctl restart sensu-enterprise
  systemctl enable sensu-enterprise
  systemctl restart sensu-enterprise-dashboard
  systemctl enable sensu-enterprise-dashboard
fi



echo -e "================="
echo "Sensu $VERSION is now up and running!"
if [ -z ${ENABLE_SENSU_SANDBOX_PORT_FORWARDING+x} ]; then 
echo "Port forwarding from the VM to this host is disabled:"
echo "  Access the dashboard at http://${IPADDR}:3000"
echo "  Access Grafana at http://${IPADDR}:4000"
else 
echo "Port forwarding from the VM to this host is enabled:"
echo "  Access the dashboard at http://localhost:3000"
echo "  Access Grafana at http://localhost:4000"
fi
echo "================="


