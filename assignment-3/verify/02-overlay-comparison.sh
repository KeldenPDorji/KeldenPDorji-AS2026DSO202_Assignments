#!/bin/bash
# Kustomize: one base, two environments, rendered locally.
#
# Run from the kustomize/ directory. Nothing is sent to the cluster here. This
# is the "render first" habit: the rendered YAML is the truth, so debug what an
# overlay RENDERS rather than reading the overlay alone.
set -eu
mkdir -p ../outputs
kubectl kustomize overlays/dev  > ../outputs/rendered-dev.yaml
kubectl kustomize overlays/prod > ../outputs/rendered-prod.yaml
ruby ../verify/render-fields.rb < ../outputs/rendered-dev.yaml  > /tmp/a3-dev.txt
ruby ../verify/render-fields.rb < ../outputs/rendered-prod.yaml > /tmp/a3-prod.txt
g() { grep -m1 "^$1=" "$2" | cut -d= -f2- ; }
row() { printf '  %-20s %-30s %s\n' "$1" "$(g "$2" /tmp/a3-dev.txt)" "$(g "$2" /tmp/a3-prod.txt)"; }

echo "THIN OVERLAYS: differences are stated, resources are not copied"
printf '  %-20s %s lines\n' "base resources" "$(cat base/*/*.yaml base/kustomization.yaml | wc -l | tr -d ' ')"
printf '  %-20s %s lines\n' "dev overlay" "$(cat overlays/dev/*.yaml | wc -l | tr -d ' ')"
printf '  %-20s %s lines\n' "prod overlay" "$(cat overlays/prod/*.yaml | wc -l | tr -d ' ')"
printf '  %-20s %s patch docs, %s contain an image: field (a copied Deployment would)\n' "overlay Deployments" \
  "$(grep -l '^kind: Deployment' overlays/*/*.yaml | wc -l | tr -d ' ')" \
  "$(grep -l '^kind: Deployment' overlays/*/*.yaml | xargs grep -l 'image:' 2>/dev/null | wc -l | tr -d ' ')"

echo
printf '  %-20s %-30s %s\n' "" "dev" "prod"
row "objects"            objects
row "namespace"          namespace
row "ConfigMap"          configmap.name
row "Secret"             secret.name
row "CORS_ORIGIN"        CORS_ORIGIN
row "BACKEND_URL"        BACKEND_URL
row "frontend Service"   frontend.type
row "frontend nodePort"  frontend.nodePort
row "frontend annotation" frontend.annotation
row "replicas backend"   replicas.backend
row "replicas frontend"  replicas.frontend
row "replicas database"  replicas.database
row "backend cpu limit"  cpulimit.backend
row "backend image"      image.backend

echo
echo "Secret hash is identical: its content never differed between environments."
echo "ConfigMap hash differs:   prod merged two keys, so the content differs."
echo "nodePort is absent in prod: removed by the JSON 6902 patch, because the"
echo "API server rejects a ClusterIP Service that still carries one."
