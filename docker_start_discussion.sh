#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <path to post file omitting _posts/> <token>"
    exit 1
fi

file_name="$1"
token="$2"

docker run --rm -v "$(pwd)":/work githubiocli /bin/bash -c "\
cd /work && \
./start_discussion.sh \"./_posts/$file_name\" \"$token\" \
"