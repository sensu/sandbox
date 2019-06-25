# Sensu Go Docker sandbox

The Sensu Go Docker sandbox helps learn the basics of Sensu and monitor a web server.
This sandbox uses Docker to deploy a basic Sensu stack:

- a **Sensu backend**
- (commented out) a **Sensu agent** with the `webserver` subscription
- the **Nginx** web server that we'll be monitoring
- **InfluxDB** to store metrics
- **Grafana** for visualization

To download the sandbox, clone the repository:

```
git clone https://github.com/sensu/sandbox && cd sandbox/sensu-go-docker
```

To deploy the sandbox, run:

```
docker-compose up -d
```

To connect to the sandbox using sensuctl:

```
sensuctl configure -n \
--username 'admin' \
--password 'P@ssw0rd!' \
--namespace default \
--url 'http://localhost:8080'
```

See the Sensu docs to install the [sensuctl command-line tool](https://docs.sensu.io/sensu-go/latest/installation/install-sensu/#install-sensuctl) and get started with step-by-step [guides](https://docs.sensu.io/sensu-go/latest/guides).
