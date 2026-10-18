#!/bin/bash
# Helm: value-level validation, before a single object reaches the cluster.
#
# Run from the helm/ directory. Two mechanisms are at work and they cover
# different things: "required" enforces PRESENCE, and values.schema.json
# enforces TYPE and PERMITTED VALUES.
set -eu
show() { printf '  %s\n' "$("$@" 2>&1 | grep -vE '^$|^Use --debug' | head -5)"; }

echo "1. required - render with no environment chosen"
helm template tt ./task-tracker 2>&1 | grep -m1 'Error:' | sed 's/^/   /'
echo "   Rendering stopped with the chart author's own message. Note the file"
echo "   named is a template that INCLUDED the helper, not the helper itself,"
echo "   so the message identifies the cause, not the location."

echo
echo "2. helm lint on the same chart, with no values at all"
helm lint ./task-tracker >/tmp/a3-lint.txt 2>&1; echo "   exit code: $?"
printf '   %s warning line(s), all identical:\n' "$(grep -c 'missing required' /tmp/a3-lint.txt | tr -d ' ')"
grep -m1 'missing required' /tmp/a3-lint.txt | sed 's/^/   /'
grep -m1 'chart(s) linted' /tmp/a3-lint.txt | sed 's/^/   /'
echo "   lint reports a missing required value as a WARNING and still exits 0."
echo "   A pipeline that runs only helm lint would pass this chart."

echo
echo "3. schema - three violations reported at once"
helm template tt ./task-tracker -f environments/dev.yaml --set backend.replicaCount=0 --set frontend.service.type=LoadBalancer --set config.environment=test 2>&1 | grep -E "^- at" | sed 's/^/   /'

echo
echo "4. schema - an unquoted image tag silently becomes a number"
printf 'backend:\n  tag: 1.30\n' > /tmp/a3-tag-float.yaml
echo "   values file contains:  tag: 1.30   (YAML parses this as the float 1.3)"
helm template tt ./task-tracker -f environments/dev.yaml -f /tmp/a3-tag-float.yaml 2>&1 | grep -E "^- at" | sed 's/^/   /'
echo "   Without the schema this renders as nginx:1.3 and fails only in the"
echo "   cluster, as ImagePullBackOff."

echo
echo "5. the committed values files pass every check"
for e in dev prod; do
  helm lint ./task-tracker -f environments/$e.yaml >/dev/null 2>&1 && helm template tt-$e ./task-tracker -f environments/$e.yaml >/dev/null 2>&1 && echo "   $e: lint ok, template ok"
done
