#!/usr/bin/env bash

set -euo pipefail

BASEDIR=$(dirname "$0")

if [ "$#" -lt 2 ]; then
  echo "We need at least 2 parameters for the script - kubernetes namespace, helm release name and optional custom NFS config type "
fi

TARGET_NAMESPACE=$1
PRODUCT_RELEASE_NAME=$2
CUSTOM_NFS_SERVER_TYPE=$3
[ "$CUSTOM_NFS_SERVER_TYPE" ] && CUSTOM_NFS_CONFIG="-$CUSTOM_NFS_SERVER_TYPE"

ARCH_EXAMPLE_DIR="$BASEDIR/../../../reference-infrastructure"
NFS_SERVER_YAML="${ARCH_EXAMPLE_DIR}/storage/nfs/nfs-server${CUSTOM_NFS_CONFIG}.yaml"

echo Deleting old NFS resources...
kubectl delete -f $NFS_SERVER_YAML --ignore-not-found=true || true

echo Starting NFS deployment...
sed -e "s/test-nfs-server/$PRODUCT_RELEASE_NAME-nfs-server/" $NFS_SERVER_YAML | kubectl apply -n "${TARGET_NAMESPACE}" -f -

echo Waiting until the NFS deployment is ready...
pod_role="$PRODUCT_RELEASE_NAME-nfs-server"
echo Pod role is [$pod_role]
pod_name=$(kubectl get pod -n "${TARGET_NAMESPACE}" -l role=$pod_role -o jsonpath="{.items[0].metadata.name}")
echo Pod name is [$pod_name]
kubectl wait --for=condition=ready pod -n "${TARGET_NAMESPACE}" "${pod_name}" --timeout=60s

echo Waiting for the container to stabilise...
while ! kubectl exec -n "${TARGET_NAMESPACE}" "${pod_name}" -- ps -o cmd | grep 'mountd' | grep -q '/usr/sbin/rpc.mountd -N 2 -V 3'; do
  sleep 1
done

echo NFS server is up and running.
