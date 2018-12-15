#!/bin/bash

PLAN=${SANDBOX_LESSON:unknown}
echo "Provisiong $PLAN Lesson Plan:"
echo "  ...Adding additional packages"
yum install tree nagios-plugins-ssh


echo "  ...Copying $PLAN /etc/sensu/"
cp -r /lesson_plans/$PLAN/files/etc/sensu/* /etc/sensu/

echo " ...Starting up $PLAN services"
systemctl restart sensu-agent

