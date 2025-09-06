#!/bin/bash
# homelab-bootstrap.sh - Complete homelab deployment script
# Usage: ./homelab-bootstrap.sh [environment] [client-name]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:-development}"
CLIENT_NAME="${2:-demo}"
INSTALL_LOG="/var/log/homelab-install.log"

# Network Configuration
NUC_IP="10.0.0.1"
PI5_IP="10.0.0.2"
ROUTER_IP="10.0.0.254"
NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$INSTALL_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$INSTALL_LOG"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$INSTALL_LOG"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$INSTALL_LOG"
}

# Pre-installation checks
pre_checks() {
    log "Starting pre-installation checks..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
    fi
    
    # Check OS compatibility
    if ! command -v apt-get &> /dev/null; then
        error "This script requires a Debian-based system"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        error "Internet connectivity required"
    fi
    
    # Check available disk space (minimum 10GB)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE_SPACE -lt 10485760 ]]; then  # 10GB in KB
        error "Insufficient disk space. Minimum 10GB required"
    fi
    
    success "Pre-installation checks passed"
}

# Configure static IP address
setup_static_ip() {
    log "Configuring static IP address..."
    
    # Backup current netplan configuration
    sudo cp /etc/netplan/*.yaml /etc/netplan/backup-$(date +%Y%m%d_%H%M%S).yaml 2>/dev/null || true
    
    # Create new netplan configuration
    cat << EOF | sudo tee /etc/netplan/01-homelab-static.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $NETWORK_INTERFACE:
      dhcp4: false
      addresses:
        - $NUC_IP/24
      routes:
        - to: default
          via: $ROUTER_IP
      nameservers:
        addresses:
          - $PI5_IP
          - 1.1.1.1
          - 1.0.0.1
      optional: true
EOF

    # Apply netplan configuration
    sudo netplan apply
    
    # Wait for network to stabilize
    sleep 5
    
    # Verify static IP is set
    CURRENT_IP=$(ip addr show $NETWORK_INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    if [[ "$CURRENT_IP" == "$NUC_IP" ]]; then
        success "Static IP configured successfully: $NUC_IP"
    else
        warning "Static IP may not have applied correctly. Current IP: $CURRENT_IP"
    fi
}

# System updates and basic packages
system_setup() {
    log "Setting up system basics..."
    
    # Update system
    sudo apt-get update && sudo apt-get upgrade -y
    
    # Install essential packages
    sudo apt-get install -y \
        curl \
        wget \
        git \
        htop \
        nano \
        vim \
        ufw \
        fail2ban \
        unzip \
        python3 \
        python3-pip \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        rsync \
        jq \
        avahi-daemon \
        openssh-server
    
    # Install development tools for microcontroller work
    sudo apt-get install -y \
        build-essential \
        python3-dev \
        python3-venv \
        arduino \
        minicom \
        screen
    
    success "System setup complete"
}

# Docker installation
install_docker() {
    log "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Test Docker installation
    if docker --version &> /dev/null; then
        success "Docker installed successfully"
    else
        error "Docker installation failed"
    fi
}

# Network configuration
setup_network() {
    log "Configuring network settings..."
    
    # Configure UFW firewall
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH
    sudo ufw allow 22/tcp comment "SSH"
    
    # Allow HTTP/HTTPS
    sudo ufw allow 80/tcp comment "HTTP"
    sudo ufw allow 443/tcp comment "HTTPS"
    
    # Allow local network access
    sudo ufw allow from 10.0.0.0/24 comment "Local network"
    sudo ufw allow from 192.168.0.0/16 comment "Private networks"
    
    # Allow specific homelab services
    sudo ufw allow 8123/tcp comment "Home Assistant"
    sudo ufw allow 1883/tcp comment "MQTT"
    sudo ufw allow 7575/tcp comment "Homarr Dashboard"
    sudo ufw allow 9000/tcp comment "Portainer"
    sudo ufw allow 1880/tcp comment "Node-RED"
    sudo ufw allow 6052/tcp comment "ESPHome"
    sudo ufw allow 3000/tcp comment "Grafana"
    sudo ufw allow 8080/tcp comment "Zigbee2MQTT"
    
    # Enable firewall
    sudo ufw --force enable
    
    success "Network configuration complete"
}

# Create Docker Compose configuration
create_docker_configs() {
    log "Creating Docker Compose configuration..."
    
    # Create docker-compose.yml
    cat > /opt/homelab/configs/docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Home Assistant - Smart Home Hub
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
      - TZ=Europe/London
    depends_on:
      - mosquitto
      - mariadb

  # MQTT Broker - Device Communication
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
      - TZ=Europe/London

  # MariaDB - Database for Home Assistant
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
      - TZ=Europe/London

  # Homarr - Dashboard
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
      - TZ=Europe/London

  # Portainer - Docker Management
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
      - TZ=Europe/London

  # ESPHome - Microcontroller Management
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
      - TZ=Europe/London

  # Node-RED - Visual Automation
  nodered:
    container_name: nodered
    image: nodered/node-red:latest
    ports:
      - "1880:1880"
    volumes:
      - ./nodered:/data
    restart: unless-stopped
    environment:
      - TZ=Europe/London
    depends_on:
      - mosquitto

  # Code Server - Web-based IDE for development
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
      - TZ=Europe/London
    user: "1000:1000"
EOF

    # Create environment file
    cat > /opt/homelab/configs/.env << 'EOF'
# Homelab Environment Configuration

# Timezone
TZ=Europe/London

# Database Passwords (Change these!)
MYSQL_ROOT_PASSWORD=homelab_root_password_change_me
MYSQL_DATABASE=homeassistant
MYSQL_USER=homeassistant
MYSQL_PASSWORD=homeassistant_password_change_me

# Code Server Password (Change this!)
CODE_SERVER_PASSWORD=development_password_change_me

# Network Configuration
HOMELAB_NETWORK=10.0.0.0/24
NUC_IP=10.0.0.1
PI5_IP=10.0.0.2
ROUTER_IP=10.0.0.254

# Client Configuration
CLIENT_NAME=demo
ENVIRONMENT=development
EOF

    # Create basic MQTT configuration
    mkdir -p /opt/homelab/configs/mosquitto/config
    cat > /opt/homelab/configs/mosquitto/config/mosquitto.conf << 'EOF'
# Mosquitto configuration
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout

# Allow anonymous connections (change for production)
allow_anonymous true

# Listeners
listener 1883
protocol mqtt

listener 9001
protocol websockets
EOF

    success "Docker configuration files created"
}

# Homelab services deployment
deploy_services() {
    log "Deploying homelab services..."
    
    # Create directory structure
    sudo mkdir -p /opt/homelab/{configs,data,backups,scripts}
    sudo chown -R $USER:$USER /opt/homelab
    
    # Create Docker configurations
    create_docker_configs
    
    # Create necessary directories for volumes
    mkdir -p /opt/homelab/configs/{homeassistant,mosquitto/{config,data,log},mariadb,homarr/{configs,icons,data},portainer,nodered,esphome,code-server}
    
    # Deploy Docker Compose stack
    cd /opt/homelab/configs
    docker compose pull
    docker compose up -d
    
    success "Services deployed"
}

# Security configuration
setup_security() {
    log "Configuring security settings..."
    
    # Configure fail2ban
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    
    # SSH security
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    
    # Set up automatic security updates
    sudo apt-get install -y unattended-upgrades
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
    
    success "Security configuration complete"
}

# Backup configuration
setup_backups() {
    log "Setting up backup system..."
    
    # Install restic
    RESTIC_VERSION="0.16.2"
    wget "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2"
    bunzip2 "restic_${RESTIC_VERSION}_linux_amd64.bz2"
    sudo mv "restic_${RESTIC_VERSION}_linux_amd64" /usr/local/bin/restic
    sudo chmod +x /usr/local/bin/restic
    
    # Create backup script
    cat > /opt/homelab/scripts/backup.sh << 'EOF'
#!/bin/bash
# Automated backup script
export RESTIC_REPOSITORY="/opt/backups/homelab"
export RESTIC_PASSWORD_FILE="/opt/homelab/configs/backup-password"

# Create backup
restic backup /opt/homelab/configs /opt/homelab/data \
    --tag daily \
    --exclude-caches \
    --exclude '*.log' \
    --exclude '*.tmp'

# Cleanup old backups
restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --prune
EOF
    
    chmod +x /opt/homelab/scripts/backup.sh
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/homelab/scripts/backup.sh") | crontab -
    
    success "Backup system configured"
}

# Main execution
main() {
    log "Starting homelab bootstrap for environment: $ENVIRONMENT, client: $CLIENT_NAME"
    
    pre_checks
    setup_static_ip
    system_setup
    install_docker
    setup_network
    deploy_services
    setup_security
    setup_backups
    
    success "Homelab bootstrap completed successfully!"
    log "Please reboot the system to ensure all changes take effect"
    log "Installation log saved to: $INSTALL_LOG"
    
    # Display next steps
    cat << EOF

${GREEN}Installation Complete!${NC}

Static IP Address: $NUC_IP

Next Steps:
1. Reboot the system: sudo reboot
2. Access services at:
   - Homarr Dashboard: http://$NUC_IP:7575
   - Home Assistant: http://$NUC_IP:8123
   - Portainer: http://$NUC_IP:9000
   - ESPHome: http://$NUC_IP:6052
   - Node-RED: http://$NUC_IP:1880
   - Code Server: http://$NUC_IP:8443

3. Configure devices and automations
4. Change default passwords in /opt/homelab/configs/.env

Documentation: /opt/homelab/configs/README.md
Support: Check logs at $INSTALL_LOG

EOF
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
