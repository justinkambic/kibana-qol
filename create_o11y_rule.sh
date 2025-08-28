#!/usr/bin/env bash
set -euo pipefail

HELP="\
create_o11y_rule.sh
Usage: ./create_o11y_rule.sh [-n NUM] [-u URL] [-a AUTH] [-f FIELD=VALUE ...] [-d DATA_JSON] [-t RULE_TYPE] [-s SPACE] [-D] [-h]

  -n NUM         Number of rules to create (default: 1)
  -u URL         API endpoint URL (default: http://localhost:5601/api/alerting/rule)
  -a AUTH        Basic auth in user:pass format (default: elastic:changeme)
  -f FIELD=VALUE Override any field in the JSON body (repeatable)
  -d DATA_JSON   Path to a JSON file to use as the base request body
  -t RULE_TYPE   Rule type (custom_threshold [default], apm_anomaly, elasticsearch_query, inventory, log_threshold, metric_threshold, slo_burn_rate)
  -s SPACE       Kibana space ID (default: default space, no URL modification)
  -D             Enable debug logging
  -h             Show help
"

# Debug trap if -D is present anywhere in args
DEBUG=0
if [[ "${*:-}" == *-D* ]]; then
	trap 'printf "\n\033[1;31m[ERROR]\033[0m Line %d: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
	printf "\033[1;36m[INFO] Starting create_o11y_rule.sh...\033[0m\n"
fi

NUM=1
URL="http://localhost:5601/api/alerting/rule"
AUTH="elastic:changeme"
FIELDS=()
DATA_JSON=""
RULE_TYPE="custom_threshold"
SPACE=""

show_help() {
	printf "%s\n" "$HELP"
	exit 0
}

while getopts ":n:u:a:f:d:t:s:Dh" opt; do
	case "$opt" in
		n) NUM="$OPTARG" ;;
		u) URL="$OPTARG" ;;
		a) AUTH="$OPTARG" ;;
		f) FIELDS+=("$OPTARG") ;;
		d) DATA_JSON="$OPTARG" ;;
		t) RULE_TYPE="$OPTARG" ;;
		s) SPACE="$OPTARG" ;;
		D) DEBUG=1 ;;
		h) show_help ;;
		:) echo "Missing argument for -$OPTARG" >&2; exit 2 ;;
		*) echo "Unknown option: -$OPTARG" >&2; show_help ;;
	esac
done
shift $((OPTIND-1))

get_default_json() {
	case "$1" in
		custom_threshold)
cat <<'EOF'
{
	"name": "Custom threshold rule",
	"enabled": true,
	"consumer": "logs",
	"tags": [],
	"params": {
		"criteria": [
			{
				"comparator": ">",
				"metrics": [ { "name": "A", "aggType": "count" } ],
				"threshold": [1],
				"timeSize": 1,
				"timeUnit": "m"
			}
		],
		"alertOnNoData": false,
		"alertOnGroupDisappear": false,
                "searchConfiguration": {
                      "query": {
                        "query": "",
                        "language": "kuery"
                      },
                      "index": "e7744dbe-a7a4-457b-83aa-539e9c88764c"
                    }
	},
	"schedule": { "interval": "1m" },
	"rule_type_id": "observability.rules.custom_threshold",
	"actions": [],
	"alert_delay": { "active": 1 }
}
EOF
		;;
		log_threshold)
cat <<'EOF'
{
	"name": "Log threshold rule",
	"enabled": true,
	"consumer": "logs",
	"tags": [],
	"params": {
		"count": {
			"comparator": "more than",
			"value": 100
		},
		"criteria": [
			[
				{
					"field": "log.level",
					"comparator": "matches",
					"value": "error"
				}
			]
		],
		"timeSize": 5,
		"timeUnit": "m",
		"logView": {
			"type": "log-view-reference",
			"logViewId": "default"
		},
		"groupBy": ["host.name"],
		"alertOnNoData": false,
		"alertOnGroupDisappear": false
	},
	"schedule": { "interval": "1m" },
	"rule_type_id": "logs.alert.document.count",
	"actions": [],
	"alert_delay": { "active": 1 }
}
EOF
		;;
		metric_threshold)
