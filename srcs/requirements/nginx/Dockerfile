FROM debian:bullseye-slim
ENV DEBIAN_FRONTEND=noninteractive
COPY tools/install.sh /tmp/install.sh
RUN sh /tmp/install.sh
RUN mkdir -p /etc/nginx/ssl && \
openssl req -x509 -nodes -days 365 \
-newkey rsa:2048 \
-keyout /etc/nginx/ssl/wordpress.key \
-out /etc/nginx/ssl/wordpress.crt \
-subj "/CN=shapetit.local"
COPY conf/nginx.conf /etc/nginx/sites-available/default
EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]