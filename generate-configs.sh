#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # 【关键的、最终的、决定性的修复】
  # 强制删除所有可能存在的、来自Windows的换行符(\r)，彻底净化输入！
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  # 跳过净化后为空的行和注释行
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    location /${service_prefix}/ {
        proxy_pass https://${service_prefix}.${BASE_DOMAIN}/;
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_buffering off;
    }
"
done < services.list

cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;

    location = / {
        add_header Content-Type text/plain;
        return 200 "Gateway is running.";
    }

    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