cat <<'EOF'
{
	"name": "Metric threshold rule",
	"enabled": true,
	"consumer": "infrastructure",
	"tags": [],
	"params": {
		"sourceId": "default",
		"criteria": [
			{
				"aggType": "avg",
				"metric": "system.cpu.user.pct",
				"comparator": ">",
				"threshold": [0.8],
				"timeSize": 5,
				"timeUnit": "m"
			}
		],
		"groupBy": ["host.name"],
		"alertOnNoData": false,
		"alertOnGroupDisappear": false
	},
	"schedule": { "interval": "1m" },
	"rule_type_id": "metrics.alert.threshold",
	"actions": [],
	"alert_delay": { "active": 1 }
}
EOF
		;;
		inventory)
cat <<'EOF'
{
	"name": "Inventory rule",
	"enabled": true,
	"consumer": "infrastructure",
	"tags": [],
	"params": {
		"sourceId": "default",
		"nodeType": "host",
		"criteria": [
			{
				"metric": "memory",
				"comparator": ">",
				"threshold": [0.9],
				"timeSize": 5,
				"timeUnit": "m"
			}
		],
		"groupBy": ["host.name"],
		"alertOnNoData": false,
		"alertOnGroupDisappear": false
	},
	"schedule": { "interval": "1m" },
	"rule_type_id": "metrics.alert.inventory.threshold",
	"actions": [],
	"alert_delay": { "active": 1 }
}
EOF
		;;
		elasticsearch_query)
cat <<'EOF'
{
	"name": "Elasticsearch query rule",
	"enabled": true,
	"consumer": "alerts",
	"tags": [],
	"params": {
		"index": ["filebeat-*"],
		"esQuery": "{\"query\":{\"match_all\":{}}}",
		"size": 0,
		"threshold": [100],
		"thresholdComparator": ">",
		"timeField": "@timestamp",
		"timeWindowSize": 5,
		"timeWindowUnit": "m"
	},
	"schedule": { "interval": "1m" },
	"rule_type_id": ".es-query",
	"actions": [],
	"alert_delay": { "active": 1 }
}
EOF
		;;
		apm_anomaly)
cat <<'EOF'
{
	"name": "APM anomaly rule",
	"enabled": true,
	"consumer": "apm",
	"tags": [],
	"params": {
		"serviceName": "*",
		"transactionType": "*",
		"environment": "*",
		"threshold": 2,
		"windowSize": 5,
		"windowUnit": "m"
	},
	"schedule": { "interval": "1m" },
	"rule_type_id": "apm.transaction_error_rate",
	"actions": [],
	"alert_delay": { "active": 1 }
}
EOF
		;;
		slo_burn_rate)
cat <<'EOF'
{
	"name": "SLO burn rate rule",
	"enabled": true,
	"consumer": "observability",
	"tags": [],
	"params": {
		"sloId": "my-slo-id",
		"windows": [
			{ 
				"id": "1h", 
				"burnRateThreshold": 2, 
				"maxBurnRateThreshold": 4, 
				"longWindow": { "value": 1, "unit": "h" }, 
				"shortWindow": { "value": 5, "unit": "m" },
				"actionGroup": "slo.burnRate.high"
			}
		]
	},
	"schedule": { "interval": "1m" },
	"rule_type_id": "slo.rules.burnRate",
	"actions": [],
	"alert_delay": { "active": 1 }
}
EOF
		;;
		*)
			echo "[ERROR] Unknown rule type: $1" >&2; exit 1 ;;
	esac
}

# Build base JSON
if [[ -n "$DATA_JSON" ]]; then
	BODY_JSON=$(cat "$DATA_JSON")
