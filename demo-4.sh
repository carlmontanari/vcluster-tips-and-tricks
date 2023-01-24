#!/bin/bash

# demo 4: high availability

. demo-magic.sh
clear


## check out some ha vcluster values, nothing too crazy, enable ha, scale up some replicas
## and you're off!
pe "cat bootstrap/vcluster_0_ha/values.yaml | yq"

## lets take a peak at a deployed ha vcluster...
pe "kubectl get pods -n demo"

## hey... waiiiiit a minute, theres a lot of stuff going on here... and... a lot of it looks
## suspiciously familiar... sure we can see the ha vcluster bits (3x etcd, 3x everything),
## but we can also see our demo app, and my-vcluster-2?!?!

## you have been bamboozled! aall the previous demos have lived in this one big vcluster!
## which in turn is living in the "actual" k3s cluster that was described. notice how we used
## the sync all nodes feature to sync our five "real" k3s nodes into the vcluster, and then
## further down into the original vcluster (vcluster-1) that we first started out wiht!

## we can do normal vcluster things from the actual finally real cluster
pe "vcluster list"

## popping out to the full cluster, we can see we've been using this vcluster all along!
## you can see the nginx controller that we've been using for all of our ingresses and
## all the other vclusters we left in place.
pe "kubectl get pods -A"

p ""