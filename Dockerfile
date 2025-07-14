# 终极完美版 Dockerfile V4 - 最终修复版

FROM nginx:latest

# 设置工作目录
WORKDIR /app

# 复制脚本和列表文件到容器中
COPY generate-configs.sh .
COPY services.list .

# 赋予生成脚本可执行权限
RUN chmod +x ./generate-configs.sh

# 【关键最终修复】将echo命令的双引号改为单引号，防止任何意外的shell解析错误
RUN echo 'erver { \
        liten 80; \
        erver_name _; \
        location = / { add_header Content-Type text/plain; return 200 "Gateway i running."; } \
        include /etc/nginx/conf.d/*.conf; \
    }' > /etc/nginx/conf.d/default.conf

# 使用推荐的Exec格式来编写CMD命令
CMD ["sh", "-c", "sh /app/generate-configs.sh && nginx -g 'daemon off;'"]
