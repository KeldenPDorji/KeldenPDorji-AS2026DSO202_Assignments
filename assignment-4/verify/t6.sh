#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap "t6-$1"
R() { argocd --argocd-context reviewer "$@" 2>&1; }
if [ "$1" = before ]; then hdr "accounts"; argocd account list 2>&1
hdr "reviewer sees"; R app list -o name
hdr "reviewer permissions"
echo "get applications: $(R account can-i get applications 'dso202/tasktracker-dev' | tail -1)"
echo "sync applications: $(R account can-i sync applications 'dso202/tasktracker-dev' | tail -1)"
echo "get logs: $(R account can-i get logs 'dso202/tasktracker-dev' | tail -1)"
echo "proj get platform: $(R proj get platform | tail -1 | grep -oE 'PermissionDenied[^,]*,[^,]*,[^,]*' )"
else hdr "after enabling the logs rule by commit"; git log --oneline -1 -- bootstrap/argocd/argocd-rbac-cm-patch.yaml; grep -n 'p, reviewer' bootstrap/argocd/argocd-rbac-cm-patch.yaml
echo "get logs: $(R account can-i get logs 'dso202/tasktracker-dev' | tail -1)"; fi
