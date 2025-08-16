#!/bin/sh
# generate-configs.sh - v2.1 (Subdomain Model with external services.list)

set -e

CONFIG_DIR="/etc/nginx/conf.d"
# 新的统一访问域名，这个可以根据你在Cloudflare DNS的设置进行修改
PROXY_DOMAIN="proxy.jiamian0128.dpdns.org"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation (Subdomain Model) from services.list ---"

# 检查 services.list 文件是否存在
if [ ! -f "services.list" ]; then
    echo "Error: services.list file not found!"
    exit 1
fi

# 从 services.list 逐行读取配置
# IFS=, 指定逗号为分隔符
while IFS=, read -r service_prefix target_host || [ -n "$service_prefix" ]; do
    # 去除可能存在的行尾回车符
    service_prefix=$(echo -n "$service_prefix" | tr -d '\r')
    target_host=$(echo -n "$target_host" | tr -d '\r')

    # 跳过空行和注释行
    if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
        continue
    fi
    
    # 构造将要监听的子域名
    server_name="${service_prefix}.${PROXY_DOMAIN}"
  
    # Cloudflare Pages/Worker (gp) 需要使用 HTTPS 协议回源
    scheme="http"
    if [ "$service_prefix" = "gp" ]; then
        scheme="https"
    fi

    echo "Generating route for: ${server_name} -> ${scheme}://${target_host}"

    cat > "$CONFIG_DIR/${service_prefix}.conf" << EOF
server {
    listen 80;
    server_name ${server_name};

    # 使用Cloudflare的DNS解析器
    resolver 1.1.1.1 valid=30s;

    location / {
        # 纯粹的代理，无内容修改
        proxy_pass ${scheme}://${target_host};

        # 标准代理头设置
        proxy_set_header Host ${target_host};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }
}
EOF
done < services.list

# 为根域名创建一个默认的欢迎页面
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name ${PROXY_DOMAIN};

    location / {
        return 200 'Claw-Proxy v2.1 is active. Access your services via subdomains like gb.${PROXY_DOMAIN}';
        add_header Content-Type text/plain;
    }
}
EOF

echo "--- Config generation finished successfully! ---"
