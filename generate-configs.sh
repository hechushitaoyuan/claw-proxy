#!/bin/sh

# 让脚本在出错时立即退出
set -e

# 定义配置文件的输出目录
CONFIG_DIR="/etc/nginx/conf.d"
# 定义源域名
BASE_DOMAIN="jiamian0128.dpdns.org"

# 创建输出目录（如果不存在）
mkdir -p $CONFIG_DIR

echo "--- Starting config generation from services.list ---"

# 逐行读取 services.list 文件
while read service_prefix || [ -n "$service_prefix" ]; do
  # 跳过空行和以#开头的注释行
  if [ -z "$service_prefix" ] || echo "$service_prefix" | grep -q "^#"; then
    continue
  fi

  echo "Generating config for: $service_prefix"
  
  # 使用 "here document" 语法动态生成配置文件
  # 这是Shell脚本中生成多行文本的强大技巧
  cat > "$CONFIG_DIR/$service_prefix.conf" << EOF
# Auto-generated for $service_prefix

location /$service_prefix/ {
    proxy_pass https://$service_prefix.$BASE_DOMAIN/;
    proxy_set_header Host $service_prefix.$BASE_DOMAIN;

    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_buffering off;
}
EOF
done < services.list

echo "--- Config generation finished successfully! ---"
