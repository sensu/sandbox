# Sensu Go Docker sandbox

This is a work-in-progress sandbox to help you get started with Sensu Go using Docker.

### Prerequisites
- Docker
- docker-compose
- jq
- curl
- sensuctl

### Setup

Download the sandbox.

Bootstrap our Sensu Go environment with `docker-compose`.

```
$ docker-compose up -d
Creating sensu-go-demo_nginx-server_1  ... done
Creating sensu-go-demo_sensu-backend_1 ... done
Creating sensu-go-demo_influxdb_1      ... done
Creating sensu-go-demo_grafana_1       ... done
Creating sensu-go-demo_influxdb-init_1 ... done
```

_NOTE: You may see some `docker pull` and `docker build` output on your first
run as Docker pulls down our base images and builds a few custom images._

Once `docker-compose` is done standing up our systems we should be able to
log in to the Sensu dashboard at http://localhost:3000 as the default user (username: `admin` and password:
`P@ssw0rd!`)._

![Sensu dashboard login screen](docs/images/login.png "Sensu dashboard login screen")

If you haven't already, install sensuctl.

```
$ sensuctl configure
? Sensu Backend URL: http://localhost:8080
? Username: admin
? Password: P@ssw0rd!
? Organization: default
? Environment: default
? Preferred output format: none
```

## Lesson #1: Create a monitoring event

```
$ sensuctl event list
  Entity   Check   Output   Status   Silenced   Timestamp  
 ──────── ─────── ──────── ──────── ────────── ─────────── 
```

```
$ export SENSU_USER=admin
$ export SENSU_PASS=P@ssw0rd!
```

```
$ export SENSU_TOKEN=`curl -XGET -u "$SENSU_USER:$SENSU_PASS" -s http://localhost:8080/auth | jq -r ".access_token"`
```

Re-run this command whenever you get an `invalid credentials` error from the API.

```
curl -X POST \
-H "Authorization: Bearer $SENSU_TOKEN" \
-H 'Content-Type: application/json' \
-d '{
  "entity": {
    "entity_class": "proxy",
    "metadata": {
      "name": "server1",
      "namespace": "default"
    }
  },
  "check": {
    "metadata": {
      "name": "server-health"
    },
    "output": "Hello world!",
    "state": "passing",
    "status": 0,
    "interval": 60
  }
}' \
http://localhost:8080/api/core/v2/namespaces/default/events | jq .

HTTP/1.1 200 OK
{
  "entity": {
    "entity_class": "proxy",
    "system": {
      "network": {
        "interfaces": null
      }
    },
    "subscriptions": null,
    "last_seen": 0,
    "deregister": false,
    "deregistration": {},
    "metadata": {
      "name": "server1",
      "namespace": "default"
    }
  },
  "check": {
    "handlers": [],
    "high_flap_threshold": 0,
    "interval": 60,
    "low_flap_threshold": 0,
    "publish": false,
    "runtime_assets": null,
    "subscriptions": [],
    "proxy_entity_name": "",
    "check_hooks": null,
    "stdin": false,
    "subdue": null,
    "ttl": 0,
    "timeout": 0,
    "round_robin": false,
    "executed": 0,
    "history": null,
    "issued": 0,
    "output": "Hello world!",
    "state": "passing",
    "status": 0,
    "total_state_change": 0,
    "last_ok": 0,
    "occurrences": 0,
    "occurrences_watermark": 0,
    "output_metric_format": "",
    "output_metric_handlers": null,
    "env_vars": null,
    "metadata": {
      "name": "server-health"
    }
  },
  "metadata": {}
}
```

```
$ sensuctl event list
   Entity         Check          Output      Status   Silenced             Timestamp            
 ─────────── ─────────────── ────────────── ──────── ────────── ─────────────────────────────── 
  server1   server-health   Hello world!        0   false      1969-12-31 16:00:00 -0800 PST  
