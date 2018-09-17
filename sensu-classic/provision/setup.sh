############################################
#            Sensu Classic Sandbox         #
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

  if [ ! -z ${ENABLE_SENSU_SANDBOX_PORT_FORWRDING+x} ]; then
    echo "ENABLE_SENSU_SANDBOX_PORT_FORWRDING=${ENABLE_SENSU_SANDBOX_PORT_FORWRDING}" >> $HOME/.vagrant_env
  fi
fi



if [ -f $HOME/.vagrant_env ] ; then
  source $HOME/.vagrant_env
  echo "Using saved provisioning state:"
  echo "ENABLE_SENSU_SANDBOX_PORT_FORWRDING=${ENABLE_SENSU_SANDBOX_PORT_FORWRDING}"
  echo "SE_USER=${SE_USER}" 
  echo "SE_PASS=${SE_PASS}"
fi

# Set up Sensu's repository
if [ -z ${SE_USER+x} ]; then 
  VERSION="Classic Core"
  VER="CC"
  echo "Preparing Sensu Classic Core Sandbox"
else
  VERSION="Classic Enterprise"
  VER="CE"
  echo "Preparing Sensu Classic Enterprise Sandbox"

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
[[ "$(rpm -qa | grep epel-release)" ]] || rpm -Uvh https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm

# Import GPG keys
cd /tmp

curl -s -O https://repos.influxdata.com/influxdb.key
curl -s -O https://packagecloud.io/gpg.key
curl -s -O https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
cp influxdb.key gpg.key RPM-GPG-KEY-grafana /etc/pki/rpm-gpg/

systemctl stop firewalld
systemctl disable firewalld

# Install Needed Yum Packages
yum install -q -y ca-certificates sensu curl jq nc vim ntp redis influxdb grafana nagios-plugins-ssh


cd $HOME
cp /vagrant_files/.bash_profile /home/vagrant/
if [ -z ${SE_USER+x} ]; then 
  # If Core:
  # Install Sensu and Uchiwa
  echo "Installing Sensu Classic Core"
  echo 'export PS1="sensu_CC_sandbox $ "' >> /home/vagrant/.bash_profile
  yum install -q -y uchiwa 
else
  # If Enterprise
  # install Sensu and Dashboard
  echo "Installing Sensu Classic Enterprise"
  echo 'export PS1="sensu_CE_sandbox $ "' >> /home/vagrant/.bash_profile
  yum install -q -y sensu-enterprise sensu-enterprise-dashboard
fi

# Update Redis "bind" and "protected-mode" configs to allow external connections
sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis.conf
sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis.conf

# Set grafana to port 4000 to not conflict with uchiwa dashboard
sed -i 's/^;http_port = 3000/http_port = 4000/' /etc/grafana/grafana.ini

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

# Copy Grafana configs
cp -r /vagrant_files/etc/grafana/* /etc/grafana/
chown -R grafana:grafana /etc/grafana
chown -R grafana:grafana /var/lib/grafana

## Set up InfluxDB configuration to enable Graphite API endpoint
rm /etc/influxdb/influxdb.conf
cp /vagrant_files/etc/influxdb/influxdb.conf /etc/influxdb/influxdb.conf

# Going to do some general setup stuff

#Start up redis 
sudo systemctl restart redis.service
sudo systemctl enable redis.service

# Flush redis
redis-cli FLUSHALL

if [ -z ${SE_USER+x} ]; then 
  sudo systemctl restart sensu-{server,api}.service
  sudo systemctl enable sensu-{server,api}.service
  sudo systemctl restart uchiwa
  sudo chkconfig uchiwa on
else
  systemctl restart sensu-enterprise
  systemctl enable sensu-enterprise
  systemctl restart sensu-enterprise-dashboard
  systemctl enable sensu-enterprise-dashboard
fi

systemctl restart influxdb
systemctl enable influxdb 
systemctl restart grafana-server
systemctl enable grafana-server

# Create the InfluxDB database
influx -execute "DROP DATABASE sensu;"
influx -execute "CREATE DATABASE sensu;"

# Create two Grafana dashboards
curl -s -XPOST -H 'Content-Type: application/json' -d@/vagrant_files/etc/grafana/cc-dashboard-http.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db
curl -s -XPOST -H 'Content-Type: application/json' -d@/vagrant_files/etc/grafana/cc-dashboard-disk.json HTTP://admin:admin@127.0.0.1:4000/api/dashboards/db

echo -e "================="
echo "Sensu $VERSION is now up and running!"
if [ -z ${ENABLE_SENSU_SANDBOX_PORT_FORWRDING+x} ]; then 
echo "Port forwarding from the VM to this host is disabled:"
echo "  Access the dashboard at http://${IPADDR}:3000"
echo "  Access Grafana at http://${IPADDR}:4000"
else 
echo "Port forwarding from the VM to this host is enabled:"
echo "  Access the dashboard at http://localhost:3000"
echo "  Access Grafana at http://localhost:4000"
fi
echo "================="


