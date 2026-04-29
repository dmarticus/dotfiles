#!/usr/bin/env bash
# Emit a JSON object describing what needs the user's attention on GitHub:
# review requests, their open PRs (with CI status), @-mentions, and items
# assigned to them on a project board.
#
# Usage: github-attention.sh [--since <ISO>] [--project-board <org>/<number>]

set -euo pipefail

SINCE=""
PROJECT_BOARD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --since) SINCE="$2"; shift 2 ;;
        --project-board) PROJECT_BOARD="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

USER_LOGIN=$(gh api user --jq '.login')

project_items="[]"
if [ -n "$PROJECT_BOARD" ]; then
    pb_org="${PROJECT_BOARD%/*}"
    pb_num="${PROJECT_BOARD#*/}"
    project_items=$(gh project item-list "$pb_num" --owner "$pb_org" --limit 100 --format json 2>/dev/null \
        | jq --arg user "$USER_LOGIN" '
            [.items[]
                | select(.assignees != null and (.assignees | index($user)))
                | select(.status != "Done" and .status != "Cancelled")
                | {
                    status,
                    title,
                    number: .content.number,
                    repo: .content.repository,
                    type: .content.type,
                    url: .content.url,
                    labels
                }
            ]' || echo "[]")
fi

review_requested_raw=$(
    gh search prs --review-requested "@me" --state open \
        --json number,title,url,author,createdAt,updatedAt,repository \
        --limit 50
)

# Annotate each review-requested PR with reviewDecision so the briefing can
# filter to PRs that genuinely need this user's input (REVIEW_REQUIRED) and
# drop ones already approved or blocked by other reviewers.
review_requested=$(echo "$review_requested_raw" | jq -c '.[]' | while read -r pr; do
    repo=$(echo "$pr" | jq -r '.repository.nameWithOwner')
    number=$(echo "$pr" | jq -r '.number')
    decision=$(gh pr view "$number" --repo "$repo" --json reviewDecision --jq '.reviewDecision // "REVIEW_REQUIRED"' 2>/dev/null || echo "REVIEW_REQUIRED")
    echo "$pr" | jq --arg d "$decision" '. + {review_decision: $d}'
done | jq -s '.')

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
    --argjson project_items "$project_items" \
    --arg user "$USER_LOGIN" \
    --arg since "$SINCE" \
    '{user: $user, since: $since, review_requested: $review_requested, my_open_prs: $my_open_prs, mentions: $mentions, project_items: $project_items}'
