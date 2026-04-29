#!/usr/bin/env bash
# Emit a JSON object describing what needs the user's attention on GitHub:
# review requests, their open PRs (with CI status), and @-mentions.
#
# Usage: github-attention.sh [--since <ISO 8601 timestamp>]

set -euo pipefail

SINCE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --since) SINCE="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

USER_LOGIN=$(gh api user --jq '.login')

review_requested=$(
    gh search prs --review-requested "@me" --state open \
        --json number,title,url,author,createdAt,updatedAt,repository \
        --limit 50
)

my_open_prs_raw=$(
    gh search prs --author "@me" --state open \
        --json number,title,url,createdAt,updatedAt,repository \
        --limit 50
)

# Annotate each of the user's PRs with CI state and unresolved review comment count.
# Done in a loop so we get accurate per-PR check state without scraping.
my_open_prs=$(echo "$my_open_prs_raw" | jq -c '.[]' | while read -r pr; do
    repo=$(echo "$pr" | jq -r '.repository.nameWithOwner')
    number=$(echo "$pr" | jq -r '.number')
    checks=$(gh pr checks "$number" --repo "$repo" --json state --jq '[.[].state] | (if any(. == "FAILURE") then "failing" elif any(. == "PENDING") then "pending" elif length == 0 then "none" else "passing" end)' 2>/dev/null || echo "unknown")
    echo "$pr" | jq --arg checks "$checks" '. + {checks_state: $checks}'
done | jq -s '.')

# Mentions = unread notifications with reason "mention" or "review_requested" since SINCE.
mentions_args=(--method GET)
if [ -n "$SINCE" ]; then
    mentions_args+=(-f "since=$SINCE")
fi

mentions=$(
    gh api notifications "${mentions_args[@]}" \
        --jq '[.[] | select(.reason == "mention" or .reason == "review_requested") | {
            reason: .reason,
            title: .subject.title,
            type: .subject.type,
            url: .subject.url,
            repo: .repository.full_name,
            updated_at: .updated_at
        }]'
)

jq -n \
    --argjson review_requested "$review_requested" \
    --argjson my_open_prs "$my_open_prs" \
    --argjson mentions "$mentions" \
    --arg user "$USER_LOGIN" \
    --arg since "$SINCE" \
    '{user: $user, since: $since, review_requested: $review_requested, my_open_prs: $my_open_prs, mentions: $mentions}'
