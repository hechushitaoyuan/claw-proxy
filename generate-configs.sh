#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

mkdir -p $CONFIG_DIR

echo "--- Starting config generation from services.list ---"

# 【加固版循环】更严格地处理空行
while read -r service_prefix; do
  # 如果行是空的，或者以#开头，就跳过
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating config for: $service_prefix"
  
  cat > "$CONFIG_DIR/$service_prefix.conf" << EOF
# Auto-generated for $service_prefix

location /$service_prefix/ {
    proxy_pass https://$service_prefix.$BASE_DOMAIN/;
    proxy_set_header Host $service_prefix.$BASE_DOMAIN;

    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_buffering off;
}
EOF
done < services.list

echo "--- Config generation finished successfully! ---"
