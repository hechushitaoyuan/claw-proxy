#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation for the Perfect Mirror ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating mirror route for: $service_prefix"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 为 /${service_prefix}/ 创建一个镜像通道
    location /${service_prefix}/ {
        # 黄金法则一：proxy_pass 必须带斜杠
        # 这会把请求路径正确地映射到后端，例如 /gb/auth -> /auth
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        
        # 黄金法则二：proxy_redirect 必须把根路径重写回子路径
        # 这会把后端的相对路径重定向（如 /dashboard）修正为 /gb/dashboard
        proxy_redirect / /${service_prefix}/;

        # --- 所有我们需要的标准头部设置 ---
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

    # 黄金法则三：必须指定一个可靠的公共DNS，绕开内部DNS问题
    resolver 1.1.1.1;

    # 让根目录直接指向我们自定义的欢迎页
    root /usr/share/nginx/html;
    index index.html;

    # 根路径的访问规则
    location = / {
        try_files \$uri \$uri/ =404;
    }
    
    # 加载我们所有的镜像通道
    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
