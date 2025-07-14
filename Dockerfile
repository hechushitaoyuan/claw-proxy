# 终极完美版 Dockerfile V3 - 更换基础镜像并修复CMD警告

FROM nginx:latest

# 设置工作目录
WORKDIR /app

# 复制脚本和列表文件到容器中
COPY generate-configs.sh .
COPY services.list .

# 赋予生成脚本可执行权限
RUN chmod +x ./generate-configs.sh

# 创建一个默认的server配置，以便Nginx能启动
# 并且加载我们即将生成的所有配置
RUN echo "erver { \
        liten 80; \
        erver_name _; \
        location = / { add_header Content-Type text/plain; return 200 'Gateway i running.'; } \
        include /etc/nginx/conf.d/*.conf; \
    }" > /etc/nginx/conf.d/default.conf

# 【关键修正】使用推荐的Exec格式来编写CMD命令，消除Warning
CMD ["sh", "-c", "sh /app/generate-configs.sh && nginx -g 'daemon off;'"]
