#!/usr/bin/env bash
# Fetch open Zendesk tickets assigned to the Feature Flags team.
# Emits JSON: { configured, new_tickets, customer_replied, aging }.
#
# Required env vars (set in ~/.zshrc or a sourced file):
#   ZENDESK_SUBDOMAIN     e.g. "posthoghelp" (the part before .zendesk.com)
#   ZENDESK_EMAIL         your zendesk email
#   ZENDESK_API_TOKEN     personal API token from Admin → Apps → API
#   ZENDESK_GROUP_ID      numeric group ID for the Feature Flags team
#
# Usage: zendesk-flags.sh [--since <ISO 8601 timestamp>]

set -euo pipefail

SINCE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --since) SINCE="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

missing=()
for var in ZENDESK_SUBDOMAIN ZENDESK_EMAIL ZENDESK_API_TOKEN ZENDESK_GROUP_ID; do
    if [ -z "${!var:-}" ]; then
        missing+=("$var")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    jq -n --argjson missing "$(printf '%s\n' "${missing[@]}" | jq -R . | jq -s .)" \
        '{configured: false, missing_env: $missing, new_tickets: [], customer_replied: [], aging: []}'
    exit 0
fi

AUTH="${ZENDESK_EMAIL}/token:${ZENDESK_API_TOKEN}"
BASE="https://${ZENDESK_SUBDOMAIN}.zendesk.com/api/v2"

# Open tickets in the Feature Flags group.
tickets=$(curl -sS -u "$AUTH" \
    "$BASE/search.json?query=type:ticket+group_id:${ZENDESK_GROUP_ID}+status<solved&sort_by=updated_at&sort_order=desc" \
    | jq '.results')

# New = created since SINCE (if provided), else created in the last 24h.
if [ -z "$SINCE" ]; then
    SINCE=$(date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ")
fi

new_tickets=$(echo "$tickets" | jq --arg since "$SINCE" '[.[] | select(.created_at >= $since)]')

# Customer replied = the most recent comment author is the requester (not the assignee).
# Run a second pass: for each ticket, fetch the latest comment.
customer_replied=$(echo "$tickets" | jq -c '.[]' | while read -r ticket; do
    id=$(echo "$ticket" | jq -r '.id')
    requester_id=$(echo "$ticket" | jq -r '.requester_id')
    latest_author=$(curl -sS -u "$AUTH" \
        "$BASE/tickets/$id/comments.json?sort_order=desc&per_page=1" \
        | jq -r '.comments[0].author_id // empty')
    if [ "$latest_author" = "$requester_id" ]; then
        echo "$ticket"
    fi
done | jq -s '.')

# Aging = open >7 days with no recent activity.
seven_days_ago=$(date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ")
aging=$(echo "$tickets" | jq --arg cutoff "$seven_days_ago" '[.[] | select(.created_at < $cutoff)]')

jq -n \
    --argjson new "$new_tickets" \
    --argjson customer_replied "$customer_replied" \
    --argjson aging "$aging" \
    '{configured: true, new_tickets: $new, customer_replied: $customer_replied, aging: $aging}'
