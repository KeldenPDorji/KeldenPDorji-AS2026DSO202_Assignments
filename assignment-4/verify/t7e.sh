#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t7e
BAD=$(cat "$A4/outputs/bad-sha.txt")
hdr "pull requests"; gh pr list --state merged --limit 20 --json number,title --jq '.[] | "#\(.number) \(.title)"' | sort -t'#' -k2 -n
hdr "graph"; git log --oneline --graph --decorate -n 15 | cut -c1-84
hdr "staging history"; argocd app history tasktracker-staging 2>&1 | grep -v "^SOURCE" | cut -c1-80
hdr "dev history"; argocd app history tasktracker-dev 2>&1 | tail -4 | cut -c1-80
hdr "staging never ran the faulty commit"; if kubectl get application tasktracker-staging -n argocd -o json | jq -e --arg b "$BAD" '[.status.history[].revision] | index($b)' >/dev/null; then echo "FOUND ${BAD:0:7}"; else echo "${BAD:0:7} is absent from the staging history"; fi
