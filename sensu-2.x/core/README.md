### Welcome to the Sensu 2.x Core sandbox!

This tutorial will get you up and running with Sensu.

- [Set up the sandbox](#set-up-the-sandbox)

Report issues or share feedback by [opening an issue in this repo](https://github.com/sensu/sandbox/issues/new).
---

## Set up the sandbox

**1. Install Vagrant and VirtualBox:**

- [Download Vagrant](https://www.vagrantup.com/downloads.html)
- [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)

**2. Download the sandbox:**

[Download from GitHub](https://github.com/sensu/sandbox/archive/core.zip) or clone the repository:

```
git clone git@github.com:sensu/sandbox.git && cd sandbox/sensu-2.x/core
```

If you downloaded the zip file from GitHub, unzip the folder and move it into your Documents folder.
Then open Terminal and enter `cd Documents` followed by `cd sandbox/sensu-2.x/core`.

**3. Start Vagrant:**

```
ENABLE_SENSU_SANDBOX_PORT_FORWRDING=1 vagrant up
```

This will take around five minutes, so if you haven't already, [read about how Sensu works](https://docs.sensu.io/sensu-core/2.0/).

_NOTE: This will configure VirtualBox to forward a couple of tcp ports from the sandbox VM machine to the localhost to make it easier for you to interact with the Sandbox dashboards. Dashboard links provided below assume port forwarding from the VM to the host is active and reference http://localhost ._

**4. SSH into the sandbox:**

Thanks for waiting! To start using the sandbox:

```
vagrant ssh
```

You should now have shell access to the sandbox and should be greeted with this sandbox prompt:  
```
[sensu_2_core_sandbox]$
```

_NOTE: To exit out of the sandbox, use `CTRL`+`D`.  
Use `vagrant destroy` then `vagrant up` to erase and restart the sandbox.
Use `vagrant provision` to reset sandbox's sensu configuration to the beginning of this lesson_


---

## Explore the sandbox
The Sensu Core sandbox comes pre-installed with Influxdb and Grafana so you can easily work with building metrics pipelines. 
For now head over to the [Sensu 2 Getting Started Guide](https://docs.sensu.io/sensu-core/2.0/getting-started/installation-and-configuration/) and learn how to configure the sensu backend and agent already installed in the sandbox.

Check back here as we get closer to Sensu 2 release, for additional sandbox tutorial content.  
