#!/bin/bash

set -euo pipefail

k3d cluster delete local

# cleanup any previous kubeconfigs
rm kubeconfigs/* || true
rm kubeconfig.yaml || true
