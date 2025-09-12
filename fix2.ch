#!/bin/bash
# Fix Apache with simpler configuration

log() {
    echo -e "\033[0;34m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log "Fixing Apache container with simpler configuration..."

cd /opt/homelab/configs

# Stop and remove the broken container
log "Stopping broken Apache container..."
docker compose stop homepage
docker compose rm -f homepage

# Create a backup of current docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)

# Replace the problematic Apache service with a simpler version
log "Updating docker-compose.yml with simpler Apache configuration..."

# Remove the old homepage service (everything after "# Apache - Homelab Homepage")
sed -i '/# Apache - Homelab Homepage/,$d' docker-compose.yml

# Add the corrected Apache service
cat >> docker-compose.yml << 'EOF'

  # Apache - Homelab Homepage (Simple)
  homepage:
    container_name: homelab-homepage
    image: httpd:alpine
    ports:
      - "80:80"
    volumes:
      - /opt/homelab/web:/usr/local/apache2/htdocs:ro
    restart: unless-stopped
    environment:
      - TZ=Europe/London
EOF

log "Starting Apache container with new configuration..."
docker compose up -d homepage

# Wait for container to start
sleep 5

# Check if it's working
if docker ps | grep -q "homelab-homepage.*Up"; then
    success "Apache container is now running!"
    
    # Test homepage
    sleep 2
    if curl -s http://10.0.0.1 | grep -q "Homelab Dashboard"; then
        success "✅ Homepage is accessible at http://10.0.0.1"
        log ""
        log "🎉 SUCCESS! Your homepage is now working!"
        log "📱 Open your browser and go to: http://10.0.0.1"
        log ""
        log "From there you can access:"
        log "• ESPHome (ESP32 development): Click the ESPHome link"
        log "• Portainer (Docker management): Click the Portainer link"
        log "• Home Assistant: Click the Home Assistant link"
        log "• All other services with one click!"
    else
        log "Container started but homepage not ready yet. Give it a moment..."
        log "Try: http://10.0.0.1 in your browser"
    fi
else
    log "Container still having issues. Checking logs..."
    docker logs homelab-homepage
fi
