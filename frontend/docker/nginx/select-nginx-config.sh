#!/bin/sh
set -eu

HTTP_CONF="/etc/nginx/templates/nginx.http.conf"
HTTPS_CONF="/etc/nginx/templates/nginx.https.conf"
TARGET_CONF="/etc/nginx/conf.d/default.conf"
CERT_FULLCHAIN="/etc/letsencrypt/live/vlotterqa.tech/fullchain.pem"
CERT_PRIVKEY="/etc/letsencrypt/live/vlotterqa.tech/privkey.pem"

if [ "${ENABLE_HTTPS:-false}" = "true" ] && [ -f "$CERT_FULLCHAIN" ] && [ -f "$CERT_PRIVKEY" ]; then
  cp "$HTTPS_CONF" "$TARGET_CONF"
  echo "Using HTTPS nginx config"
else
  cp "$HTTP_CONF" "$TARGET_CONF"
  echo "Using HTTP nginx config (certificates not found or HTTPS disabled)"
fi
