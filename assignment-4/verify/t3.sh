#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t3
hdr "projects and applications"; kubectl get appproject -n argocd --no-headers | awk '{print $1}' | paste -sd' ' -; apps
hdr "dso202 created by root"; argocd app resources root 2>&1 | awk 'NR==1 || /AppProject/' | cut -c1-90
hdr "dso202 project"; argocd proj get dso202 2>&1 | grep -E '^(Name|Sources|Destinations|Allowed|Denied)' | cut -c1-96
hdr "whitelist vs chart"; diff <(helm template tasktracker charts/tasktracker -f environments/dev/values.yaml | grep '^kind:' | awk '{print $2}' | sort -u) <(kubectl get appproject dso202 -n argocd -o json | jq -r '.spec.namespaceResourceWhitelist[].kind' | sort -u) && echo "identical: the whitelist names exactly the kinds the chart renders"
