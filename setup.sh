#!/bin/bash

set -euo pipefail

scriptDir=$(dirname -- "$( readlink -f -- "$0"; )";)

fetchKubeconfig() {
	namespace=$1
	name=$2
	updateHost=$3
	outFile=$4
	kubeConfig=${5:-"${HOME}/.kube/config"}

    while ! KUBECONFIG=$kubeConfig kubectl get secret -n $namespace $2 ; do
    	echo "waiting for vcluster secret..."
    	sleep 10
	done

	KUBECONFIG=$kubeConfig kubectl get secret -n $namespace $2 -o jsonpath='{.data.config}' | \
    	base64 -d | \
    	sed 's|https://localhost:8443|https://'"$3"':8443|g' > \
    	$outFile
}

checkBins() {
	if ! command -v kubectl &> /dev/null
	then
	    echo "kubectl could not be found, byeoooo!"
	    exit
	fi

	if ! command -v k3d &> /dev/null
	then
	    echo "k3d could not be found, byeoooo!"
	    exit
	fi

	if ! command -v vcluster &> /dev/null
	then
	    echo "vcluster could not be found, byeoooo!"
	    exit
	fi

	if ! command -v helm &> /dev/null
	then
	    echo "helm could not be found, byeoooo!"
	    exit
	fi
}

checkHosts() {
	hostsContent=$(cat /etc/hosts)

	failed=false

	if ! grep -E -q '127\.0\.0\.1\s+vcluster-0-ha.loft.local' <<< "$hostsContent"
	then
		echo "missing host entry for vcluster-0-ha.loft.local"
		failed=true
	fi

	if ! grep -E -q '127\.0\.0\.1\s+my-vcluster\.loft\.local' <<< "$hostsContent"
	then
		echo "missing host entry for my-vcluster.loft.local"
		failed=true
	fi

	if ! grep -E -q '127\.0\.0\.1\s+vcluster-1\.loft\.local' <<< "$hostsContent"
	then
		echo "missing host entry for vcluster-1.loft.local"
		failed=true
	fi

	if ! grep -E -q '127\.0\.0\.1\s+app\.loft\.local' <<< "$hostsContent"
	then
		echo "missing host entry for app.loft.local"
		failed=true
	fi

	if $failed
	then
		echo "missing one or more host entries, to run this demo you'll need entries in /etc/hosts that look like:"
		echo ""
		echo "127.0.0.1 vcluster-0-ha.loft.local
127.0.0.1 my-vcluster.loft.local
127.0.0.1 vcluster-1.loft.local
127.0.0.1 app.loft.local"
		echo ""
		exit 1
	fi
}

checkHosts

startK3s() {
	echo "starting k3s cluster..."

	k3d cluster create local --servers 5 \
		--k3s-arg --disable="traefik@server:0;server:1;server:2;server:3;server:4" \
		-p 8080:80@loadbalancer -p 8443:443@loadbalancer \
		--wait

	echo "k3s cluster started!"

	echo "warming images..."

	docker pull nginx && k3d image import -c local nginx
	docker pull ghcr.io/carlmontanari/echo-env && k3d image import -c local ghcr.io/carlmontanari/echo-env
	docker pull ghcr.io/carlmontanari/vcluster-plugin/prefer-parent-resources && k3d image import -c local ghcr.io/carlmontanari/vcluster-plugin/prefer-parent-resources

	echo "images warmed up!"
}

startNginx() {
	echo "installing nginx ingress..."

	helm upgrade --install ingress-nginx ingress-nginx \
		--create-namespace \
		--repo https://kubernetes.github.io/ingress-nginx \
		--namespace nginx --version 4.4.0 \
		-f $scriptDir/bootstrap/ingress/values.yaml

	echo "waiting for nginx ingress controller to be happy..."

	kubectl wait --namespace nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s

	echo "nginx ingress is looking good!"
}

startOuterVcluster () {
	echo "starting outer/ha vcluster..."

	vcluster create vcluster-0-ha \
		--namespace demo \
		--create-namespace \
		--connect=false \
		--update-current=false \
		--distro k8s \
		-f bootstrap/vcluster_0_ha/values.yaml

	echo "getting outer/ha vcluster kubeconfig ready..."

	fetchKubeconfig demo vc-vcluster-0-ha vcluster-0-ha.loft.local $scriptDir/kubeconfigs/vcluster-0-ha

	echo "outer/ha vcluster ready!"
}

startVcluster1() {
	echo "create vcluster-1"

	KUBECONFIG=$scriptDir/kubeconfigs/vcluster-0-ha vcluster create vcluster-1 \
		--namespace vcluster1 \
		--create-namespace \
		--connect=false \
		--update-current=false \
		--distro k0s \
		-f bootstrap/vcluster_1/values.yaml

	echo "getting vcluster-1 kubeconfig ready..."

	fetchKubeconfig vcluster1 vc-vcluster-1 vcluster-1.loft.local \
		$scriptDir/kubeconfigs/vcluster-1 $scriptDir/kubeconfigs/vcluster-0-ha

	echo "vcluster-1 ready!"
}

checkBins

# cleanup any previous kubeconfigs
rm kubeconfigs/* || true

startK3s

startNginx

startOuterVcluster

startVcluster1
