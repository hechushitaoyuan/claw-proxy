#!/bin/sh

set -e

# 目标目录
CONFIG_DIR="/etc/nginx/conf.d"
# 您的目标域名
BASE_DOMAIN="jiamian0128.dpdns.org"

# 清理旧的配置
rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # 净化输入，删除\r
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  # 跳过空行和注释
  if [ -z "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  # 【终极决战修改】
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    location /${service_prefix}/ {
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};

        # 【关键的“欺诈”指令】
        # 如果后端返回重定向到 http://.../，就把它伪装成我们自己的 /.../ 路径
        proxy_redirect http://${service_prefix}.${BASE_DOMAIN}/ /${service_prefix}/;
        # 如果后端返回重定向到 https://.../，也把它伪装成我们自己的 /.../ 路径
        proxy_redirect https://${service_prefix}.${BASE_DOMAIN}/ /${service_prefix}/;

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

# 生成最终的、单一的配置文件
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
