### Upgrade Sensu 1.x Check to Sensu Go 

This tutorial will walk you through updated a check from Sensu 1.x to Sensu Go

- [Set up the sandbox](#set-up-the-sandbox)
- [Lesson \#1: Translate Sensu 1.x configs](#lesson-1-translate-sensu-1.x-configs)
- [Lesson \#2: Adjust check spec attributes](#lesson-2-adjust-check-spec-attributes)
- [Lesson \#3: Adjust check token substitution syntax](#lesson-3-adjust-check-token-substitution-syntax)
- [Lesson \#4: Upload the check into Sensu Go](#lesson-4-upload-the-check-into-sensu-go)
- [Lesson \#5: Adjust the Sensu Go agent configuration](#lesson-5-adjust-the-sensu-go-agent-configuration)

Report issues or share feedback by [opening an issue in this repo](https://github.com/sensu/sandbox/issues/new).

---

## Set up the sandbox

**1. Install Vagrant and VirtualBox:**

- [Download Vagrant](https://www.vagrantup.com/downloads.html)
- [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)

**2. Download the sandbox:**

[Download from GitHub](https://github.com/sensu/sandbox/archive/master.zip) then unzip and enter the sensu-go sandbox directory 

```
unzip sandbox-master.zip && cd sandbox-master/sensu-go/core/
```

Or clone the repository:

```
git clone git@github.com:sensu/sandbox.git && cd sandbox/sensu-go/core
```

**3. Start Vagrant:**

```
ENABLE_SENSU_SANDBOX_PORT_FORWARDING=1 vagrant up
```

This may take around five minutes if this is a new sandbox.

_NOTE: This will configure VirtualBox to forward a couple of tcp ports (3002,4002) from the sandbox VM machine to the localhost to make it easier for you to interact with the Sandbox dashboards. Dashboard links provided below assume port forwarding from the VM to the host is active and reference http://localhost._


**4. Provision the the sandbox for this lesson plan**

```
SANDBOX_LESSON=check-upgrade vagrant provision
```

This may a take a couple of minutes if this is the first time this sandbox has been used for the check-update lesson plan.

**5. SSH into the sandbox**

```
vagrant ssh
```

You should now have shell access to the sandbox and should be greeted with this sandbox prompt:  

```
[sensu_go_sandbox]$
```

**6. Make sure Nagios ssh plugin is installed**
```
sudo yum install nagios-plugins-ssh
```

**7. Start the Sensu Agent**
```
sudo systemctl restart sensu-agent
```

_NOTE: To exit out of the sandbox, use `CTRL`+`D`. Use `vagrant destroy` then `vagrant up` to erase and restart the sandbox. Use `SANDBOX_LESSON=check-upgrade vagrant provision` to reset sandbox's sensu configuration to the beginning of this lesson_

_NOTE: To save you a little time we've pre-configured sensuctl in the sandbox to use the Sensu Go admin user with default password as part of sandbox provisioning, so you won't have to configure sensuctl each time you spin up the sandbox to try out a new feature. Before installing sensuctl outside of the sandbox please, please read the [first time setup reference](https://docs.sensu.io/sensu-go/5.0/sensuctl/reference/#first-time-setup) to learn how to configure sensuctl._  

---

## Lesson \#1: Translate Sensu 1.x configs

Find the Sensu Core 1.x `check_ssh_server.json` configuration file installed as part of the lesson plan's Sensu Core 1.x config.

```
[sensu_go_sandbox]$ tree /etc/sensu/conf.d/
/etc/sensu/conf.d/
├── checks
│   ├── check_filtered_ssh_server.json
│   ├── check_http_proxy_request.json
│   ├── check_ssh_server.json
│   └── cpu_percentage.json
├── client.json
├── filter
│   └── workday_filters.json
├── handlers
│   ├── filtered_logevent.json
│   ├── influxdb_tcp.json
│   └── logevent.json
├── influxdb.json
├── logevent.json
├── redis.json
└── transport.json
```

```
[sensu_go_sandbox]$ cat /etc/sensu/conf.d/checks/check_ssh_server.json
{
  "checks": {
    "nagios_check_ssh_server_localhost": {
      "command": "/usr/lib64/nagios/plugins/check_ssh -4 -r :::ssh.version|OpenSSH_7.4::: -P :::ssh.protocol|2.0::: localhost",
      "type" : "metric",
      "handlers": [ "logevent" ],
      "interval": 10,
      "subscribers": ["localhost"],
      "timeout": 15
    }
  }
}
```

Translate the Sensu Core 1.x config located in `/etc/sensu/config.d` into Sensu Go compatible resource json files using `sensu-translator`. The translated config will be created in the `/tmp/sensu_config_translated` directory

```
[sensu_go_sandbox]$ sensu-translator -d /etc/sensu/conf.d -o /tmp/sensu_config_translated

Sensu 1.x filter translation is not yet supported
...
DONE!

```

As expected, filters were not translated — complicated filter logic can’t be automatically translated.

```
[sensu_go_sandbox]$ tree /tmp/sensu_config_translated/
/tmp/sensu_config_translated/
├── checks
│   ├── check-http-proxy-request.json
│   ├── cpu_metrics.json
│   ├── nagios_check_ssh_server_localhost.json
│   ├── nagios_during_office_hours_ssh_server_localhost.json
│   └── nagios_outside_office_hours_ssh_server_localhost.json
├── extensions
├── filters
├── handlers
│   ├── influx-tcp.json
│   ├── logevent.json
│   ├── silence_during_office_hours_logevent.json
│   └── silence_outside_office_hours_logevent.json
└── mutators

```
The example Sensu 1.x configuration defines multiple resources in a single file and the translator creates a separate file for each translated Sensu Go resource.

The translator gets us most of the way for checks and handlers, giving us configuration files that can be uploaded into Sensu Go using the `sensuctl create -f` command. The translator doesn’t yet attempt to translate check token substitution nor extended attributes —  we’ll need to visually inspect and make some adjustments for correct operation.


Let's move to the translated config directory:

```
[sensu_go_sandbox]$ cd /tmp/sensu_config_translated/
```

The translated file we’re interested in now is the nagios_check_ssh_server_localhost.json  check:

```
[sensu_go_sandbox]$ cat nagios_check_ssh_server_localhost.json
{
  "api_version":"core/v2",
  "type":"Check",
  "metadata":{
    "namespace":"default",
    "name":"nagios_check_ssh_server_localhost",
    "labels":{},
    "annotations":{
      "sensu.io.json_attributes":"{\"type\":\"metric\"}"
    }
  },
  "spec":{
    "command":"/usr/lib64/nagios/plugins/check_ssh -4 -r :::ssh.version|OpenSSH_7.4::: -P :::ssh.protocol|1.0::: localhost",
    "subscriptions":[
      "localhost"
    ],
    "publish":true,
    "interval":10,
    "handlers":[
      "logevent"
    ]
      “timeout”:15
  }
}
```



## Lesson \#2: Adjust check spec attributes


The translator stores all check extended attributes in the check metadata annotation named `sensu.io.json_attributes`. In this check, the `type` attribute is no longer part of the Sensu Go check spec, so we’ll need to adjust it by hand. The original check was configured as `type: metric` which told Sensu 1.x to always handle the check regardless of the check status output. This allowed Sensu 1.x to process output metrics via a handler even when the check status was not in an alerting state. Sensu Go treats output metrics as first-class objects, allowing you to process check status as well as output metrics via different event pipelines.  Let’s edit the `nagios_check_ssh_server_localhost.json` and update the spec attributes manually. Here’s the Sensu Go check config snippet with the updated metrics configuration:

```
[sensu_go_sandbox]$ cat nagios_check_ssh_server_localhost.json
...

  "spec":{
...
    "handlers":[
        "logevent"
    ],
    "output_metric_handlers":[
        "influxdb"
    ],
    "output_metric_format": "nagios_perfdata",
    "timeout":15
...
  }
```
The Sensu Go agent will ingest the plaintext metrics included in the output of the check command using the Nagios perfdata format. The resulting metrics will be handled by a handler named `influxdb`.


## Lesson \#3: Adjust check token substitution syntax
The check command still uses the Sensu 1.x check substitution syntax, making reference to Sensu 1.x nested client attributes `ssh.server` and `ssh.protocol` as part of the client JSON config. The Sensu Go agent handles extended attributes differently, allowing you to define a flat set of key value pairs referred to as labels. The Sensu Go check config nagios_check_ssh_server_localhost.json needs to be edited to update the token substitution syntax.
Open the file to edit using `nano`
```
[sensu_go_sandbox]$ nano nagios_check_ssh_server_localhost.json

```

Here’s what the check command looks like after editing.

```
[sensu_go_sandbox]$ cat nagios_check_ssh_server_localhost.json
...
  "spec":{
   "command":"/usr/lib64/nagios/plugins/check_ssh -4 -r {{.labels.ssh_version | default \"OpenSSH_7.4\" }} -P {{.labels.ssh_protocol | default \"1.0\" }} localhost",
...


```

## Lesson \#4: Upload the check into Sensu Go

This check should now be ready to upload into sensuctl.
```
[sensu_go_sandbox]$ sensuctl create -f nagios_check_ssh_server_localhost.json
```

And it should now show up in the list of defined checks

```
[sensu_go_sandbox]$ sensuctl check list
NAME                                   COMMAND
Nagios_check_ssh_server_localhost  /usr/lib64/nagios/plugins/check_ssh ...
```
The check hasn’t been scheduled yet as the Sensu Go agent is not yet subscribed to the localhost subscription.

## Lesson \#5: Adjust the Sensu Go agent configuration
Edit `/etc/sensu/agent.yml` 
```
[sensu_go_sandbox]$ sudo nano /etc/sensu/agent.yml
```

and make sure include the localhost subscription by uncommenting the subscription section and ensuring `localhost` is in the list of subscriptions:

```
##
# agent configuration
##
...
subscriptions:
 - "localhost"
...

```
And restart the agent:
```
[sensu_go_sandbox]$ sudo systemctl restart sensu-agent 
```
Now the check should be firing at 10 second intervals:

```
[sensu_go_sandbox]$ sensuctl event info sensu-go-sandbox   nagios_check_ssh_server_localhost

=== sensu-go-sandbox - nagios_check_ssh_server_localhost
Entity:    sensu-go-sandbox
Check:     nagios_check_ssh_server_localhost
Output:    SSH CRITICAL - OpenSSH_7.4 (protocol 2.0) protocol version mismatch, expected '1.0'
Status:    2
History:   2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
Silenced:  false
...
```
But there’s still a problem: the ssh protocol `2.0` doesn’t match the expected protocol string `1.0`. This can be addressed by setting the ssh_protocol label in the `agent.yml` to the correct expected protocol string.

Edit `/etc/sensu/agent.yml` to include labels:
```
##
# agent configuration
##
...
subscriptions:
 - "localhost"
labels:
  ssh_protocol: "2.0"
  ssh_version: "OpenSSH_7.4" 
...

```
Restart the sensu-agent service again and wait for the check to run. Now the check should be returning a check status of 0.

```
[sensu_go_sandbox]$ sensuctl event info sensu-go-sandbox   nagios_check_ssh_server_localhost
=== sensu-go-sandbox - nagios_check_ssh_server_localhost
Entity:    sensu-go-sandbox
Check:     nagios_check_ssh_server_localhost
Output:    SSH OK - OpenSSH_7.4 (protocol 2.0) | time=0.024728s;;;0.000000;10.000000
Status:    0
History:   2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0
Silenced:  false

...
```

Notice also that the output includes Nagios perfdata. Since we configured the check’s output_metric_format, the Sensu Go agent converts the Nagios perfdata into Sensu’s internal metrics representation and sends it along as part of the Sensu event:
```
[sensu_go_sandbox]$ sensuctl event info sensu-go-sandbox nagios_check_ssh_server_localhost --format json
...
 "metrics": {
    "handlers": [
      "influxdb"
    ],
    "points": [
      {
        "name": "time",
        "value": 0.024728,
        "timestamp": 1545270871,
        "tags": []
      }
    ]
  },
...
```

## Next steps
This walk-through covered the typical considerations as you upgrade existing Sensu 1.x check definitions. If you want to try something more complicated, take a look at the Sensu 1.x `check_http_proxy_request.json` provided as part of this lesson plan and see if you can get the proxy request updated using [the Sensu Go reference documentation](https://docs.sensu.io/sensu-go/latest/).


If you want to set up the InfluxDB handler, you can read [the metrics guide](https://docs.sensu.io/sensu-go/latest/guides/influx-db-metric-handler/), or check out [the Sensu Go sandbox introduction lesson](https://github.com/sensu/sandbox/tree/master/sensu-go/core).



