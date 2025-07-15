#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation from services.list ---"

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # 净化输入，删除\r
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')

  # 跳过空行和注释行
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  echo "Generating location block for: $service_prefix"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    location /${service_prefix}/ {
        # 【核心武器1：路径处理】
        # 用最安全的方式，把请求发给后端
        proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
        
        # 【核心武器2：重定向处理】
        # 这个规则，现在并且永远都是正确的
        proxy_redirect / /${service_prefix}/;
        
        # 【核心武器3：内容替换引擎 - 武装到牙齿的最终版】
        # 1. 禁用后端压缩，这样我们才能读取并修改内容
        proxy_set_header Accept-Encoding \"\";
        # 2. 告诉Nginx，不要只替换一次，要替换所有匹配项
        sub_filter_once off;
        # 3. 全面替换所有可能的绝对路径引用
        sub_filter 'href=\"/'  'href=\"/${service_prefix}/';
        sub_filter 'src=\"/'   'src=\"/${service_prefix}/';
        sub_filter 'action=\"/' 'action=\"/${service_prefix}/';
        sub_filter 'url(/' 'url(/${service_prefix}/'; # 修复CSS中的url(/...)
        sub_filter '\"/api/' '\"/${service_prefix}/api/'; # 修复JS中的"/api/..."
        sub_filter '\'/api/' '\'/${service_prefix}/api/'; # 修复JS中的'/api/...'

        # --- 其他所有头部设置，都保持完美 ---
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

cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name _;

    location = / {
        add_header Content-Type text/plain;
        return 200 "tjad6894 is running.";
    }

    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
