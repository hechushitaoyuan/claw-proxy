#!/bin/sh
# generate-configs.sh - v3.0 (Ultimate Path-Based Proxy)

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org" # 这是Cloudflare隧道的目标

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation for Ultimate Path-Based Proxy ---"

# --- 动态生成所有服务的 Location 块 ---
SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # 跳过空行和注释
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  # 判断目标服务是否需要用https回源 (只有gp是)
  target_scheme="http"
  if [ "$service_prefix" = "gp" ]; then
    target_scheme="https"
  fi
  
  target_host="${service_prefix}.${BASE_DOMAIN}"
  echo "Generating route: /${service_prefix}/ -> ${target_scheme}://${target_host}/"

  # ★★★ 这是最关键的部分：强化的内容替换规则 ★★★
  # 覆盖了HTML/CSS的引用，以及JS中常见的API请求路径
  SUB_FILTER_RULES="
        # 强制禁用gzip压缩，否则sub_filter无法生效
        proxy_set_header Accept-Encoding \"\";
        sub_filter_once off;

        # 基础资源替换 (HTML/CSS)
        sub_filter 'href=\"/'      'href=\"/${service_prefix}/';
        sub_filter 'src=\"/'       'src=\"/${service_prefix}/';
        sub_filter 'action=\"/'    'action=\"/${service_prefix}/';
        sub_filter 'url(/'         'url(/${service_prefix}/';

        # 关键API路径替换 (JavaScript/Fetch/XHR)
        # 同时处理了双引号和单引号的情况
        sub_filter '\"/api/'       '\"/${service_prefix}/api/';
        sub_filter '\\'/api/'      '\\'/${service_prefix}/api/';
        sub_filter '\"/auth'       '\"/${service_prefix}/auth';
        sub_filter '\\'/auth'      '\\'/${service_prefix}/auth';
        sub_filter '\"/ws'         '\"/${service_prefix}/ws';
        sub_filter '\\'/ws'        '\\'/${service_prefix}/ws';
  "

  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 规则 for /${service_prefix}/
    location /${service_prefix}/ {
        proxy_pass ${target_scheme}://${target_host}/;
        proxy_redirect default; # 使用更健壮的重定向处理
        
        ${SUB_FILTER_RULES}

        # 标准代理头部
        proxy_set_header Host ${target_host};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade'; # 支持WebSocket
        proxy_buffering off;
    }
  "
done < services.list


# --- 生成最终的 Nginx 配置文件 ---
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;

    # Cloudflare DNS
    resolver 1.1.1.1;

    # ★★★ 根路径配置，用于展示你的 index.html ★★★
    location = / {
        root /usr/share/nginx/html;
        index index.html;
    }
    
    # 动态嵌入所有服务的location配置
    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
