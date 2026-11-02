#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t1
hdr "tools"; echo "docker $(docker version --format '{{.Server.Version}}') | $(kind version | cut -d' ' -f1,2) | kubectl $(kubectl version --client -o json | jq -r .clientVersion.gitVersion) | helm $(helm version --short)"
echo "$(git --version) | argocd $(argocd version --client --short | head -1) | $(kubeseal --version)"
hdr "pinned chart"; helm search repo sealed-secrets/sealed-secrets --versions | awk '$2=="2.20.0"{print "chart "$2" -> controller "$3}'
hdr "first commit"; git log --reverse --format='%h %s' | head -1; git show --stat --format= "$(git rev-list --max-parents=0 HEAD)" | head -1
hdr "helm lint"; for e in dev staging; do echo "$e: $(helm lint charts/tasktracker -f environments/$e/values.yaml 2>&1 | tail -1)"; done
hdr "kinds rendered"; helm template tasktracker charts/tasktracker -f environments/dev/values.yaml | grep '^kind:' | sort | uniq -c
hdr "cluster"; kubectl config current-context; kubectl get nodes --no-headers | awk '{print $1,$2,$5}'
docker ps --filter name=dso202-gitops --format '{{.Names}} {{.Ports}}' | grep 30080
