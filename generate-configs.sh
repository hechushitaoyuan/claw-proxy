#!/bin/sh
# generate-configs.sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation for the Ultimate Mirror Engine ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating Ultimate Mirror route for: $service_prefix"
  
  # 我们只对gb和npm这两个“传统应用”开启内容替换的终极武器
  SUB_FILTER_RULES=""
  if [ "$service_prefix" = "gb" ] || [ "$service_prefix" = "npm" ]; then
    SUB_FILTER_RULES="
        proxy_set_header Accept-Encoding \"\";
        sub_filter_once off;
        sub_filter 'href=\"/'  'href=\"/${service_prefix}/';
        sub_filter 'src=\"/'   'src=\"/${service_prefix}/';
        sub_filter 'action=\"/' 'action=\"/${service_prefix}/';
        sub_filter 'url(/' 'url(/${service_prefix}/';
        sub_filter '\"/api/' '\"/${service_prefix}/api/';
        sub_filter '\'/api/' '\'/${service_prefix}/api/';
        sub_filter '\"/auth' '\"/${service_prefix}/auth';
        sub_filter '\'/auth' '\'/${service_prefix}/auth';
    "
  fi

  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    location /${service_prefix}/ {
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        proxy_redirect / /${service_prefix}/;

        ${SUB_FILTER_RULES}

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

    resolver 1.1.1.1;

    root /usr/share/nginx/html;
    index index.html;

    location = / {
        try_files \$uri \$uri/ =404;
    }
    
    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
