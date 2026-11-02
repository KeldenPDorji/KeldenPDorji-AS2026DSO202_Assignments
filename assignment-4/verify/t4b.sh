#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t4b
hdr "committed credential files are ciphertext"; for e in dev staging; do echo "$e: kind=$(awk '/^kind:/{print $2}' platform/$e/tasktracker-credentials.sealed.yaml), encrypted keys=$(sed -n '/encryptedData:/,/template:/p' platform/$e/tasktracker-credentials.sealed.yaml | grep -c ': Ag')"; done
hdr "history search across all branches (values are never printed)"; for f in secrets-plain/*.env; do while IFS='=' read -r k v; do [ -n "$v" ] || continue; n=$(git log -p --all -S"$v" | wc -l | tr -d ' '); echo "$(basename "$f" .env) $k: $n matching lines"; done < "$f"; done
hdr "ignored by git"; git status --short --ignored | grep -E '^!!' | cut -c1-60
