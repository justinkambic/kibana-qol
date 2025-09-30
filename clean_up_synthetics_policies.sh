#!/bin/zsh

if [[ -z "$API_KEY" || -z "$KIBANA_BASEPATH" ]]; then
  echo "Error: API_KEY and KIBANA_BASEPATH must be set in the environment." >&2
  exit 1
fi

PAGE=1
PER_PAGE=1
DELETED=0

while :; do
  ARGS="?page=$PAGE&perPage=$PER_PAGE&kuery=ingest-package-policies.package.name%3A%20synthetics"
  URL="$KIBANA_BASEPATH/api/fleet/package_policies$ARGS"
  echo "Fetching synthetics package policy IDs (page $PAGE)..."

  IDS=($(curl -s -H "Authorization: ApiKey $API_KEY" "$URL" | jq -r '.items[] | .id'))
  COUNT=${#IDS[@]}
  if [[ $COUNT -eq 0 ]]; then
    echo "No more synthetics package policy IDs found on page $PAGE. Done."
    break
  fi

  IDS_JSON=$(printf '"%s",' "${IDS[@]}")
  IDS_JSON="[${IDS_JSON%,}]"

  echo "Deleting package policies on page $PAGE: $IDS_JSON"

  curl -v -X POST "${KIBANA_BASEPATH}/api/fleet/package_policies/delete" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -H "Authorization: ApiKey $API_KEY" \
    -d "{\"force\": true, \"packagePolicyIds\": $IDS_JSON}"

  DELETED=$((DELETED + COUNT))
  PAGE=$((PAGE + 1))
done

echo "Total deleted: $DELETED"

echo "Creating dummy Synthetics param..."
curl -X POST "${KIBANA_BASEPATH}/api/synthetics/params" \
  -H "Authorization: ApiKey ${API_KEY}" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"key": "temp-global-param", "value": "temp-value", "description": "A temp param created to re-trigger the creation of package policies. Feel free to delete this anytime, there will be no bad effects.", "tags": [], "share_across_spaces": true}'

