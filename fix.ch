#!/bin/bash
# Fix Apache configuration for homepage

log() {
    echo -e "\033[0;34m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log "Fixing Apache configuration..."

# Create apache config directory
mkdir -p /opt/homelab/configs/apache

# Create the Apache virtual host configuration
cat > /opt/homelab/configs/apache/homepage.conf << 'EOF'
<VirtualHost *:80>
    DocumentRoot /usr/local/apache2/htdocs
    ServerName localhost
    
    # Enable directory browsing and follow symlinks
    <Directory "/usr/local/apache2/htdocs">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Default file
        DirectoryIndex index.html index.htm
    </Directory>
    
    # Security headers
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    
    # Enable compression for better performance
    <IfModule mod_deflate.c>
        SetOutputFilter DEFLATE
        SetEnvIfNoCase Request_URI \
            \.(?:gif|jpe?g|png|ico)$ no-gzip dont-vary
        SetEnvIfNoCase Request_URI \
            \.(?:exe|t?gz|zip|bz2|sit|rar)$ no-gzip dont-vary
    </IfModule>
    
    # Cache static files
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType text/css "access plus 1 month"
        ExpiresByType application/javascript "access plus 1 month"
        ExpiresByType image/png "access plus 1 month"
        ExpiresByType image/jpg "access plus 1 month"
        ExpiresByType image/jpeg "access plus 1 month"
        ExpiresByType image/gif "access plus 1 month"
        ExpiresByType image/ico "access plus 1 month"
        ExpiresByType image/x-icon "access plus 1 month"
    </IfModule>
    
    # Logging
    ErrorLog /usr/local/apache2/logs/error.log
    CustomLog /usr/local/apache2/logs/access.log combined
</VirtualHost>
EOF

# Fix ownership of web directory (Apache needs to read it)
sudo chown -R king:king /opt/homelab/web/

log "Restarting Apache container..."
cd /opt/homelab/configs
docker compose stop homepage
docker compose rm -f homepage
docker compose up -d homepage

# Wait for container to start
sleep 5

# Check if Apache is now running properly
if docker ps | grep -q "homelab-homepage.*Up"; then
    success "Apache container is now running properly!"
    
    # Test if homepage is accessible
    if curl -s http://10.0.0.1 | grep -q "Homelab Dashboard"; then
        success "✅ Homepage is accessible at http://10.0.0.1"
    else
        log "⏳ Homepage starting up, should be ready in a moment"
    fi
else
    log "Checking Apache logs for any remaining issues..."
    docker logs homelab-homepage
fi

log ""
log "🎉 Your homepage should now be available at: http://10.0.0.1"
log "📱 Just type '10.0.0.1' in your browser!"
