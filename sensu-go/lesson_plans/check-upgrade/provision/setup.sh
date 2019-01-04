#!/bin/bash

PLAN=${SANDBOX_LESSON:unknown}
echo "Provisiong $PLAN Lesson Plan:"
echo "  ...Adding additional packages"
yum -y install tree nagios-plugins-ssh


echo "  ...Copying $PLAN /etc/sensu/"
cp -r /lesson_plans/$PLAN/files/etc/sensu/* /etc/sensu/

rm -rf /home/vagrant/sensu_configs_fixed
cp -r /lesson_plans/$PLAN/files/sensu_configs_fixed /home/vagrant/

echo " ...Starting up $PLAN services"
systemctl restart sensu-agent

