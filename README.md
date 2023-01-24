vcluster tips and tricks demos
==============================

# Purpose

To demo some cool vcluster things!


## Warning

Apologies in advance for horrible down and dirty bash scripts :D


# Setup

To run this, you'll need a machine with `kubectl`, `helm`, `vcluster`, `k3d`, and `docker` ready to go. You'll also need a few entries added to `/etc/hosts` so we can resolve some endpoints in the cluster(s). Those required entries are as follows:

```
127.0.0.1 vcluster-0-ha.loft.local
127.0.0.1 my-vcluster.loft.local
127.0.0.1 vcluster-1.loft.local
127.0.0.1 app.loft.local
```

To get things prepared, simply run `./setup.sh`. This script will make sure you've got the necessary binaries installed, spin up a 5 node k3s cluster, and bootstrap things for the demos.


# Cleanup

Simply run `./cleanup.sh` to destroy the k3s cluster and tidy up local files.


# Demo Scripts

Each demo segment contains a simple script to execute the demo. The script uses [demo magic](https://github.com/paxtonhare/demo-magic) to ensure the demo is repeatable and an audience does not have to suffer through countless typos! You can execute any of the demo scripts by the demo segment number like: `./demo-1.sh` or `./demo-4.sh` -- note that some of the demos build on each other so you should run them from the beginning!

One more note: the demo-magic scripts allow us to "lie" (just a little bit) about the actual commands that are running in the background vs what is being shown in the terminal. Check out the demos before taking a peak at the actual scripts, that way you get the full experience! After that, take a look behind the scenes at the scripts and you can see how demo-magic helped make the demo (hopefully) cooler!


# Demo Segments

## Demo 1 - Basics

This demo shows the basics of using `vcluster` cli to create a virtual cluster and create some basic resources in it. In this demo we start with our fresh "k3s cluster" and check the nodes and pods just to see we are working with a fresh cluster. Next, we use the `vcluster` cli to create a virtual cluster named "my-vcluster" in the namespace "my-vcluster". We provide a values file as we need to set the tls-san for the apiserver to work with the ingress we've asked vcluster to create for us.

We keep tabs on the state of the virtual cluster by running the `vcluster list` command to list all the virtual clusters that the `vcluster` cli is aware of. Once the virtual cluster is up, we can check on the ingress to make sure its grabbed an IP and is up and happy.

With all that out of the way, we can then go ahead and fetch a kubeconfig for the virtual cluster, once again we can do this with the `vcluster` cli. Normally when using the `vcluster connect` command, vcluster will auto update the kubeconfig with the relevant information to talk to your vcluster; in this case we do *not* update the kubeconfig, and we also update the vcluster server endpoint to match that of our ingress. This is mostly for demo purposes, but depending on your use case may be more true to life where you have long running virtual clusters that you connect to through a load balancer or an ingress.

With a working kubeconfig in hand, we can then fetch nodes and pods of the virtual cluster -- not a lot to see here, since its a fresh deployment, but at least we know its working!

Finally, we'll create a new namespace "nginx", and deploy a simple deployment with two nginx pods in it just to see things working. We can check the pods get deployed with `kubectl`, just like normal!

Just like a "normal" kubernetes cluster, just virtual (and way way way faster to spin up)!

The last thing we do here is take a look at what has happened in our host/parent cluster in the "my-vcluster" namespace. We can see the statefulset where our virtual cluster lives, but we can also see the nginx and coredns pods and their translated names show up!


## Demo 2 - Inception

We heard you loved `vcluster`, so we put a virtual cluster in your virtual cluster so you can virtual cluster while virtual clustering!

Probably not super useful for most folks, but it is pretty cool -- we can put virtual clusters *in* virtual clusters. That virtual cluster created in demo 1? Yep, *inside* another virtual cluster. We did a little bit of trickery to sync all the "real" nodes from our k3s cluster into the vcluster (rather than the default only nodes that have pods scheduled on them), but other than that there were no real shenanigans, it just works *TM*.

In this demo we start out by just taking a peak at our nodes again -- everything looks like a normal k3s cluster; but what if we check pods?

Checking the pods, however, reveals something strange?! Ah, yes, you have been lied to you! the virtual cluster created in the previous demo was actually *inside* of the "vcluster-1" virtual cluster! We can use the kubeconfig for vcluster-1 to check the pods that live inside of this vcluster without the rest of the pods in the host cluster. This shows we no longer see the vcluster-1 pod (syncer and k3s apiserver), and more clearly shows our my-vcluster virtual cluster without the name translations going on.

We can go ahead and delete this virtual cluster now since we don't need it; by doing this we also automagically clean up all the resources that were created inside that virtual cluster (our silly nginx demo stuff).

Watching the pods after destroying the virtual cluster we can see things terminating and cleaning up nicely, and we end up with just our "vcluster1", its coredns instance, and the coredns containers for our host cluster. Pretty slick!


## Demo 3 - Init Manifests/Charts && Plugins

Virtual clusters are obviously a pretty cool way to have self contained development or testing environments -- environments that you can easily deploy things into and tidily clean up all in one command. Wouldn't it be neat if we could also "bootstrap" a virtual cluster with some predefined manifests or even helm charts worth of resources? Great news, you can do that!

Here we'll start out by showing the `init` section of a values file we will shortly use to deploy a virtual cluster. Some pretty basic things in here: a deployment, a secret, a service, and an ingress. These resources represent a silly little demo app. This app does one thing: echo the contents of an environment variable, that's it! 

This time around, rather than using the `vcluster` cli to deploy this virtual cluster, we can use `helm`. There isn't a lot different here, at the end of the day virtual clusters are always deployed with `helm` anyway!

We'll keep checking the pods until we see our "demo-app" is up and running as expected. We can also check to make sure the service and ingress are configured as expected. Nothing crazy here, everything looking like expected!

As a final confirmation, we can quickly curl our demo-app to validate things are truly working -- wow, such fancy, it returned a string!

So... that demo was pretty cool (the app thingy) but where is that string coming from (that it echoes)? Let's check the deployment spec to investigate a bit. OK, neat, we can see that the image name, and it says it echos things. We can also see the command that the container is given -- env=SECRET, and we can see a secret mounted as an environment variable called SECRET. This is all pretty clear what is going on!

So, let's check the contents of this secret...

Hmm... that... does not line up! The secret that is mounted in the deployment says one thing, but the app returns something else.

Enter `vcluster` plugins! `vcluster` plugins let us change the default syncing behavior that `vcluster` uses when syncing resources from the virtual cluster into the host cluster. We can check the values that were provided to the `helm` command we deployed this virtual cluster with, specifically the "plugin" section to see whats up.

"prefer-parent-resources", huh, OK, that sounds interesting! Well this plugin is a very simple one that does what it says on the tin! configmaps and secrets that live in the "host" cluster, are always preferred over configmaps/secrets living in the virtual cluster. The idea here is that you can deploy some configmap in a namespace that contains some default settings for an application for example, then, when developers are doing their thing, their deployments will automagically pick up *that* configmap rather than one inside the vcluster.

You may have noticed earlier that this virtual cluster actually has *three* containers rather than the two that we've seen before. If we inspect the names of the containers we can see that, sure enough, a third container "prefer-parent-resources" is running in this pod!

And to bring things full circle, we can check the secret in the host cluster to see what its contents are, and sure enough, that's the string that we've been seeing!

Finally, we can check the logs of the plugin container to see, yes, in fact, this plugin has been mutating our pod.

A trivial example, but hopefully one that shows how flexible and useful vcluster plugins can be!


## Demo 4 - HA

virtual clusters are often used for development or test environments that don't really "need" any sort of high availability. Sometimes, however, you really do want a highly available virtual cluster, and you can do just that with the k8s and k3s distros.

We'll start by taking a quick look at a values file that could be used to deploy an HA vcluster. The most obviously important setting here is of course the "enableHA" setting, but we've also scaled up replicas for all the relevant pods.

Let's check out a deployed HA vcluster... hey... wait a minute what is going on here! Lots of things! Most importantly, you have been bamboozled!!! All the previous demos have been ran *inside* an HA vcluster running on the k3d cluster! This includes the vcluster *inside* the vcluster -- that's three vclusters deep!

We can also see the actual HA bits here -- three etcd pods, three api servers, etc..

If you were curious, the power of the "demo magic" script has allowed us to lie to you! The commands shown in the demos have been legit commands, but not necessarily in the kube context that you may have thought they were being executed in!

Now, with all the deception aside, we can go back to the beginning and list our virtual clusters using the `vcluster` cli, and sure enough see the ha vcluster. Note that even though there are more virtual clusters *inside* the HA virtual cluster, `vcluster` cli is not aware of them as they are simply pods running inside of this outer virtual cluster. If we changed kube contexts we could get `vcluster` to pick those up though if we needed to!

We won't do it in the demo in case there are questions/we want to show anything else, but at this point we could safely destroy the HA vcluster and be left with a pristine k3d cluster! Pretty cool!
