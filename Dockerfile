# 终极决战版 Dockerfile V5 - 放弃动态生成，使用静态COPY

FROM nginx:latest

# 设置工作目录
WORKDIR /app

# 复制脚本和列表文件
COPY generate-configs.sh .
COPY services.list .

# 【关键决战修改】
# 删除所有RUN echo命令，直接复制我们预先创建好的default.conf文件。
# 这将100%避免任何诡异的shell解析bug！
COPY default.conf /etc/nginx/conf.d/default.conf

# 赋予生成脚本可执行权限
RUN chmod +x ./generate-configs.sh

# 使用推荐的Exec格式来编写CMD命令
CMD ["sh", "-c", "sh /app/generate-configs.sh && nginx -g 'daemon off;'"]
