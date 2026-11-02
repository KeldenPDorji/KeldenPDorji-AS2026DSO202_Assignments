#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t2
hdr "render checks"; kubectl kustomize bootstrap/argocd | grep -E '^kind: (Deployment|StatefulSet)$' | sort | uniq -c
kubectl kustomize bootstrap/argocd | grep 'image:' | sort -u | sed 's/^ *image: /  /'
hdr "pods"; kubectl get pods -n argocd --no-headers | awk '{print $1,$2,$3}'
hdr "crds"; kubectl get crd | grep argoproj.io | awk '{print $1}'
hdr "argocd-cm"; kubectl get configmap argocd-cm -n argocd -o yaml | grep -E '^  (timeout.reconciliation|accounts.reviewer)'
hdr "version"; argocd version --short 2>&1 | head -2
