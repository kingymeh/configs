#!/bin/bash
# Setup homelab homepage as default on port 80

log() {
    echo -e "\033[0;34m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log "Setting up homepage as default on port 80..."

# Create web directory
mkdir -p /opt/homelab/web

# Create the homepage HTML file
cat > /opt/homelab/web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Homelab Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh;
            color: white;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        
        .status-bar {
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 30px;
            text-align: center;
        }
        
        .status-item {
            display: inline-block;
            margin: 0 20px;
        }
        
        .status-dot {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #4CAF50;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .service-category {
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            padding: 25px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
        }
        
        .category-title {
            font-size: 1.5rem;
            margin-bottom: 20px;
            color: #FFD700;
            border-bottom: 2px solid #FFD700;
            padding-bottom: 10px;
        }
        
        .service-link {
            display: block;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 10px;
            text-decoration: none;
            color: white;
            transition: all 0.3s ease;
            border: 1px solid transparent;
        }
        
        .service-link:hover {
            background: rgba(255,255,255,0.2);
            border-color: rgba(255,255,255,0.3);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        
        .service-name {
            font-size: 1.1rem;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .service-desc {
            font-size: 0.9rem;
            opacity: 0.8;
            margin-bottom: 5px;
        }
        
        .service-url {
            font-size: 0.8rem;
            opacity: 0.6;
            font-family: monospace;
        }
        
        .info-section {
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            padding: 25px;
            margin-top: 30px;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
        }
        
        .info-item h3 {
            color: #FFD700;
            margin-bottom: 10px;
        }
        
        .info-item code {
            background: rgba(0,0,0,0.3);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: monospace;
        }
        
        .footer {
            text-align: center;
            margin-top: 40px;
            opacity: 0.7;
        }
        
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2rem;
            }
            
            .services-grid {
                grid-template-columns: 1fr;
            }
            
            .status-item {
                display: block;
                margin: 10px 0;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 Homelab Dashboard</h1>
            <p>Your Smart Home Development Environment</p>
        </div>
        
        <div class="status-bar">
            <div class="status-item">
                <span class="status-dot"></span>
                <span>System Online</span>
            </div>
            <div class="status-item">
                <span class="status-dot"></span>
                <span>Services Running</span>
            </div>
            <div class="status-item">
                <span class="status-dot"></span>
                <span>Network: 10.0.0.1</span>
            </div>
        </div>
        
        <div class="services-grid">
            <div class="service-category">
                <h2 class="category-title">🔧 Development Tools</h2>
                
                <a href="http://10.0.0.1:6052" class="service-link" target="_blank">
                    <div class="service-name">ESPHome</div>
                    <div class="service-desc">ESP32/ESP8266 Firmware Builder</div>
                    <div class="service-url">10.0.0.1:6052</div>
                </a>
                
                <a href="http://10.0.0.1:9000" class="service-link" target="_blank">
                    <div class="service-name">Portainer</div>
                    <div class="service-desc">Docker Container Management</div>
                    <div class="service-url">10.0.0.1:9000</div>
                </a>
                
                <a href="http://10.0.0.1:1880" class="service-link" target="_blank">
                    <div class="service-name">Node-RED</div>
                    <div class="service-desc">Visual Programming & Automation</div>
                    <div class="service-url">10.0.0.1:1880</div>
                </a>
            </div>
            
            <div class="service-category">
                <h2 class="category-title">🏡 Smart Home</h2>
                
                <a href="http://10.0.0.1:8123" class="service-link" target="_blank">
                    <div class="service-name">Home Assistant</div>
                    <div class="service-desc">Smart Home Hub & Automation</div>
                    <div class="service-url">10.0.0.1:8123</div>
                </a>
                
                <a href="http://10.0.0.1:7575" class="service-link" target="_blank">
                    <div class="service-name">Homarr</div>
                    <div class="service-desc">Advanced Dashboard</div>
                    <div class="service-url">10.0.0.1:7575</div>
                </a>
            </div>
            
            <div class="service-category">
                <h2 class="category-title">📡 Core Services</h2>
                
                <div class="service-link" style="cursor: default;">
                    <div class="service-name">MQTT Broker</div>
                    <div class="service-desc">Device Communication Hub</div>
                    <div class="service-url">10.0.0.1:1883</div>
                </div>
                
                <div class="service-link" style="cursor: default;">
                    <div class="service-name">MariaDB</div>
                    <div class="service-desc">Database Server</div>
                    <div class="service-url">10.0.0.1:3306</div>
                </div>
            </div>
        </div>
        
        <div class="info-section">
            <h2 style="text-align: center; margin-bottom: 25px; color: #FFD700;">🚀 Quick Start Guide</h2>
            <div class="info-grid">
                <div class="info-item">
                    <h3>ESP32 Development</h3>
                    <p>1. Open <strong>ESPHome</strong> (port 6052)</p>
                    <p>2. Create new device configuration</p>
                    <p>3. Flash firmware to your ESP32</p>
                    <p>4. Connect to MQTT: <code>10.0.0.1:1883</code></p>
                </div>
                
                <div class="info-item">
                    <h3>Automation Testing</h3>
                    <p>1. Use <strong>Node-RED</strong> for visual programming</p>
                    <p>2. Connect to MQTT broker</p>
                    <p>3. Test device interactions</p>
                    <p>4. Deploy to Home Assistant</p>
                </div>
                
                <div class="info-item">
                    <h3>System Management</h3>
                    <p>1. <strong>Portainer</strong> for container management</p>
                    <p>2. Check logs and resource usage</p>
                    <p>3. Start/stop services as needed</p>
                    <p>4. Update container images</p>
                </div>
                
                <div class="info-item">
                    <h3>Network Info</h3>
                    <p>Server IP: <code>10.0.0.1</code></p>
                    <p>MQTT: <code>10.0.0.1:1883</code></p>
                    <p>SSH: <code>ssh user@10.0.0.1</code></p>
                    <p>Config: <code>/opt/homelab/configs/</code></p>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Homelab Development Environment | Last updated: <span id="timestamp"></span></p>
        </div>
    </div>
    
    <script>
        // Update timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Simple service availability checker
        function checkService(url, element) {
            fetch(url, { mode: 'no-cors' })
                .then(() => {
                    element.style.opacity = '1';
                })
                .catch(() => {
                    element.style.opacity = '0.5';
                });
        }
        
        // Check all service links on page load
        document.addEventListener('DOMContentLoaded', function() {
            const serviceLinks = document.querySelectorAll('.service-link[href]');
            serviceLinks.forEach(link => {
                if (link.href) {
                    checkService(link.href, link);
                }
            });
        });
    </script>
</body>
</html>
EOF

# Create nginx config
mkdir -p /opt/homelab/configs/nginx

cat > /opt/homelab/configs/nginx/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # Enable gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

log "Checking current Docker Compose configuration..."

# Check if homepage service already exists
if grep -q "homepage:" /opt/homelab/configs/docker-compose.yml; then
    warning "Homepage service already exists in docker-compose.yml"
    log "Updating existing configuration..."
    
    # Stop existing homepage if running
    cd /opt/homelab/configs
    docker compose stop homepage || true
    docker compose rm -f homepage || true
else
    log "Adding new homepage service..."
fi

# Check for existing nginx service or port conflicts
if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q ":80->"; then
    warning "Port 80 is already in use by another container"
    
    # Find what's using port 80
    CONTAINER_USING_80=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":80->" | awk '{print $1}')
    log "Container using port 80: $CONTAINER_USING_80"
    
    # If it's not our homepage, we need to handle this
    if [[ "$CONTAINER_USING_80" != "homelab-homepage" ]]; then
        warning "Another service is using port 80. Using port 8080 instead."
        PORT="8080:80"
        ACCESS_URL="http://10.0.0.1:8080"
    else
        PORT="80:80"
        ACCESS_URL="http://10.0.0.1"
    fi
else
    PORT="80:80"
    ACCESS_URL="http://10.0.0.1"
fi

# Backup current docker-compose.yml
cp /opt/homelab/configs/docker-compose.yml /opt/homelab/configs/docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)

# Remove existing homepage service if it exists
sed -i '/# Nginx - Homelab Homepage/,/^$/d' /opt/homelab/configs/docker-compose.yml
sed -i '/homepage:/,/^  [a-zA-Z]/d' /opt/homelab/configs/docker-compose.yml
sed -i '/homelab-homepage:/,/^  [a-zA-Z]/d' /opt/homelab/configs/docker-compose.yml

# Add homepage service to docker-compose.yml
cat >> /opt/homelab/configs/docker-compose.yml << EOF

  # Nginx - Homelab Homepage (Default)
  homepage:
    container_name: homelab-homepage
    image: nginx:alpine
    ports:
      - "$PORT"
    volumes:
      - /opt/homelab/web:/usr/share/nginx/html:ro
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
    environment:
      - TZ=Europe/London
EOF

# Start the homepage service
log "Starting homepage service..."
cd /opt/homelab/configs
docker compose up -d homepage

# Wait a moment for the service to start
sleep 5

# Check if the service started successfully
if docker compose ps homepage | grep -q "Up"; then
    success "Homepage service started successfully!"
else
    warning "Homepage service may not have started correctly. Checking logs..."
    docker compose logs homepage
fi

# Update UFW if needed
if [[ "$PORT" == "80:80" ]]; then
    # Port 80 should already be allowed, but let's make sure
    if ! sudo ufw status | grep -q "80/tcp"; then
        sudo ufw allow 80/tcp comment "HTTP Homepage"
    fi
else
    # Using port 8080
    if ! sudo ufw status | grep -q "8080/tcp"; then
        sudo ufw allow 8080/tcp comment "Homelab Homepage"
    fi
fi

success "Homepage setup complete!"
log ""
log "🎉 Your homelab homepage is now the default page!"
log ""
log "📱 Access your homelab:"
log "   Just go to: $ACCESS_URL"
log "   Or bookmark: $ACCESS_URL"
log ""
log "🚀 Quick access to all services from your homepage:"
log "   • ESPHome (ESP32 dev): Click to go to 10.0.0.1:6052"
log "   • Portainer (Docker): Click to go to 10.0.0.1:9000"
log "   • Home Assistant: Click to go to 10.0.0.1:8123"
log "   • Node-RED: Click to go to 10.0.0.1:1880"
log "   • Homarr (Advanced): Click to go to 10.0.0.1:7575"
log ""
log "💡 Now you can just type '10.0.0.1' and get instant access to everything!"

# Test if the homepage is accessible
log "Testing homepage accessibility..."
if curl -s "$ACCESS_URL" | grep -q "Homelab Dashboard"; then
    success "✅ Homepage is accessible and working!"
else
    warning "⚠️  Homepage may not be fully accessible yet. Give it a moment to start up."
fi
