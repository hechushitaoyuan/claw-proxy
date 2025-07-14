#!/bin/sh

set -e

# 目标目录
CONFIG_DIR="/etc/nginx/conf.d"
# 您的目标域名
BASE_DOMAIN="jiamian0128.dpdns.org"

# 清理旧的配置，确保一个干净的开始
rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

# 读取服务列表
SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # 跳过空行和注释
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  # 【关键重构】不再生成独立文件，而是将所有location块拼接成一个变量
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

# 【最终生成】创建一个单一的、包含所有location的、语法绝对正确的配置文件
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;

    location = / {
        add_header Content-Type text/plain;
        return 200 "Gateway is running.";
    }

    # 将我们拼接好的所有location块，安全地插入到这里
    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
echo "Generated final config file:"
cat "$CONFIG_DIR/default.conf"
