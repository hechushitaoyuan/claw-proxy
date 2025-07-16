#!/bin/sh

set -e

CONFIG_DIR="/etc/nginx/conf.d"
# 这是您在文档中定义的 claw-proxy 的上游目标
# 我们直接从 Cloudflare Tunnel 主机名构建配置
BASE_DOMAIN="jiamian0128.dpdns.org" 

rm -f $CONFIG_DIR/*.conf

echo "--- Starting config generation for the Path-Aware Proxy ---"

SERVICE_LOCATIONS=""
while IFS=, read -r service_prefix target_url || [ -n "$service_prefix" ]; do
  # 清理可能存在的行尾回车符
  service_prefix=$(echo -n "$service_prefix" | tr -d '\r')
  target_url=$(echo -n "$target_url" | tr -d '\r')

  # 跳过空行和注释行
  if [ -z "$service_prefix" ] || [ "${service_prefix#\#}" != "$service_prefix" ]; then
    continue
  fi

  # 如果 services.list 中没有提供完整的 URL，则根据前缀构建
  if [ -z "$target_url" ]; then
    target_url="http://${service_prefix}.${BASE_DOMAIN}"
  fi
  
  # 从完整 URL 中提取 Host，用于 proxy_set_header
  target_host=$(echo "$target_url" | awk -F/ '{print $3}')

  echo "Generating path-aware route for: /${service_prefix}/ -> ${target_url}/"
  
  SERVICE_LOCATIONS="${SERVICE_LOCATIONS}
    # 为 /${service_prefix}/ 创建一个路径感知的代理通道
    location /${service_prefix}/ {
        # --- 黄金法则 1: [传入] 请求路径重写 ---
        # proxy_pass 必须带斜杠，将 /prefix/path 映射到后端的 /path
        proxy_pass ${target_url}/;
        
        # --- 黄金法则 2: [传出] HTTP重定向头修正 ---
        # 将后端的 Location: /foo 重写为 Location: /prefix/foo
        proxy_redirect default; # 使用默认规则通常足够
        proxy_redirect / /${service_prefix}/;

        # --- 黄金法则 3 (您思考的终点): [传出] 响应体内容重写 ---
        # 使用 sub_filter 修正HTML/JS/CSS中的绝对路径链接
        sub_filter_once off; # 允许页面内多次替换
        sub_filter 'href="/' 'href="/${service_prefix}/';
        sub_filter 'src="/' 'src="/${service_prefix}/';
        sub_filter 'action="/' 'action="/${service_prefix}/';
        sub_filter 'url("/' 'url("/${service_prefix}/';
        # 修正可能由JS动态生成的链接
        sub_filter '=".' '="/${service_prefix}/.';
        sub_filter "'/" "'/${service_prefix}/";

        # 移除上游可能设置的压缩，否则sub_filter可能失效
        proxy_set_header Accept-Encoding "";

        # --- 标准头部设置 ---
        proxy_set_header Host ${target_host};
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
    listen 8080; # 爪子云的容器端口是8080
    server_name _;

    resolver 1.1.1.1; # 使用公共DNS解析上游

    root /usr/share/nginx/html;
    index index.html;

    location = / {
        try_files \$uri \$uri/ =404;
    }
    
    # 加载我们所有的服务通道
    ${SERVICE_LOCATIONS}
}
EOF

echo "--- Config generation finished successfully! ---"
