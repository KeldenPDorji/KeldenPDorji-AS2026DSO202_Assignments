#!/bin/bash
# 2.1 - ordinal identity, ordered creation, per-ordinal storage, stable DNS.
#
# Scales the database StatefulSet from 1 to 3 to exercise the mechanics the
# single-replica application does not by itself exhibit. The extra ordinals are
# independent empty PostgreSQL instances, not replicas of db-0 - 2.1.9 is
# explicit that a StatefulSet supplies identity, not replication. What is being
# demonstrated is Kubernetes behaviour, not database clustering.
set -eu
NS=dso202-assignment-02

echo "===== before: one ordinal ====="
kubectl get statefulset db -n "$NS" -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,SERVICE:.spec.serviceName --no-headers
kubectl get pods -n "$NS" -l tier=database -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --no-headers

echo
echo "===== scale to 3 ====="
kubectl scale statefulset db -n "$NS" --replicas=3
kubectl rollout status statefulset/db -n "$NS" --timeout=900s

echo
echo "===== ordinal names, not random suffixes ====="
kubectl get pods -n "$NS" -l tier=database -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName,AGE:.metadata.creationTimestamp

echo
echo "===== creation was ORDERED: 0, then 1, then 2 ====="
echo "(podManagementPolicy: OrderedReady - ordinal N+1 is not created until N is Ready)"
kubectl get events -n "$NS" --field-selector reason=SuccessfulCreate --sort-by=.metadata.creationTimestamp -o custom-columns=TIME:.metadata.creationTimestamp,OBJECT:.involvedObject.name,MESSAGE:.message --no-headers | grep 'StatefulSet db'

echo
echo "===== one PVC PER ORDINAL, generated from volumeClaimTemplates ====="
echo "(named <template>-<pod>, so data-db-0 always belongs to db-0)"
kubectl get pvc -n "$NS" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,VOLUME:.spec.volumeName

echo
echo "===== stable per-ordinal DNS, resolved from inside the backend Pod ====="
for i in 0 1 2; do
  printf 'db-%s.db-headless -> ' "$i"
  kubectl exec -n "$NS" deploy/backend -- getent hosts "db-$i.db-headless" | awk '{print $1}'
done

echo
echo "Each name resolves to exactly one Pod IP. The headless Service publishes"
echo "one DNS record per ordinal rather than load-balancing across all three,"
echo "which is why the backend can address db-0 specifically and always get db-0."
