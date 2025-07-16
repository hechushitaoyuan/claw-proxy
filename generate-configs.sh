#!/bin/sh
# generate-configs.sh - The Real Final Stand v7

set -e
CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"
rm -f $CONFIG_DIR/*.conf
echo "--- Starting config generation for the Ultimate Mirror Engine v7 ---"

# --- Part 1: Create Upstream Definitions ---
UPSTREAM_DEFINITIONS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi
  
  UPSTREAM_DEFINITIONS="${UPSTREAM_DEFINITIONS}
upstream ${service_prefix}_upstream {
    # 这里的域名将由下面的 resolver 来解析
    server ${service_prefix}.${BASE_DOMAIN}:80;
}
  "
done < services.list

# --- Part 2: Create Location Blocks ---
SERVICE_LOCATIONS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi
  echo "Generating v7 route for: $service_prefix"
  
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
    location /${service_prefix}/ {
        # 直接代理到我们定义好的upstream
        proxy_pass http://${service_prefix}_upstream/;
        proxy_redirect / /${service_prefix}/;
        ${SUB_FILTER_RULES}
        # ... (标准头部设置) ...
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
    }
  "
done < services.list

# --- Part 3: Assemble the Final nginx.conf ---
cat > "$CONFIG_DIR/default.conf" << EOF
