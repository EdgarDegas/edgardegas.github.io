#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <path to post file> <token>"
    exit 1
fi

file_path="$1"
token="$2"

# post URL
file_name=$(basename "$file_path")
file_name="${file_name%.*}"
file_name="${file_name// /-}"

file_title=$(basename "$file_path" | cut -d '-' -f 4- | sed 's/ /-/g' | sed 's/\.md$//')
file_title=$(echo "$file_title" | tr '[:upper:]' '[:lower:]')
url="https://edgardegas.github.io/${file_title}.html"

# discussion.title
title=$(grep -m 1 "^title: " "$1" | sed 's/^title: //')

# discussion.body
if [[ $title =~ ^[[:ascii:]]*$ ]]; then
  # 如果是ASCII字符，构造body
  body="Leave your comment on [${title}](${url})."
else
  # 如果不是ASCII字符，构造body
  body="请在此处发表对[${title}](${url})的评论。"
fi

graphql_request=$(cat <<EOF
mutation {
  createDiscussion(input: {
    repositoryId: "R_kgDOLj4p9A",
    categoryId: "DIC_kwDOLj4p9M4CeSpb",
    title: "$title",
    body: "$body"
  }) {
    discussion {
      url
    }
  }
}
EOF
)

graphql_request=$(echo "$graphql_request" | jq -sRr '@json')

response=$(curl -s -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"query\": $graphql_request}" \
    https://api.github.com/graphql)

url_value=$(echo "$response" | jq -r '.data.createDiscussion.discussion.url')

echo $url_value

if grep -q "^disc_url: " "$file_path"; then
  sed -i "s|^disc_url: .*|disc_url: $url_value|" "$file_path"
else
  sed -i "/^title: /a disc_url: $url_value" "$file_path"
fi