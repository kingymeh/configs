#!/bin/bash
# docker-homelab-setup.sh - Docker installation and homelab deployment
# Usage: ./docker-homelab-setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
check_user() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
    fi
    log "User check passed"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    # Update system
    sudo apt update && sudo apt upgrade -y
    
    # Install prerequisites
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release wget git nano
    
    # Remove old Docker versions
    sudo apt remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    success "Docker installation complete"
}

# Set up static IP
setup_static_ip() {
    log "Setting up static IP address..."
    
    # Detect network interface
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    log "Detected network interface: $NETWORK_INTERFACE"
    
    # Backup existing interfaces file
    sudo cp /etc/network/interfaces /etc/network/interfaces.backup-$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    # Create new interfaces configuration
    sudo tee /etc/network/interfaces > /dev/null << EOF
# This file describes the network interfaces available on your system
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# Static IP configuration for primary interface
auto $NETWORK_INTERFACE
iface $NETWORK_INTERFACE inet static
    address 10.0.0.1
    netmask 255.255.255.0
    gateway 10.0.0.254
    dns-nameservers 10.0.0.2 1.1.1.1
EOF

    # Restart networking
    log "Applying network configuration..."
    sudo systemctl restart networking || {
        warning "Network restart failed, trying alternative method..."
        sudo ifdown $NETWORK_INTERFACE && sudo ifup $NETWORK_INTERFACE
    }
    
    sleep 5
    
    # Verify static IP
    CURRENT_IP=$(ip addr show $NETWORK_INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    if [[ "$CURRENT_IP" == "10.0.0.1" ]]; then
        success "Static IP configured successfully: $CURRENT_IP"
    else
        warning "Static IP may not have applied correctly. Current IP: $CURRENT_IP"
    fi
}

# Create homelab directory structure
create_directories() {
    log "Creating homelab directory structure..."
    
    sudo mkdir -p /opt/homelab/{configs,data,backups,scripts}
    sudo chown -R $USER:$USER /opt/homelab
    
    mkdir -p /opt/homelab/configs/{homeassistant,mosquitto/{config,data,log},mariadb,homarr/{configs,icons,data},portainer,nodered,esphome,code-server}
    
    success "Directory structure created"
}

# Create Docker Compose file
create_docker_compose() {
    log "Creating Docker Compose configuration..."
    
    cd /opt/homelab/configs
    
    cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'
services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    volumes:
      - ./homeassistant:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/dbus:/run/dbus:ro
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=${TZ}
    depends_on:
      - mosquitto
      - mariadb

  mosquitto:
    container_name: mosquitto
    image: eclipse-mosquitto:latest
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
    restart: unless-stopped
    environment:
      - TZ=${TZ}

  mariadb:
    container_name: homeassistant-db
    image: mariadb:latest
    ports:
      - "3306:3306"
    volumes:
      - ./mariadb:/var/lib/mysql
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - TZ=${TZ}

  homarr:
    container_name: homarr
    image: ghcr.io/ajnart/homarr:latest
    ports:
      - "7575:7575"
    volumes:
      - ./homarr/configs:/app/data/configs
      - ./homarr/icons:/app/public/icons
      - ./homarr/data:/data
    restart: unless-stopped
    environment:
      - TZ=${TZ}

  portainer:
    container_name: portainer
    image: portainer/portainer-ce:latest
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer:/data
    restart: unless-stopped
    environment:
      - TZ=${TZ}

  esphome:
    container_name: esphome
    image: ghcr.io/esphome/esphome:latest
    ports:
      - "6052:6052"
    volumes:
      - ./esphome:/config
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=${TZ}

  nodered:
    container_name: nodered
    image: nodered/node-red:latest
    ports:
      - "1880:1880"
    volumes:
      - ./nodered:/data
    restart: unless-stopped
    environment:
      - TZ=${TZ}
    depends_on:
      - mosquitto

  code-server:
    container_name: code-server
    image: codercom/code-server:latest
    ports:
      - "8443:8080"
    volumes:
      - ./code-server:/home/coder
      - /opt/homelab:/home/coder/homelab
    restart: unless-stopped
    environment:
      - PASSWORD=${CODE_SERVER_PASSWORD}
      - TZ=${TZ}
    user: "1000:1000"
COMPOSE_EOF

    success "Docker Compose file created"
}

# Create environment file
create_env_file() {
    log "Creating environment file..."
    
    cat > /opt/homelab/configs/.env << 'ENV_EOF'
TZ=Europe/London
MYSQL_ROOT_PASSWORD=homelab_root_password_change_me
MYSQL_DATABASE=homeassistant
MYSQL_USER=homeassistant
MYSQL_PASSWORD=homeassistant_password_change_me
CODE_SERVER_PASSWORD=development_password_change_me
ENV_EOF

    success "Environment file created"
}

# Create MQTT config
create_mqtt_config() {
    log "Creating MQTT configuration..."
    
    cat > /opt/homelab/configs/mosquitto/config/mosquitto.conf << 'MQTT_EOF'
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
allow_anonymous true
listener 1883
protocol mqtt
listener 9001
protocol websockets
MQTT_EOF

    success "MQTT configuration created"
}

# Deploy services
deploy_services() {
    log "Deploying homelab services..."
    
    cd /opt/homelab/configs
    
    # Pull Docker images
    log "Pulling Docker images..."
    sudo docker compose pull
    
    # Start services
    log "Starting services..."
    sudo docker compose up -d
    
    success "Services deployed"
}

# Verify deployment
verify_deployment() {
    log "Verifying service deployment..."
    
    cd /opt/homelab/configs
    sleep 10
    
    sudo docker compose ps
    
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}=== HOMELAB SETUP COMPLETE ===${NC}"
    echo -e "${BLUE}Services available at:${NC}"
    echo -e "  • Homarr Dashboard: http://$CURRENT_IP:7575"
    echo -e "  • Home Assistant:   http://$CURRENT_IP:8123"
    echo -e "  • Portainer:        http://$CURRENT_IP:9000"
    echo -e "  • ESPHome:          http://$CURRENT_IP:6052"
    echo -e "  • Node-RED:         http://$CURRENT_IP:1880"
    echo -e "  • Code Server:      http://$CURRENT_IP:8443"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo -e "  • Change passwords in /opt/homelab/configs/.env"
    echo -e "  • Services may take 2-5 minutes to start"
    echo -e "  • Logout/login for Docker group membership"
    echo ""
}

# Main execution
main() {
    log "Starting homelab setup..."
    
    check_user
    install_docker
    setup_static_ip
    create_directories
    create_docker_compose
    create_env_file
    create_mqtt_config
    deploy_services
    verify_deployment
    
    log "Setup completed successfully!"
}

main "$@"
