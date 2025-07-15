#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  # 【最终决战·分流处理】
  # 我们只对gb和npm这两个有问题的应用，启用“内容替换”超能力
  # 对于gp这个本身就很现代化的应用，我们保持原样
  SUB_FILTER_CONFIG=""
  if [ "$service_prefix" = "gb" ] || [ "$service_prefix" = "npm" ]; then
    SUB_FILTER_CONFIG="
        # 开启内容替换
        sub_filter_once off;
        # 把 href=\"/ 替换成 href=\"/${service_prefix}/
        sub_filter 'href=\"/' 'href=\"/${service_prefix}/';
        # 把 src=\"/ 替换成 src=\"/${service_prefix}/
        sub_filter 'src=\"/' 'src=\"/${service_prefix}/';
        # 把 action=\"/ 替换成 action=\"/${service_prefix}/
        sub_filter 'action=\"/' 'action=\"/${service_prefix}/';
    "
  fi

  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    location /${service_prefix}/ {
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
        
        # --- 之前的所有配置都保持完美 ---
        proxy_redirect http://${service_prefix}.${BASE_DOMAIN}/ /${service_prefix}/;
        proxy_redirect https://${service_prefix}.${BASE_DOMAIN}/ /${service_prefix}/;
        proxy_set_header Accept-Encoding \"\"; # 【关键】禁用压缩，sub_filter才能生效
        
        # 【加载超能力】
        ${SUB_FILTER_CONFIG}

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

cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;

    location = / {
        add_header Content-Type text/plain;
        return 200 "jiamian personal domain";
    }

    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
