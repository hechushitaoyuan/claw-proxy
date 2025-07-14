FROM nginx:latest
COPY nginx.conf /etc/nginx/nginx.conf
WORKDIR /app
COPY generate-configs.sh .
COPY services.list .
RUN chmod +x ./generate-configs.sh
CMD ["sh", "-c", "sh /app/generate-configs.sh && nginx -g 'daemon off;'"]
