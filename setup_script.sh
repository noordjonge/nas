#!/bin/bash

# NAS Setup Script - Version 3.0
# This script automates the setup of a NAS system with various services.
# It is designed to run on Ubuntu 22.04 and later versions.

# Copyright - Sebastian Palencsár
# Disclaimer: This script is provided "as is" without any warranty.

set -euo pipefail

# Configuration variables
CONFIG_FILE="/etc/nas_setup.conf"
LOG_FILE="/var/log/setup_script.log"
DEFAULT_SSH_PORT=39000
DEFAULT_USER="nas_user"
DEFAULT_DOCKER_DATA_DIR="/var/lib/docker"
DEBUG=${DEBUG:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging configuration
exec > >(tee -a "${LOG_FILE}") 2>&1

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}" >&2
}

log_debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo -e "${NC}[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}" >> "${LOG_FILE}"
    fi
}

handle_error() {
    "$@"
    if [ "$?" -ne 0 ]; then
        log_error "Error executing $*"
        exit 1
    fi
}

ask_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -rp "$prompt (y/n): " response
        case "$response" in
            [yY]) return 0 ;;
            [nN]) return 1 ;;
            *) echo "Please answer 'y' for yes or 'n' for no." ;;
        esac
    done
}

ask_with_default() {
    local prompt="$1"
    local default="$2"
    local response

    read -rp "$prompt [$default]: " response
    echo "${response:-$default}"
}

show_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    local percentage=$((current * 100 / total))
    printf "\r[%-50s] %d%% %s" $(printf "#%.0s" $(seq 1 $((percentage / 2)))) "$percentage" "$task"
}

check_ubuntu_version() {
    local version=$(lsb_release -rs)
    if (( $(echo "$version < 22.04" | bc -l) )); then
        log_error "This script requires Ubuntu 22.04 or later. Current version: $version"
        exit 1
    fi
}

check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check available disk space
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 10 ]; then
        log_error "Insufficient disk space. At least 10GB required."
        exit 1
    fi
    
    # Check RAM
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 2048 ]; then
        log_error "Insufficient RAM. At least 2GB required."
        exit 1
    fi
    
    log_info "System requirements met."
}

backup_config() {
    local file="$1"
    local backup_dir="/root/nas_setup_backups"
    
    mkdir -p "$backup_dir"
    cp "$file" "${backup_dir}/$(basename "$file").$(date +%Y%m%d%H%M%S).bak"
    log_info "Backup of $file created."
}

configure_network() {
    log_info "Configuring network..."
    
    local interface=$(ip route | awk '/default/ {print $5}')
    local current_ip=$(ip addr show $interface | awk '/inet / {print $2}' | cut -d/ -f1)
    
    read -p "Enter static IP address [$current_ip]: " static_ip
    static_ip=${static_ip:-$current_ip}
    
    read -p "Enter gateway IP: " gateway_ip
    read -p "Enter DNS server IP: " dns_ip
    
    backup_config "/etc/netplan/01-netcfg.yaml"
    
    cat <<EOL | sudo tee /etc/netplan/01-netcfg.yaml > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses: [$static_ip/24]
      routes:
        - to: default
          via: $gateway_ip
      nameservers:
        addresses: [$dns_ip]
EOL
    
    sudo netplan apply
    log_info "Network configuration applied."
}

configure_firewall() {
    log_info "Configuring firewall..."
    
    handle_error sudo apt install -y ufw
    handle_error sudo ufw default deny incoming
    handle_error sudo ufw default allow outgoing
    handle_error sudo ufw allow $NEW_SSH_PORT/tcp
    handle_error sudo ufw allow 80/tcp
    handle_error sudo ufw allow 443/tcp
    handle_error sudo ufw allow Samba
    
    echo "y" | sudo ufw enable
    log_info "Firewall configured and enabled."
}

update_system() {
    log_info "Updating system..."
    handle_error sudo apt update
    handle_error sudo apt upgrade -y
    log_info "System updated successfully."
}

cleanup() {
    log_info "Cleaning up..."
    handle_error sudo apt autoremove -y
    handle_error sudo apt clean
    log_info "Cleanup completed."
}

configure_automatic_updates() {
    log_info "Configuring automatic updates..."
    handle_error sudo apt install -y unattended-upgrades
    handle_error sudo dpkg-reconfigure --priority=low unattended-upgrades
    log_info "Automatic updates configured."
}

secure_shared_memory() {
    log_info "Securing shared memory..."
    echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | sudo tee -a /etc/fstab > /dev/null
    handle_error sudo mount -o remount /run/shm
    log_info "Shared memory secured."
}

install_fail2ban() {
    log_info "Installing and configuring fail2ban..."
    handle_error sudo apt install -y fail2ban
    cat <<EOL | sudo tee /etc/fail2ban/jail.local > /dev/null
[sshd]
enabled = true
port = $NEW_SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOL
    handle_error sudo systemctl restart fail2ban
    log_info "fail2ban installed and configured."
}

setup_basic_monitoring() {
    log_info "Setting up basic system monitoring..."
    handle_error sudo apt install -y htop iotop
    log_info "Basic monitoring tools installed."
}

# Load or create configuration
load_or_create_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration loaded from $CONFIG_FILE."
    else
        log_warn "No configuration file found. Creating a new one."
        NEW_SSH_PORT=$(ask_with_default "Enter desired SSH port" "$DEFAULT_SSH_PORT")
        NEW_USER=$(ask_with_default "Enter desired username" "$DEFAULT_USER")
        DOCKER_DATA_DIR=$(ask_with_default "Enter Docker data directory" "$DEFAULT_DOCKER_DATA_DIR")
        
        cat <<EOL > "$CONFIG_FILE"
