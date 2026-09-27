#!/bin/bash
# 2.2 - one Ingress, one host, two Services, routed by URL path.
#
# Every request below goes to the SAME host and port. Only the path differs,
# and that alone decides which Service answers - which is Layer 7 routing, and
# the thing a NodePort or a LoadBalancer Service cannot do.
set -eu
NS=dso202-assignment-02
HOST=tasktracker.local

echo "===== the Ingress object, as the controller resolved it ====="
kubectl describe ingress task-tracker-ingress -n "$NS" | sed -n '/^Rules:/,/^Annotations:/p'

echo "===== the controller that serves it (a different namespace entirely) ====="
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o wide --no-headers
kubectl get ingressclass --no-headers

echo
echo "===== path / -> frontend-svc:8080 ====="
curl -s -o /dev/null -w 'HTTP %{http_code}  served %{size_download} bytes of HTML\n' "http://$HOST/"

echo "===== path /api/status -> backend-svc:8080 ====="
curl -s "http://$HOST/api/status"; echo

echo "===== path /api/tasks -> backend-svc:8080 ====="
curl -s "http://$HOST/api/tasks" | jq -c '.[] | {id, title, status}'

echo
echo "===== TLS termination: the same host over HTTPS ====="
curl -sk -o /dev/null -w 'HTTP %{http_code} over %{http_version} / TLS\n' "https://$HOST/api/status"
echo | openssl s_client -connect "$HOST:443" -servername "$HOST" 2>/dev/null | openssl x509 -noout -subject -dates

echo
echo "===== no NodePort exists anywhere in this namespace ====="
kubectl get svc -n "$NS" -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,NODEPORT:.spec.ports[0].nodePort
kubectl get resourcequota dso202-quota -n "$NS" -o jsonpath='quota services.nodeports = {.status.used.services\.nodeports} used / {.status.hard.services\.nodeports} hard{"\n"}'
