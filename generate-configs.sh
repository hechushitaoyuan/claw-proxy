#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  if [ -z "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 【终极决战·路径重写】
    # 匹配所有以 /gb/ 开头的请求
    location /${service_prefix}/ {
        # 【关键】告诉Nginx，在将请求发给后端前，
        # 把URL中的 /gb/ 部分砍掉，只保留后面的部分。
        # 例如：/gb/auth 会被重写为 /auth
        rewrite ^/${service_prefix}/(.*)$ /\$1 break;
        
        # --- 之前的所有配置都保持完美 ---
        proxy_pass http://${service_prefix}.${BASE_DOMAIN};
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
        
        # 【关键】我们不再需要sub_filter，所以把Accept-Encoding加回来，恢复压缩
        # proxy_set_header Accept-Encoding \"\"; 
        
        # 【关键】因为路径已经被重写，后端的任何相对路径重定向都会是正确的！
        # 我们只需要一个更通用的proxy_redirect
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
        return 200 "jiamian personal domain is running~~";
    }

    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
