#!/bin/zsh

# Defaults
KIBANA_URL="http://localhost:5601"
USER="elastic"
PASS="changeme"
TITLE="fewawfea"
DESCRIPTION="fwea"
SEVERITY="low"
OWNER="observability"
COUNT=1   # default 1 case

# Parse args
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --url)
      KIBANA_URL="$2"
      shift; shift
      ;;
    --user)
      USER="$2"
      shift; shift
      ;;
    --pass)
      PASS="$2"
      shift; shift
      ;;
    --title)
      TITLE="$2"
      shift; shift
      ;;
    --description)
      DESCRIPTION="$2"
      shift; shift
      ;;
    --severity)
      SEVERITY="$2"
      shift; shift
      ;;
    --owner)
      OWNER="$2"
      shift; shift
      ;;
    -n|--count)
      COUNT="$2"
      shift; shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Loop to create cases
for i in {1..$COUNT}; do
  # Make titles/descriptions unique if more than one
  CASE_TITLE="$TITLE"
  CASE_DESC="$DESCRIPTION"
  if [[ $COUNT -gt 1 ]]; then
    CASE_TITLE="$TITLE #$i"
    CASE_DESC="$DESCRIPTION (case $i)"
  fi

  # Build JSON payload
  read -r -d '' DATA <<EOF
{
  "title": "$CASE_TITLE",
  "tags": [],
  "category": null,
  "severity": "$SEVERITY",
  "description": "$CASE_DESC",
  "connector": {
    "id": "none",
    "name": "none",
    "type": ".none",
    "fields": null
  },
  "settings": { "syncAlerts": false },
  "owner": "$OWNER",
  "customFields": []
}
EOF

  echo "Creating case $i of $COUNT: $CASE_TITLE"

  curl -s -X POST "$KIBANA_URL/api/cases" \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' \
    -u "$USER:$PASS" \
    -d "$DATA"

  echo "\n---"
done

