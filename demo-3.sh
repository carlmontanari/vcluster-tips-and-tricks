#!/bin/bash

# demo 3: init manifests/charts && plugins

source helper.sh

. demo-magic.sh
clear

## Use helm to deploy a vcluster with some init manifests/charts, take a quick peak at the values
## first -- in this case just init manifests, but you can do charts similarily!
pe "cat bootstrap/my-vcluster-2/values.yaml | yq '.init'"

## deploy the vcluster with helm, this will deploy all our goodies with it...
p "helm upgrade --install my-vcluster-2 vcluster \\
    --repo https://charts.loft.sh \\
    --namespace my-vcluster-2 \\
    --create-namespace \\
    --values bootstrap/my-vcluster-2/values.yaml"
KUBECONFIG=kubeconfigs/vcluster-0-ha helm upgrade --install my-vcluster-2 vcluster \
  --repo https://charts.loft.sh \
  --namespace my-vcluster-2 \
  --create-namespace \
  --values bootstrap/my-vcluster-2/values.yaml

## check on our new vcluster as it comes up... we should see our demo app pod in there!
## keen eyes may notice three containers in our pod, don't worry about that third one just yet ;)
## run this until we see our demo app running
doUntil "kubectl get pods -n my-vcluster-2" "KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get pods -n my-vcluster-2" 'demo-app-.+\s+1\/1\s+Running'

## we can see our svc and ingress get synced just like pods too! not only does this show that the svc/ingress
## stuff syncs just like pods, but it also shows our init manifest goodness has done its job!
p "kubectl get svc -n my-vcluster-2"
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get svc -n my-vcluster-2

doUntil "kubectl get ingress -n my-vcluster-2" "KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get ingress -n my-vcluster-2" 'app.loft.local\s+\d+\.\d+\.\d+\.\d+'

## we can now confirm that our app is up and working -- its just a dumb app that returns some
## value from an environment variable...
pe "curl -k https://app.loft.local:8443/demo-app"

## now... plugin time...

## but... where is that string valu ecoming from, lets check it out by looking at the deployment container spec
## fun fact, we can also directly execute commands in the vcluster like this without having
## to have an ingress/node port/port-forwarding -- can be quite handy!
p "vcluster connect my-vcluster-2 -- kubectl get deployments -n demo demo-app -o yaml | yq '.spec.template.spec.containers[0]'"
KUBECONFIG=kubeconfigs/vcluster-0-ha vcluster connect my-vcluster-2 -- kubectl get deployments -n demo demo-app -o yaml | yq '.spec.template.spec.containers[0]'

## ok we see a secret is mounted, lets check out that secret too... but hey, what gives?! shouldn't this say racecar?
p "vcluster connect my-vcluster-2 -- kubectl get secrets -n demo my-secret -o jsonpath='{.data.data}' | base64 -d"
KUBECONFIG=kubeconfigs/vcluster-0-ha vcluster connect my-vcluster-2 -- \
  kubectl get secrets -n demo my-secret -o jsonpath='{.data.data}' | base64 -d
echo ""

## yes... well... no! let's take a peak at the values that this vcluster was deployed with
pe "cat bootstrap/my-vcluster-2/values.yaml | yq '.plugin'"

## and we can see that there is a *third* container in our vcluster pod that we didn't see in
## previous examples (usually its "just" the vcluster (apiserver) and the syncer), now we have
## a plugin container as well.
p "kubectl get pods -n my-vcluster-2 my-vcluster-2-0 -o jsonpath='{.spec.containers[*].name}'"
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get pods -n my-vcluster-2 my-vcluster-2-0 -o jsonpath='{.spec.containers[*].name}'
echo ""

## the "prefer-parent-resources" plugin does what it sounds like: it prefers to mount configmaps/secrets
## from the "parent" cluster (meaning *not* the vcluster). this is a super simple plugin, you could
## obviously get way more advanced! let's see where this "parent" resource is coming from:
p "kubectl get secrets -n my-vcluster-2 my-secret -o jsonpath='{.data.data}' | base64 -d"
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl get secrets -n my-vcluster-2 my-secret -o jsonpath='{.data.data}' | base64 -d
echo ""

## and we can check the logs of the plugin just like any other pod and see what its doin... obviously
## this will be entirely up to the plugin what they log and such, but the point here is its just
## a normal container doin' normal things more or less! in this case we can see where we mutate a pod
## to prefer the configmap from the "real" host.
p "kubectl logs -n my-vcluster-2 my-vcluster-2-0 -c prefer-parent-resources | grep \"mutating pod\""
KUBECONFIG=kubeconfigs/vcluster-0-ha kubectl logs -n my-vcluster-2 my-vcluster-2-0 -c prefer-parent-resources | grep "mutating pod"

p ""