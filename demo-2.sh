#!/bin/bash

# demo 1: inception

source helper.sh

. demo-magic.sh
clear

## once again, look, everything looks like a "normal" k3s cluster, but... what if we check the
## pods too!?
p "kubectl get nodes"
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get nodes

## yes, we lied in demo-1! here is our vcluster-1 living in it's parent cluster! we can even
## see the nginx pods from the previous demo with their names translated all crazy (twice! once
## for each vcluster!).
p "kubectl get pods -A"
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get pods -A

## we can also look at just whats "inside" of vcluster 1 itself by setting our context to
## that vcluster. this is basically what we were doing in demo 1, it was just hidden by
## demo magic :)
pe "KUBECONFIG=kubeconfigs/vcluster-1 kubectl get pods -A"

## we can delete the vcluster we created in demo-1... and it automagically will nuke all
## the resources, very nice! we can also show that we were using kubeconfigs with the vcluster
## command to keep our illusion alive!
pe "KUBECONFIG=kubeconfigs/vcluster-1 vcluster delete my-vcluster && rm kubeconfig.yaml"

## the pods may take a few seconds to terminate... we can check the vcluster and our "real"
## physical cluster here.
doUntil "KUBECONFIG=kubeconfigs/vcluster-1 kubectl get pods -A" "KUBECONFIG=kubeconfigs/vcluster-1 kubectl get pods -A" 'my-vcluster\s+my-vcluster-0' "1"

p "kubectl get pods -A"
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get pods -A

p ""

: '
were looking for output like this -- in this case we still see our "vcluster1" vcluster that the
original vcluster from demo 1 was created in, but now our "my-vcluster" has been cleaned up and
is gone, leaving us with our "real" (still lying to viewers about the ha vcluster!) cluster with
just some stuff running in it. keen eyes may ask about coredns, this is replicated because of our
ha vcluster, but we can just say we scaled up that replicaset ;)

---
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get pods -A
NAMESPACE     NAME                                                  READY   STATUS    RESTARTS   AGE
kube-system   coredns-66ffcc6b58-fpfwh                              1/1     Running   0          21m
kube-system   coredns-66ffcc6b58-w5vvm                              1/1     Running   0          21m
kube-system   coredns-66ffcc6b58-zr5ng                              1/1     Running   0          21m
vcluster1     coredns-6b8566fc7f-d78rd-x-kube-system-x-vcluster-1   1/1     Running   0          20m
vcluster1     vcluster-1-0                                          2/2     Running   0          20m

'
