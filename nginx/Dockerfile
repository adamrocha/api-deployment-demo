FROM nginx:1.28.2-alpine-slim

# Install dependencies, create directories, and set up non-root user
RUN apk add --no-cache \
    openssl=3.5.5-r0 && \
    # Remove default nginx configuration
    rm /etc/nginx/conf.d/default.conf && \
    # Create directories
    mkdir -p /var/cache/nginx /var/run /run /etc/nginx/ssl /var/log/nginx /var/www/static && \
    # Create non-root user and group
    addgroup -g 10001 -S nginx-app && \
    adduser -S -D -H -u 10001 -h /var/cache/nginx -s /sbin/nologin -G nginx-app -g nginx-app nginx-app

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Copy configuration files
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY common-config.conf /etc/nginx/conf.d/

# Copy scripts and static content
COPY generate-ssl.sh /usr/local/bin/
COPY health-check.sh /usr/local/bin/
COPY index.html /usr/share/nginx/html/

# Set permissions and ownership
RUN chmod +x /usr/local/bin/entrypoint.sh \
    /usr/local/bin/generate-ssl.sh \
    /usr/local/bin/health-check.sh && \
    chown -R nginx-app:nginx-app \
    /var/cache/nginx \
    /var/run \
    /run \
    /etc/nginx/ssl \
    /var/log/nginx \
    /usr/share/nginx/html \
    /var/www/static

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Expose non-privileged ports
EXPOSE 8080 8443

# Set working directory
WORKDIR /usr/share/nginx/html

# Switch to non-root user
USER nginx-app

# Start with entrypoint script
CMD ["/usr/local/bin/entrypoint.sh"]