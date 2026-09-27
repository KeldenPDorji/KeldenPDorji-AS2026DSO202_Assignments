#!/bin/bash
# 2.4 - what a CRD does, and the thing it conspicuously does not do.
#
# 2.4.9 names the single most common misconception about the Operator pattern:
# that installing a CRD gives you functionality. It does not. A CRD teaches the
# API server a new TYPE. Acting on instances of that type requires a controller,
# and writing one is outside Unit II's scope (2.4.7). This script demonstrates
# both halves.
set -eu
NS=dso202-assignment-02
CRD=tasktrackerbackups.tasktracker.dso202.io

echo "===== 0. start from a clean slate ====="
kubectl delete crd "$CRD" --ignore-not-found --wait=true
echo "(deleting the CRD also deletes every CR of that type)"

echo
echo "===== 1. a CR created BEFORE its CRD is rejected (2.4.9) ====="
kubectl apply -f crd/nightly-backup-cr.yaml 2>&1 | head -3 || true
echo "  The API server has no schema registered for this kind, so it cannot"
echo "  store the object at all."

echo
echo "===== 2. install the CRD ====="
kubectl apply -f crd/tasktrackerbackup-crd.yaml
kubectl wait --for=condition=Established crd/"$CRD" --timeout=120s

echo
echo "===== 3. the new type is now a first-class API resource ====="
kubectl api-resources --api-group=tasktracker.dso202.io

echo
echo "===== 4. the same CR is now accepted ====="
kubectl apply -f crd/nightly-backup-cr.yaml
kubectl get tasktrackerbackups -n "$NS"
echo "  The SCHEDULE and TARGET columns come from additionalPrinterColumns in"
echo "  the CRD, so the custom type reads like a built-in one."

echo
echo "===== 5. schema validation is enforced by the API server ====="
echo "  retentionDays has minimum: 1, maximum: 365. Attempting 9999:"
kubectl patch tasktrackerbackup nightly-db-backup -n "$NS" --type=merge -p '{"spec":{"retentionDays":9999}}' 2>&1 | head -3 || true
echo "  Rejected by the CRD's own openAPIV3Schema - no controller involved."

echo
echo "===== 6. and yet NOTHING has happened ====="
echo "  status subresource (a controller would write here):"
kubectl get tasktrackerbackup nightly-db-backup -n "$NS" -o jsonpath='{.status}' ; echo "  <- empty"
echo "  PHASE column:"
kubectl get tasktrackerbackup nightly-db-backup -n "$NS" -o jsonpath='[{.status.phase}]{"\n"}'
echo "  Jobs or CronJobs created to perform the backup:"
kubectl get jobs,cronjobs -n "$NS" 2>&1 | tail -1
echo "  Events on the object:"
kubectl describe tasktrackerbackup nightly-db-backup -n "$NS" | tail -2

echo
echo "The object is stored, validated, and queryable. No backup exists, and none"
echo "ever will, because no controller is watching this type. A CRD defines a"
echo "noun; an Operator is the running process that gives the noun meaning."
