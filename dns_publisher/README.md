# VCAP dns_publisher
DNS Publisher vcap module.

MIT license

## Usecase
Listen to the router starting and stopping applications.
Denpending on the urls on which the apps are started and stopped take appropriate actions
to broadcast those URLs on the DNS.

The DNS registration is a plugin mechanism.

Currently supported: multi-cast DNS with avahi.

In progress: AWS's route53.

## avahi mDNS plugin
Server's requirements: run on the same machine than the Router; install avahi-daemon and the python bindings.

On ubuntu:

   apt-get avahi-daemon python-avahi


Client's machines that will access those URLs, an mDNS responder must be installed.
- Ubuntu and other linux: out of the box with avahi installed
- Macosx: out of the box with Bonjour
- Windows: need to install bonjour.

Typical usage: all applications deployed on a url that ends with ".local" 
are registered as aliases of the avahi-hostname of the machine.

Please note that on the same local-network, each VM must have a different avahi-hostname to avoid conflicts.

## route53: In progress.
AWS route53 is a dynamic DNS provided by Amazon.
Publishes the apps in a route53 zone as new CNames.

Current state: skeleton code to chat with AWS route53 is committed.
Not using it at the moment in this manner so contact me if you want to collaborate on this.

