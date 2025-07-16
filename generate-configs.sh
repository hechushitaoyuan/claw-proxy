#!/bin/sh
# generate-configs.sh - The Final Version

set -e
CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"
rm -f $CONFIG_DIR/*.conf
echo "--- Starting config generation for the Ultimate Mirror Engine v4 ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # ... (净化输入的代码保持不变) ...
  # ... (跳过注释的代码保持不变) ...
  echo "Generating v4 route for: $service_prefix"
  
  SUB_FILTER_RULES=""
  if [ "$service_prefix" = "gb" ] || [ "$service_prefix" = "npm" ]; then
    SUB_FILTER_RULES="
        proxy_set_header Accept-Encoding \"\";
        sub_filter_once off;
        
        # --- 最全面的内容替换规则 ---
        sub_filter 'href=\"/'  'href=\"/${service_prefix}/';
        sub_filter 'src=\"/'   'src=\"/${service_prefix}/';
        sub_filter 'action=\"/' 'action=\"/${service_prefix}/';
        sub_filter 'href=\'/' 'href=\'/${service_prefix}/';
        sub_filter 'src=\'/'   'src=\'/${service_prefix}/';
        sub_filter 'action=\'/' 'action=\'/${service_prefix}/';
        sub_filter 'url(/' 'url(/${service_prefix}/';
        sub_filter '\"/api/' '\"/${service_prefix}/api/';
        sub_filter '\'/api/' '\'/${service_prefix}/api/';
        sub_filter '\"/auth' '\"/${service_prefix}/auth'; # for gb
        sub_filter '\'/auth' '\'/${service_prefix}/auth'; # for gb
        # 【最后的、决定性的规则！】
        sub_filter '\"/login' '\"/${service_prefix}/login'; # for npm
        sub_filter '\'/login' '\'/${service_prefix}/login'; # for npm
    "
  fi

  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    location /${service_prefix}/ {
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        proxy_redirect / /${service_prefix}/;
        ${SUB_FILTER_RULES}
        # ... (标准头部设置)
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_buffering off; # 确保sub_filter可以工作
    }
  "
done < services.list

# ... (生成default.conf的代码保持不变) ...
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;
    resolver 1.1.1.1;
    root /usr/share/nginx/html;
    index index.html;
    location = / { try_files \$uri \$uri/ =404; }
    ${SERVICE_LOCATIONS}
}
EOF
echo "--- Config generation finished successfully! ---"