NEW_SSH_PORT=$NEW_SSH_PORT
NEW_USER=$NEW_USER
DOCKER_DATA_DIR=$DOCKER_DATA_DIR
EOL
        log_info "New configuration saved to $CONFIG_FILE."
    fi
}

# Main functions
configure_ssh() {
    log_info "Changing SSH port to $NEW_SSH_PORT..."
    backup_config "/etc/ssh/sshd_config"
    handle_error sudo sed -i "s/#Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
    handle_error sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

    if id "$NEW_USER" &>/dev/null; then
       log_info "User $NEW_USER already exists!"
    else
       handle_error sudo adduser "$NEW_USER"
       handle_error sudo usermod -aG sudo "$NEW_USER"
    fi

    handle_error sudo systemctl restart ssh
    log_info "SSH configuration completed. New port: $NEW_SSH_PORT, User: $NEW_USER"
}

setup_samba() {
    log_info "Installing Samba..."
    handle_error sudo apt install -y samba avahi-daemon

    if ! sudo pdbedit -L | grep -q "$NEW_USER"; then
        handle_error sudo smbpasswd -a "$NEW_USER"
    fi

    if ask_yes_no "Do you want to configure Time Machine?"; then
        configure_time_machine
    fi
}

configure_time_machine() {
    log_info "Configuring Time Machine..."
    handle_error sudo mkdir -p /home/tmuser/timemachine
    handle_error sudo chown tmuser:nogroup /home/tmuser/timemachine
    handle_error sudo chmod 700 /home/tmuser/timemachine

    backup_config "/etc/samba/smb.conf"
    cat <<EOL | sudo tee -a /etc/samba/smb.conf > /dev/null
[timemachine]
    comment = Time Machine Backup
    path = /home/tmuser/timemachine
    browseable = yes
    read only = no
    valid users = tmuser
    vfs objects = catia fruit streams_xattr
    fruit:time machine = yes
    fruit:time machine max size = 1T
EOL

    backup_config "/etc/avahi/services/samba.service"
    cat <<EOL | sudo tee /etc/avahi/services/samba.service > /dev/null
<?xml version="1.0" standalone="no"?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=TimeCapsule8,119</txt-record>
  </service>
  <service>
    <type>_adisk._tcp</type>
    <txt-record>dk0=adVN=timemachine,adVF=0x82</txt-record>
    <txt-record>sys=waMa=0,adVF=0x100</txt-record>
  </service>
</service-group>
EOL

    handle_error sudo systemctl restart avahi-daemon
    log_info "Time Machine configuration completed."
}

install_docker() {
    log_info "Installing Docker..."
    handle_error sudo apt install -y apt-transport-https ca-certificates curl software-properties-common uidmap
    handle_error curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    handle_error echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    handle_error sudo apt update
    handle_error sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Configure Docker data directory
    if [[ "$DOCKER_DATA_DIR" != "$DEFAULT_DOCKER_DATA_DIR" ]]; then
        log_info "Configuring Docker data directory to $DOCKER_DATA_DIR..."
        handle_error sudo mkdir -p "$DOCKER_DATA_DIR"
        echo "{\"data-root\": \"$DOCKER_DATA_DIR\"}" | sudo tee /etc/docker/daemon.json > /dev/null
        handle_error sudo systemctl restart docker
    fi

    export DOCKER_CONTENT_TRUST=1

    log_info "Docker installed successfully."
    log_info "Instructions for installing Docker in rootless mode:"
    echo "1. Ensure required packages are installed: uidmap"
    echo "2. Run Docker rootless installation script: curl -fsSL https://get.docker.com/rootless | sh"
    echo "3. Set the following environment variables in your shell profile (e.g., ~/.bashrc):"
    echo "   export PATH=/usr/bin:\$PATH"
    echo "   export DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock"
    echo "4. Start and enable Docker service in user mode:"
    echo "   systemctl --user start docker"
    echo "   systemctl --user enable docker"
    echo "5. Enable linger for the user:"
    echo "   sudo loginctl enable-linger \$(whoami)"
}

install_additional_components() {
    if ask_yes_no "Do you want to install Vaultwarden?"; then
        install_vaultwarden
    fi
    if ask_yes_no "Do you want to install Jellyfin?"; then
        install_jellyfin
    fi
    if ask_yes_no "Do you want to install Portainer?"; then
        install_portainer
    fi
    if ask_yes_no "Do you want to install Netdata?"; then
        install_netdata
    fi
}

# Main script execution
log_info "NAS Setup Script started."

check_ubuntu_version
check_system_requirements

load_or_create_config

update_system

configure_network
configure_ssh
setup_samba
configure_firewall

secure_shared_memory
install_fail2ban
configure_automatic_updates
setup_basic_monitoring

if ask_yes_no "Do you want to install Docker?"; then
    install_docker
fi

if ask_yes_no "Do you want to install additional components?"; then
    install_additional_components
else
    log_info "Installation of additional components skipped."
fi

cleanup

log_info "Setup completed. User $NEW_USER has been created with sudo and Samba access. Installation of optional components completed."
show_progress 100 100 "Setup completed"

log_info "Please reboot your system to ensure all changes take effect."
if ask_yes_no "Do you want to reboot now?"; then
    sudo reboot
fi
