#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t5
hdr "pod creation order (waves 0,1,2 then PostSync)"; kubectl get pods -n dso202-dev --sort-by=.metadata.creationTimestamp -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp,PHASE:.status.phase --no-headers
hdr "smoke test"; kubectl get job -n dso202-dev --no-headers | awk '{print $1,$2,$3}'; echo "log: $(kubectl logs job/tasktracker-smoke-test -n dso202-dev | jq -c 'length as $n | "\($n) tasks returned from the database"' 2>/dev/null)"
hdr "dev"; argocd app get tasktracker-dev 2>&1 | grep -E '^(Project|Target|Sync Policy|Sync Status|Health Status)'
hdr "staging before first sync"; argocd app get tasktracker-staging 2>&1 | grep -E '^(Target|Sync Policy|Sync Status|Health Status)'
hdr "root before first staging sync"; appstate root
