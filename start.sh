#!/bin/bash

current_date=$(date +"%Y-%m-%d")

if [ $# -eq 1 ]; then
    file_name="${current_date}-$1.md"
    title="$1"
else
    file_name="${current_date}-新文章.md"
    title="标题"
fi

touch "./_posts/${file_name}"
echo "---" >> "./_posts/${file_name}"
echo "layout: post" >> "./_posts/${file_name}"
echo "title: $title" >> "./_posts/${file_name}"
echo "---" >> "./_posts/${file_name}"