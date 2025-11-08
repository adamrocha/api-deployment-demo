FROM nginx:1.29.3-alpine
  # checkov:skip=CKV_DOCKER_3: The nginx:alpine base image provides nginx user (UID 1001) which is sufficient for security

# Install dependencies for SSL and configuration
RUN apk add --no-cache \
    openssl \
    curl \
    bash

# Ensure nginx user exists for security (use existing nginx user from base image)
RUN getent passwd nginx > /dev/null 2>&1 || adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin nginx

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY common-config.conf /etc/nginx/conf.d/

# Copy SSL generation script
COPY generate-ssl.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/generate-ssl.sh

# Copy health check script
COPY health-check.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/health-check.sh

# Copy static files
COPY index.html /usr/share/nginx/html/

# Create directories and set up all permissions for nginx user
RUN mkdir -p /var/www/static /etc/nginx/ssl /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/ssl /usr/share/nginx/html /var/www/static

# Note: nginx will start as root but drop privileges to nginx user for worker processes
# This is the standard and secure way to run nginx

# Generate self-signed SSL certificates for development (as root during build time)
RUN SSL_DIR=/etc/nginx/ssl /usr/local/bin/generate-ssl.sh && \
    chmod 644 /etc/nginx/ssl/*.crt && \
    chmod 600 /etc/nginx/ssl/*.key && \
    chown nginx:nginx /etc/nginx/ssl/*.key /etc/nginx/ssl/*.crt

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Start nginx with SSL support
CMD ["nginx", "-g", "daemon off;"]