FROM nginx:1.27.3-alpine

# Install dependencies for SSL and configuration
RUN apk add --no-cache \
    openssl \
    curl \
    bash

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

# Create directories
RUN mkdir -p /var/www/static /etc/nginx/ssl /var/log/nginx

# Generate self-signed SSL certificates for development
RUN /usr/local/bin/generate-ssl.sh

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Start nginx with SSL support
CMD ["nginx", "-g", "daemon off;"]