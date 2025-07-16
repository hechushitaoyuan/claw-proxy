# Dockerfile
FROM nginx:latest

# 把我们唯一的、正确的配置文件生成脚本，复制进去
COPY generate-configs.sh /
# 把我们的服务列表，复制进去
COPY services.list /
# 把我们专属的欢迎页面，复制进去
COPY index.html /usr/share/nginx/html/

# 赋予脚本执行权限
RUN chmod +x /generate-configs.sh

# 启动命令：先生成配置，再启动Nginx
CMD ["/bin/sh", "-c", "/generate-configs.sh && nginx -g 'daemon off;'"]
