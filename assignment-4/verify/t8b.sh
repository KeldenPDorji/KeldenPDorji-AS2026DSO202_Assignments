#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t8b
hdr "drill 3: prediction: deleting the file from Git deletes the ConfigMap from the cluster"
cp "$A4/verify/drill-prune.yaml" platform/dev/prune-drill.yaml; git add platform/dev/prune-drill.yaml; git commit -qm "Drill 3: add prune-drill ConfigMap"; git push -q origin main; refresh platform-dev
kubectl wait --for=create configmap/prune-drill -n dso202-dev --timeout=180s >/dev/null; kubectl get configmap prune-drill -n dso202-dev --no-headers | awk '{print "present:",$1}'
git rm -q platform/dev/prune-drill.yaml; git commit -qm "Drill 3: remove prune-drill ConfigMap"; git push -q origin main; refresh platform-dev
kubectl wait --for=delete configmap/prune-drill -n dso202-dev --timeout=180s >/dev/null; kubectl get configmap prune-drill -n dso202-dev 2>&1 | tail -1 | cut -c1-70
hdr "drill 4: prediction: project dso202 refuses the ResourceQuota, and staging is unaffected"
cp "$A4/verify/drill-quota.yaml" charts/tasktracker/templates/drill-quota.yaml; git add charts/tasktracker/templates/drill-quota.yaml; git commit -qm "Drill 4: add ResourceQuota to the chart"; git push -q origin main; BAD=$(git rev-parse HEAD); refresh tasktracker-dev
kubectl wait --for=jsonpath="{.status.sync.revision}=$BAD" application/tasktracker-dev -n argocd --timeout=180s >/dev/null
kubectl wait --for=jsonpath='{.status.sync.status}=OutOfSync' application/tasktracker-dev -n argocd --timeout=120s >/dev/null
until kubectl get application tasktracker-dev -n argocd -o jsonpath='{.status.operationState.message}' | grep -q 'not permitted'; do :; done
appstate tasktracker-dev; echo "message: $(kubectl get application tasktracker-dev -n argocd -o jsonpath='{.status.operationState.message}' | sed 's/ Retrying.*//' | cut -c1-96)"
appstate tasktracker-staging; echo "drill-quota in cluster: $(kubectl get resourcequota drill-quota -n dso202-dev --no-headers 2>/dev/null | wc -l | tr -d ' ')"
git revert --no-edit "$BAD" >/dev/null; git push -q origin main; H=$(git rev-parse HEAD); refresh tasktracker-dev; wait_rev tasktracker-dev "$H" 900s; wait_app tasktracker-dev 900s
hdr "restored by git revert"; git log --oneline -1 | cut -c1-70; appstate tasktracker-dev
