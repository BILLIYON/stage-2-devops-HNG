#!/usr/bin/env bash
set -e

# This script builds final nginx.conf from template and starts nginx foreground.
# It uses ACTIVE_POOL env var to choose which server is primary/backup.

: "${ACTIVE_POOL:=blue}"
: "${BLUE_SERVICE_HOST:=app_blue}"
: "${GREEN_SERVICE_HOST:=app_green}"
: "${BLUE_SERVICE_PORT:=3000}"
: "${GREEN_SERVICE_PORT:=3000}"

# Build upstream server list
if [ "$ACTIVE_POOL" = "green" ]; then
  UPSTREAM="server ${GREEN_SERVICE_HOST}:${GREEN_SERVICE_PORT} max_fails=1 fail_timeout=3s;
server ${BLUE_SERVICE_HOST}:${BLUE_SERVICE_PORT} backup max_fails=1 fail_timeout=3s;"
else
  UPSTREAM="server ${BLUE_SERVICE_HOST}:${BLUE_SERVICE_PORT} max_fails=1 fail_timeout=3s;
server ${GREEN_SERVICE_HOST}:${GREEN_SERVICE_PORT} backup max_fails=1 fail_timeout=3s;"
fi

# Export variable for envsubst
export NGINX_UPSTREAM_SERVERS="$UPSTREAM"

# Render template to nginx.conf
envsubst '\$NGINX_UPSTREAM_SERVERS' < /etc/nginx/templates/nginx.tmpl > /etc/nginx/nginx.conf

# Print resulting config for debugging
echo "===== Rendered /etc/nginx/nginx.conf ====="
sed -n '1,200p' /etc/nginx/nginx.conf
echo "========================================="

# Start nginx (foreground)
nginx -g "daemon off;"
