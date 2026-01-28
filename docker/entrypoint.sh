#!/bin/sh
set -e

# If CONTENT_DIR is set and exists, generate index
if [ -n "$CONTENT_DIR" ] && [ -d "$CONTENT_DIR" ]; then
    echo "Generating content index from $CONTENT_DIR..."
    python3 /app/generate_index.py "$CONTENT_DIR" /usr/share/nginx/html
    echo "Content index generated."
fi

# Start nginx
exec nginx -g "daemon off;"