```

Provide context about the systems we're monitoring with a discovery event

This time, use the entities API to create an event that gives Sensu some extra information about `server1`.

<!-- To do: Add extra info to API request.-->

```
curl -X PUT \
-H "Authorization: Bearer $SENSU_TOKEN" \
-H 'Content-Type: application/json' \
-d '{
    "entity_class": "proxy",
    "metadata": {
      "name": "server1",
      "namespace": "default"
    },
    
}' \
http://127.0.0.1:8080/api/core/v2/namespaces/default/entities/server1
```

Nice work! You're now creating monitoring events with Sensu Enterprise.
In the next lesson, we'll take action on these events by creating a pipeline.

## Lesson #2: Pipe events into Slack

Now that we know the sandbox is working properly, let's get to the fun stuff: creating a pipeline.
In this lesson, we'll create a pipeline to send alerts to Slack.
(If you'd rather not create a Slack account, you can skip ahead to lesson 3.)

Get your Slack webhook URL.

If you're already an admin of a Slack, visit `https://YOUR WORKSPACE NAME HERE.slack.com/services/new/incoming-webhook` and follow the steps to add the Incoming WebHooks integration, choose a channel, and save the settings.
(If you're not yet a Slack admin, start [here](https://slack.com/get-started#create) to create a new workspace.)
After saving, you'll see your webhook URL under Integration Settings.

Register the Sensu Slack handler asset.

```
sensuctl asset create sensu-slack-handler --url "https://github.com/sensu/sensu-slack-handler/releases/download/1.0.3/sensu-slack-handler_1.0.3_linux_amd64.tar.gz" --sha512 "68720865127fbc7c2fe16ca4d7bbf2a187a2df703f4b4acae1c93e8a66556e9079e1270521999b5871473e6c851f51b34097c54fdb8d18eedb7064df9019adc8"
```

```
sensuctl asset list
```

Create a handler to send event data to Slack.

Now we'll use sensuctl to create a handler called `slack` that pipes event data to Slack using the `sensu-slack-handler` asset.
Edit the command below to include your Slack channel and webhook URL.
For more information about customizing your Sensu slack alerts, see the asset page in [Bonsai](bonsai.sensu.io).

```
sensuctl handler create slack \
--type pipe \
--env-vars "SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T0000/B000/XXXXXXXX" \
--command "sensu-slack-handler --channel '#monitoring'" \
--runtime-assets sensu-slack-handler
```

```
sensuctl handler list
```

Pipe event data into Slack with the Sensu API.

Let's use the events API to create an event and send it to our pipeline by adding `"handlers": ["slack"]`.

```
curl -X PUT \
-H "Authorization: Bearer $SENSU_TOKEN" \
-H 'Content-Type: application/json' \
-d '{
  "entity": {
    "entity_class": "proxy",
    "metadata": {
      "name": "server1",
      "namespace": "default"
    }
  },
  "check": {
    "output": "Server error",
    "status": 1,
    "handlers": ["slack"],
    "interval": 60,
    "metadata": {
      "name": "server-health"
    }
  }
}' \
http://127.0.0.1:8080/api/core/v2/namespaces/default/events/server1/server-health
```

Did you get an `invalid credentials` error? Re-run the following command:

```
export SENSU_TOKEN=`curl -XGET -u "$SENSU_USER:$SENSU_PASS" -s http://localhost:8080/auth | jq -r ".access_token"`
```

Check out the Slack channel you configured when creating the webhook, and you should see a message from Sensu.

Let's send another event to resolve the warning:

```
curl -X PUT \
-H "Authorization: Bearer $SENSU_TOKEN" \
-H 'Content-Type: application/json' \
-d '{
  "entity": {
    "entity_class": "proxy",
    "metadata": {
      "name": "server1",
      "namespace": "default"
    }
  },
  "check": {
    "output": "Everything looks good here!",
    "status": 0,
    "handlers": ["slack"],
    "interval": 60,
    "metadata": {
      "name": "server-health"
    }
  }
}' \
http://127.0.0.1:8080/api/core/v2/namespaces/default/events/server1/server-health
```

Add a filter to the pipeline.

## Lesson #3: Automate event production with the Sensu agent

```
$ curl -I http://localhost:8000
HTTP/1.1 200 OK
Server: nginx/1.15.12
Date: Thu, 25 Apr 2019 21:46:24 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 16 Apr 2019 13:08:19 GMT
Connection: keep-alive
ETag: "5cb5d3c3-264"
Accept-Ranges: bytes
```

Create an InfluxDB pipeline

Deploy a Sensu agent

