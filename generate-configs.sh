#!/bin/sh
# generate-configs.sh - The Final Strike Version

set -e
CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"
rm -f $CONFIG_DIR/*.conf
echo "--- Starting config generation for the Ultimate Mirror Engine v6 ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi
  echo "Generating v6 Final Strike route for: $service_prefix"
  
  # ... (SUB_FILTER_RULES 保持不变)
  SUB_FILTER_RULES=""
  if [ "$service_prefix" = "gb" ] || [ "$service_prefix" = "npm" ]; then
    SUB_FILTER_RULES="
        proxy_set_header Accept-Encoding \"\";
        sub_filter_once off;
        sub_filter 'href=\"/' 'href=\"/${service_prefix}/';
        sub_filter 'src=\"/' 'src=\"/${service_prefix}/';
        sub_filter 'action=\"/' 'action=\"/${service_prefix}/';
        sub_filter 'href=\'/' 'href=\'/${service_prefix}/';
        sub_filter 'src=\'/' 'src=\'/${service_prefix}/';
        sub_filter 'action=\'/' 'action=\'/${service_prefix}/';
        sub_filter 'url(/' 'url(/${service_prefix}/';
        sub_filter '\"/api/' '\"/${service_prefix}/api/';
        sub_filter '\'/api/' '\'/${service_prefix}/api/';
        sub_filter '\"/auth' '\"/${service_prefix}/auth';
        sub_filter '\'/auth' '\'/${service_prefix}/auth';
        sub_filter '\"/login' '\"/${service_prefix}/login';
        sub_filter '\'/login' '\'/${service_prefix}/login';
    "
  fi

  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 【决定性修正1：精确匹配】
    # 使用'~'来表示这是一个正则表达式匹配，确保所有/npm/开头的请求，包括/npm/login，都能被正确捕获
    location ~ ^/${service_prefix}/ {
        # 【决定性修正2：强制IPv4】
        # 把proxy_pass的目标，从域名，改成一个变量！
        set \$upstream_host http://${service_prefix}.${BASE_DOMAIN};
        proxy_pass \$upstream_host;

        proxy_redirect / /${service_prefix}/;
        ${SUB_FILTER_RULES}
        # ... (标准头部设置) ...
    }
  "
done < services.list

# ... (生成default.conf的代码保持不变) ...
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;
    # 【决定性修正2：强制IPv4】
    # 在DNS解析时，就告诉它我们只要ipv4
    resolver 1.1.1.1 ipv6=off;
    root /usr/share/nginx/html;
    index index.html;
    location = / { try_files \$uri \$uri/ =404; }
    ${SERVICE_LOCATIONS}
}
EOF
echo "--- Config generation finished successfully! ---"
