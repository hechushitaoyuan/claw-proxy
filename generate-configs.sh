#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

# 【最终决战·DNS修正】
UPSTREAM_BLOCKS=""
LOCATION_BLOCKS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating blocks for: $service_prefix"
  
  # 创建上游服务器定义
  UPSTREAM_BLOCKS="${UPSTREAM_BLOCKS}
  upstream ${service_prefix}_upstream {
    server ${service_prefix}.${BASE_DOMAIN}:80; # 我们先假设是80端口
  }
  "
  
  # 创建路径分发规则
  LOCATION_BLOCKS="${LOCATION_BLOCKS}
    location /${service_prefix}/ {
        proxy_pass http://${service_prefix}_upstream/;
        
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
        proxy_redirect / /${service_prefix}/;

        # --- 其他我们熟知的所有头部设置 ---
        # ... (保留所有proxy_set_header) ...
    }
  "
done < services.list

# 生成最终的、单一的配置文件
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;

    # 【关键】指定一个公共的DNS服务器，比如Cloudflare的1.1.1.1
    # 这将绕过爪子云内部可能存在问题的DNS
    resolver 1.1.1.1;

    root /usr/share/nginx/html;
    index index.html;

    location = / {
        try_files \$uri \$uri/ =404;
    }
    
    # 加载我们所有的路径分发规则
    ${LOCATION_BLOCKS}
}

# 把上游服务器定义，放在http块的顶层
# 这里我们假设它们在同一个http块里，这需要一点技巧
# 我们把它们写到另一个文件里，让nginx自动加载
echo "http { \\
    ${UPSTREAM_BLOCKS} \\
    include /etc/nginx/conf.d/*.conf; \\
}" > /etc/nginx/nginx.conf
EOF

echo "--- Config generation finished successfully! ---"
