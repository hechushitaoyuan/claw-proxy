FROM nginx:latest

COPY generate-configs.sh /
COPY services.list /
COPY index.html /usr/share/nginx/html/

RUN chmod +x /generate-configs.sh

CMD ["/bin/sh", "-c", "/generate-configs.sh && nginx -g 'daemon off;'"]
