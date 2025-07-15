#!/bin/sh
# ... (前面的代码保持不变) ...

SERVICE_LOCATIONS=""
while read -r service_prefix; do
  # ... (净化输入的代码保持不变) ...
  # ... (跳过注释的代码保持不变) ...

  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    location /${service_prefix}/ {
        # 我们只做一件事：把请求，通过内部代理，发给一个只属于这个服务的、虚拟的server块
        proxy_pass http://${service_prefix}_server;

        # --- 其他所有头部设置，都保持完美 ---
        proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
        proxy_set_header X-Real-IP \$remote_addr;
        # ... (其他header) ...
    }
  "
done < services.list

UPSTREAM_SERVERS=""
while read -r service_prefix; do
  # ... (净化和跳过注释的代码) ...

  UPSTREAM_SERVERS="${UPSTREAM_SERVERS}
    # 为每个服务创建一个独立的、虚拟的server
    server {
        listen 80; # 这只是一个占位符
        server_name ${service_prefix}_server;

        location / {
            # 这里的proxy_pass将完美工作！
            proxy_pass http://${service_prefix}.${BASE_DOMAIN}/;
            proxy_set_header Host ${service_prefix}.${BASE_DOMAIN};
            # ... (其他header) ...
        }
    }
  "
done < services.list

cat > "$CONFIG_DIR/default.conf" << EOF
# 主server，负责接收外部流量
server {
    listen 80;
    server_name _;

    location = / { # ... (欢迎页面) ... }

    # 加载我们所有的路径分发规则
    ${SERVICE_LOCATIONS}
}

# 加载我们所有虚拟的后端server
${UPSTREAM_SERVERS}
EOF

# ... (脚本结束) ...
