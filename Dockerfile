FROM nginx:latest

# 工作目录
WORKDIR /app

# 复制我们的脚本和列表
COPY generate-configs.sh .
COPY services.list .

# 赋予权限
RUN chmod +x ./generate-configs.sh

# 启动命令
CMD ["sh", "-c", "sh /app/generate-configs.sh && nginx -g 'daemon off;'"]