else
	BODY_JSON=$(get_default_json "$RULE_TYPE")
fi

# Build URL with space support
if [[ -n "$SPACE" ]]; then
	# Insert space into URL: http://host:port/s/space-id/api/...
	if [[ "$URL" =~ ^(https?://[^/]+)(/.*)?$ ]]; then
		BASE_URL="${BASH_REMATCH[1]}"
		API_PATH="${BASH_REMATCH[2]:-/api/alerting/rule}"
		URL="${BASE_URL}/s/${SPACE}${API_PATH}"
	else
		echo "Error: Invalid URL format for space insertion: $URL" >&2
		exit 1
	fi
fi

# Override fields via jq
override_fields() {
	local json="$1"
	local jq_args=()
	for field in "${FIELDS[@]:-}"; do
		[[ -z "$field" ]] && continue
		local key="${field%%=*}"
		local value="${field#*=}"
		# Use 'val' as the jq variable name to avoid conflicts with field paths
		if jq -e . >/dev/null 2>&1 <<<"$value"; then
			jq_args+=("--argjson" "val" "$value" ".${key} = \$val")
		else
			jq_args+=("--arg" "val" "$value" ".${key} = \$val")
		fi
	done
	if ((${#jq_args[@]})); then
		echo "$json" | jq "${jq_args[@]}"
	else
		echo "$json"
	fi
}

if ! command -v jq >/dev/null; then
	echo "Error: jq is required for this script. Please install jq." >&2
	exit 1
fi

SUCCESS=0
FAIL=0
for ((i=1; i<=NUM; i++)); do
	RULE_JSON=$(jq --arg name "${RULE_TYPE//_/ } rule $i" '.name = $name' <<<"$BODY_JSON")
	RULE_JSON=$(override_fields "$RULE_JSON")
	printf "\n\033[1;34m[+] Creating rule %d at %s\033[0m\n" "$i" "$URL"
	if [[ $DEBUG -eq 1 ]]; then
		printf "\033[1;33m[DEBUG] Request body:\033[0m\n"
		echo "$RULE_JSON"
		printf "\033[1;33m[DEBUG] curl command:\033[0m curl -X POST %s -H 'kbn-xsrf:true' -H 'Content-Type:application/json' -d '[body]' -u %s\n" "$URL" "$AUTH"
	fi
	RESPONSE=$(curl -sS -w "HTTP_STATUS:%{http_code}" -X POST "$URL" \
		-H "kbn-xsrf:true" \
		-H "Content-Type:application/json" \
		-d "$RULE_JSON" \
		-u "$AUTH")
	BODY="${RESPONSE%%HTTP_STATUS:*}"
	STATUS="${RESPONSE##*HTTP_STATUS:}"
	if [[ -z "$BODY" ]]; then
		echo "[!] No response body received. HTTP status: $STATUS" >&2
	else
		if [[ $DEBUG -eq 1 ]]; then
			echo "$BODY"
			echo "$BODY" | jq . || echo "[!] jq failed to parse response. Raw body above."
		fi
		if [[ "$STATUS" == 2* ]]; then
			printf "\033[1;32m[OK] Rule %d: HTTP %s\033[0m\n" "$i" "$STATUS"
			((SUCCESS++))
		else
			printf "\033[1;31m[FAIL] Rule %d: HTTP %s (Rule was NOT created)\033[0m\n" "$i" "$STATUS"
			((FAIL++))
			if [[ -n "$BODY" ]]; then
				printf "\033[1;31m[SERVER ERROR]\033[0m\n"
				echo "$BODY" | jq . || echo "$BODY"
			fi
		fi
	fi
	if [[ "$STATUS" != 2* ]]; then
		echo "[!] Non-success HTTP status: $STATUS" >&2
	fi
done

printf "\n\033[1;32mSummary:\033[0m %d succeeded, %d failed.\n" "$SUCCESS" "$FAIL"
