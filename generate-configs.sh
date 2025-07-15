#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

# 清理旧的配置
rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # 净化输入
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  # 跳过注释和空行
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 【最终的、最安全的方案】
    location /${service_prefix}/ {
        # 【核心武器1：路径处理】
        # proxy_pass后面的斜杠，是Nginx最安全、最推荐的路径处理方式。
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        
        # 【核心武器2：重定向处理】
        proxy_redirect / /${service_prefix}/;

        # --- 其他我们熟知的所有头部设置 ---
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

# 生成最终的、单一的配置文件
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;

    # 让根目录直接指向我们自定义的欢迎页
    root /usr/share/nginx/html;
    index index.html;

    location = / {
        try_files \$uri \$uri/ =404;
    }
    
    # 加载我们所有的路径分发规则
    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
