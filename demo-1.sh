#!/bin/bash

# demo 1: basics

source helper.sh

. demo-magic.sh
clear

## get nodes to show we are connected to our nice little multi-node k3s cluster
p "kubectl get nodes"
KUBECONFIG=kubeconfigs/vcluster-1 kubectl get nodes

## nothing exciting here, a blank k3s cluster basically
p "kubectl get pods -A"
KUBECONFIG=kubeconfigs/vcluster-1 kubectl get pods -A

## create a vcluster; because we are using a "remote" cluster (k3s vs kind/docker-desktop/minikube)
## vcluster would normally setup port-forwarding and keep our terminal hostage which we don't want
## for the demo, so we'll also set up an ingress; this is something you would probably need to do
## in most cases where you are not running kind/docker-desktop/minikube anyway!
p "vcluster create my-vcluster \\
	--namespace my-vcluster \\
	--create-namespace \\
	--connect=false \\
	-f bootstrap/my-vcluster/values.yaml"
KUBECONFIG=kubeconfigs/vcluster-1 vcluster create my-vcluster \
	--namespace my-vcluster \
	--connect=false \
	-f bootstrap/my-vcluster/values.yaml

## we can watch our vcluster to wait till we see it is ready
doUntil "vcluster list" "KUBECONFIG=kubeconfigs/vcluster-1 vcluster list" 'my-vcluster\s+my-vcluster\s+Running'

## make sure our ingress grabs a public ip/is happy so we know we can reach the vcluster api server
doUntil "kubectl get ingress -n my-vcluster" "KUBECONFIG=kubeconfigs/vcluster-1 kubectl get ingress -n my-vcluster" 'my-vcluster.loft.local\s+\d+\.\d+\.\d+\.\d+'

## grab a kubeconfig so we can use this fancy new vcluster; note 8443 because of k3s load balancer magic
p "vcluster connect my-vcluster --update-current=false --server=https://my-vcluster.loft.local:8443"
KUBECONFIG=kubeconfigs/vcluster-1 vcluster connect my-vcluster \
	--update-current=false --server=https://my-vcluster.loft.local:8443

pe "cat kubeconfig.yaml"

## use the new kubeconfig to list nodes and pods in the vcluster
pe "KUBECONFIG=kubeconfig.yaml kubectl get nodes"
pe "KUBECONFIG=kubeconfig.yaml kubectl get pods -A"

## create a simple nginx deployment to demo that the vcluster is just a normal little cluster!
pe "KUBECONFIG=kubeconfig.yaml kubectl create namespace nginx"
pe "KUBECONFIG=kubeconfig.yaml kubectl create deployment nginx --image=nginx --replicas=2 -n nginx"

## hey look ma, pods!
doUntil "KUBECONFIG=kubeconfig.yaml kubectl get pods -n nginx" "KUBECONFIG=kubeconfig.yaml kubectl get pods -n nginx" 'nginx-.+\s+1\/1\s+Running'

## now we can check in the host cluster and see that they show up w/ translated names and such
p "kubectl get pods -n my-vcluster"
KUBECONFIG=kubeconfigs/vcluster-1 kubectl get pods -n my-vcluster

p ""