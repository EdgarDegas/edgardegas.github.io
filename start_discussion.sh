#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <path to post file> [token]" >&2
    exit 1
fi

file_path="$1"
token="${2:-${GH_TOKEN:-}}"

if [ ! -f "$file_path" ]; then
    echo "Error: Post not found: $file_path" >&2
    exit 1
fi

if [ -z "$token" ]; then
    echo "Error: Set GH_TOKEN or provide a token as the second argument." >&2
    exit 1
fi

for command in curl jq; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: Required command not found: $command" >&2
        exit 1
    fi
done

existing_url=$(sed -n 's/^disc_url:[[:space:]]*//p' "$file_path" | head -n 1)
if [ -n "$existing_url" ]; then
    echo "$existing_url"
    exit 0
fi

file_name=$(basename "$file_path")
if [[ ! "$file_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-(.+)\.md$ ]]; then
    echo "Error: Post name must use YYYY-MM-DD-slug.md: $file_name" >&2
    exit 1
fi

slug="${BASH_REMATCH[1]}"
post_url="https://edgardegas.github.io/${slug}.html"

title=$(sed -n 's/^title:[[:space:]]*//p' "$file_path" | head -n 1)
if [ -z "$title" ]; then
    echo "Error: Post front matter has no title." >&2
    exit 1
fi

if [[ "$title" =~ ^[[:ascii:]]*$ ]]; then
    body="Leave your comment on [${title}](${post_url})."
else
    body="请在此处发表对[${title}](${post_url})的评论。"
fi

read -r -d '' query <<'GRAPHQL' || true
mutation($repositoryId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
  createDiscussion(input: {
    repositoryId: $repositoryId
    categoryId: $categoryId
    title: $title
    body: $body
  }) {
    discussion {
      url
    }
  }
}
GRAPHQL

payload=$(jq -n \
    --arg query "$query" \
    --arg repository_id "R_kgDOLj4p9A" \
    --arg category_id "DIC_kwDOLj4p9M4CeSpb" \
    --arg title "$title" \
    --arg body "$body" \
    '{
      query: $query,
      variables: {
        repositoryId: $repository_id,
        categoryId: $category_id,
        title: $title,
        body: $body
      }
    }')

response=$(curl --fail --silent --show-error \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    https://api.github.com/graphql)

discussion_url=$(jq -r '.data.createDiscussion.discussion.url // empty' <<<"$response")
if [ -z "$discussion_url" ]; then
    echo "Error: GitHub did not create the discussion." >&2
    jq -c '{errors: .errors}' <<<"$response" >&2
    exit 1
fi

temporary_file=$(mktemp)
trap 'rm -f "$temporary_file"' EXIT

awk -v discussion_url="$discussion_url" '
    NR == 1 && $0 == "---" {
        in_front_matter = 1
    }

    in_front_matter && /^title:[[:space:]]/ && !inserted {
        print
        print "disc_url: " discussion_url
        inserted = 1
        next
    }

    {
        print
    }

    NR > 1 && in_front_matter && $0 == "---" {
        in_front_matter = 0
    }

    END {
        if (!inserted) {
            exit 2
        }
    }
' "$file_path" >"$temporary_file"

cat "$temporary_file" >"$file_path"
echo "$discussion_url"
