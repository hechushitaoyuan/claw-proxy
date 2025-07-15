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

  # 跳过空行和注释行
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 【最终的、最安全的方案】
    location /${service_prefix}/ {
        # 【关键】不再使用危险的rewrite。
        # proxy_pass后面的斜杠，会自动处理路径！
        # 例如，/gb/auth 的请求，会被发到后端的 /auth
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        
        # --- 之前的所有配置都保持完美 ---
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
