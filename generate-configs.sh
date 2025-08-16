#!/bin/sh
# generate-configs.sh - v4.1 (The Perfect Mirror Gateway with index.html support)

set -e

CONFIG_DIR="/etc/nginx/conf.d"
CLAW_DOMAIN="pjfhlzclkyhb.ap-southeast-1.clawcloudrun.com"

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation for The Perfect Mirror Gateway ---"

# --- 主配置：动态镜像代理 ---
# 这个server块会处理所有 *.jiamian0128.dpdns.org 的流量
cat > "$CONFIG_DIR/mirror.conf" << EOF
server {
    listen 80;
    # 使用正则表达式匹配并捕获子域名部分
    server_name ~^(?<subdomain>.+)\.jiamian0128\.dpdns\.org$;
    
    # 使用Cloudflare/Google的公共DNS来解析目标
    resolver 1.1.1.1 8.8.8.8 valid=30s;

    location / {
        # 默认使用 http 协议回源
        set \$target_scheme http;
        
        # 如果捕获到的子域名是 'gp'，则强制改用 https 协议
        if (\$subdomain = 'gp') {
            set \$target_scheme https;
        }

        # --- 终极代理指令 ---
        # $host 是Nginx的内置变量，代表客户端请求的原始Host头
        # 例如: "gb.jiamian0128.dpdns.org"
        # $request_uri 是Nginx的内置变量，包含URI和参数，例如 "/config?user=123"
        proxy_pass \$target_scheme://\$host\$request_uri;

        # --- 标准的透明代理头部设置 ---
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        # 告诉后端服务，客户端实际上是通过HTTPS访问的
        proxy_set_header X-Forwarded-Proto https; 
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade"; # 保证WebSocket等协议正常工作
        proxy_buffering off;
    }
}
EOF

# --- 辅助配置：为直接访问爪子云域名提供首页 ---
# 这个server块只会在用户直接访问爪子云URL时生效
cat > "$CONFIG_DIR/default.conf" << EOF
server {
    listen 80;
    server_name ${CLAW_DOMAIN};

    location / {
        # 指向您Dockerfile中复制的index.html所在的位置
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

echo "--- Config generation finished successfully! ---"
