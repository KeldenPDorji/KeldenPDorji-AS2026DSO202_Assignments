#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t4
hdr "applications"; apps
hdr "namespaces"; kubectl get namespaces | grep dso202 | awk '{print $1,$2}'
for e in dev staging; do hdr "$e"; kubectl get sealedsecret -n dso202-$e --no-headers | awk '{print "SealedSecret",$1,"synced="$2}'; kubectl describe secret tasktracker-credentials -n dso202-$e | sed -n '/^Data/,$p' | tail -n +3 | sed 's/^/  /'; kubectl get resourcequota,limitrange -n dso202-$e -o name | paste -sd' ' -; done
hdr "key backup (outside the repo)"; ls -l ../dso202-keys/ | tail -n +2 | awk '{print $1,$NF}'
