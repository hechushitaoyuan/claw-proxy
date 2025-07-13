# 最终版 Dockerfile

FROM nginx:alpine

# 设置工作目录
WORKDIR /app

# 复制脚本和列表文件到容器中
COPY generate-configs.sh .
COPY services.list .

# 赋予生成脚本可执行权限
RUN chmod +x ./generate-configs.sh

# 创建一个默认的server配置，以便Nginx能启动
# 并且加载我们即将生成的所有配置
RUN echo "server { \
        listen 80; \
        server_name _; \
        location = / { add_header Content-Type text/plain; return 200 'Gateway is running.'; } \
        include /etc/nginx/conf.d/*.conf; \
    }" > /etc/nginx/conf.d/default.conf

# 关键命令！
# 在容器启动时，先执行我们的生成脚本，
# && 表示只有脚本成功执行后，才继续执行后面的命令
# nginx -g 'daemon off;' 是让Nginx在前台运行的标准容器化做法
CMD sh /app/generate-configs.sh && nginx -g 'daemon off;'
