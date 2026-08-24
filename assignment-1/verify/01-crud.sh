#!/bin/sh
# Task 7a - full CRUD cycle against the backend through a port-forward.
#
# The backend Service is ClusterIP, so it is NOT reachable from the host.
# `kubectl port-forward` opens a temporary tunnel through the API server for
# this demonstration only; it creates no NodePort and no cluster-wide exposure.
#
# Usage:  terminal A -> kubectl port-forward -n dso202-assignment-01 svc/backend-svc 8080:8080
#         terminal B -> ./verify/01-crud.sh
set -eu
API="http://localhost:8080/api/tasks"

echo "===== C : POST ${API} ====="
NEW=$(curl -s -X POST "$API" -H 'Content-Type: application/json' \
  -d '{"title":"Persistence probe","description":"Created before the backend Pod is deleted"}')
echo "$NEW" | jq .
ID=$(echo "$NEW" | jq -r .id)

echo
echo "===== R : GET ${API} ====="
curl -s "$API" | jq -c '.[] | {id, title, status}'

echo
echo "===== U : PUT ${API}/${ID}  (status -> done) ====="
curl -s -X PUT "$API/$ID" -H 'Content-Type: application/json' \
  -d '{"title":"Persistence probe","description":"Created before the backend Pod is deleted","status":"done"}' | jq .

echo
echo "===== D : DELETE ${API}/${ID} ====="
curl -s -o /dev/null -w 'HTTP %{http_code}\n' -X DELETE "$API/$ID"

echo
echo "===== R : GET ${API}  (id ${ID} is gone) ====="
curl -s "$API" | jq -c '.[] | {id, title, status}'
