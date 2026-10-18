#!/bin/bash
# Kustomize: both environments running at once, from one base.
#
# Run from the kustomize/ directory, after applying both overlays.
set -eu

echo "WORKLOADS"
kubectl get deploy -A -l app.kubernetes.io/name=task-tracker -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image --no-headers

echo
echo "SERVICES"
kubectl get svc -A -l app.kubernetes.io/name=task-tracker -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,NODEPORT:.spec.ports[0].nodePort --no-headers

echo
echo "ENVIRONMENT LABEL (applied by the overlay, not written in the base)"
kubectl get deploy -A -l app.kubernetes.io/name=task-tracker -o custom-columns=NAMESPACE:.metadata.namespace,ENV:.metadata.labels.app\\.kubernetes\\.io/environment --no-headers | sort -u

echo
echo "DEV through its NodePort, from the host"
printf '  GET http://localhost:30080/            -> HTTP %s\n' "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:30080/)"

echo
echo "DEV backend, through the ClusterIP Service inside the cluster"
kubectl exec -n dso202-a3-dev deploy/frontend -- curl -s http://backend-svc:8080/api/status
echo

echo
echo "PROD backend, in its own namespace, with its own database"
kubectl exec -n dso202-a3-prod deploy/frontend -- curl -s http://backend-svc:8080/api/status
echo

echo
echo "Both releases run the same images from the same base. Only the overlay"
echo "differs: namespace, replica count, Service type and config."
