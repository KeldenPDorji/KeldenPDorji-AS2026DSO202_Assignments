#!/bin/bash
# Task 4: writes secrets-plain/{dev,staging}.env with random values and prints
# nothing, so no credential reaches the terminal, a screenshot or shell history.
# DB_* and POSTGRES_* carry matching values; dev and staging differ.
set -eu
umask 077; mkdir -p secrets-plain
for e in dev staging; do
  u="task_$e"; p="$(openssl rand -hex 16)"
  printf 'DB_USER=%s\nDB_PASSWORD=%s\nPOSTGRES_USER=%s\nPOSTGRES_PASSWORD=%s\n' "$u" "$p" "$u" "$p" > "secrets-plain/$e.env"
done
ls -l secrets-plain | tail -n +2 | awk '{print $1,$NF}'
