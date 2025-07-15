#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # 净化输入，删除\r
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  # 【关键的、决定性的、再也不会被我忘记的、回归的修复！】
  # 把那个该死的、跳过空行和注释行的逻辑，加回来！
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 使用路径重写来解决所有子路径问题
    location /${service_prefix}/ {
        rewrite ^/${service_prefix}/(.*)$ /\$1 break;
        
        proxy_pass http://${service_prefix}.${BASE_DOMAIN};
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
        
        # 通用的重定向规则，处理后端返回的相对路径
        proxy_redirect / /${service_prefix}/;

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
        return 200 "jiamian personal domain is running.";
    }

    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
