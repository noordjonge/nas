#!/bin/bash

# Funktion zur Installation von Vaultwarden
install_vaultwarden() {
    echo "Installing Vaultwarden..."
    sudo docker run -d --name vaultwarden -e ROCKET_PORT=8080 -e 
WEBSOCKET_ENABLED=true -v /home/$(whoami)/vaultwarden:/data -p 8080:80 
--restart=unless-stopped vaultwarden/server:latest
}

# Funktion zur Installation von Jellyfin
install_jellyfin() {
    echo "Installing Jellyfin..."
    sudo docker run -d --name jellyfin -v 
/home/$(whoami)/jellyfin/config:/config -v 
/home/$(whoami)/jellyfin/cache:/cache -v /home/$(whoami)/media:/media -p 
8096:8096 -p 8920:8920 --restart=unless-stopped jellyfin/jellyfin:latest
}

# Update the system
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "Installing Docker..."
sudo apt install -y apt-transport-https ca-certificates curl 
software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg 
--dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) 
signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] 
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo 
tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Start Docker and enable it to start on boot
sudo systemctl start docker
sudo systemctl enable docker

# Install Portainer CE
echo "Installing Portainer CE..."
sudo docker volume create portainer_data
sudo docker run -d -p 9000:9000 -p 9443:9443 --name portainer 
--restart=always -v /var/run/docker.sock:/var/run/docker.sock -v 
portainer_data:/data portainer/portainer-ce:latest

# Install Samba
echo "Installing Samba..."
sudo apt install -y samba avahi-daemon

# Create a new user for Samba
read -p "Enter the username for Samba: " samba_user
sudo adduser $samba_user
sudo smbpasswd -a $samba_user

# Create directories for the new user
echo "Creating directories for the new user..."
sudo mkdir -p /home/$samba_user/Downloads
sudo mkdir -p /home/$samba_user/Dokumente
sudo mkdir -p /home/$samba_user/Bilder
sudo mkdir -p /home/$samba_user/Videos

# Set permissions for the directories
sudo chown -R $samba_user:$samba_user /home/$samba_user
sudo chmod -R 0700 /home/$samba_user

# Create a separate user for Time Machine
echo "Creating a separate user for Time Machine..."
sudo adduser --system --no-create-home --ingroup nogroup --shell 
/usr/sbin/nologin tmuser
sudo smbpasswd -a tmuser

# Create the Time Machine directory and set permissions
echo "Creating the Time Machine directory..."
sudo mkdir -p /home/tmuser/timemachine
sudo chown tmuser:nogroup /home/tmuser/timemachine
sudo chmod 700 /home/tmuser/timemachine

# Configure Samba
echo "Configuring Samba..."
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf_backup
sudo bash -c 'cat <<EOL >> /etc/samba/smb.conf

[global]
   server min protocol = SMB2
   smb encrypt = required
   client signing = mandatory
   server signing = mandatory
   hosts allow = 127.0.0.1 10.10.0.0/24
   hosts deny = 0.0.0.0/0

[homes]
   comment = Home Directories
   browseable = no
   read only = no
   create mask = 0700
   directory mask = 0700
   valid users = %S

[timemachine]
   comment = Time Machine Backup
   path = /home/tmuser/timemachine
   browseable = yes
   read only = no
   valid users = tmuser
   vfs objects = catia fruit streams_xattr
   fruit:time machine = yes
   fruit:time machine max size = 1T
EOL'

# Restart Samba service
sudo systemctl restart smbd

# Configure Avahi for Time Machine
echo "Configuring Avahi for Time Machine..."
sudo bash -c 'cat <<EOL > /etc/avahi/services/samba.service
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
EOL'

sudo systemctl restart avahi-daemon

# Change SSH port
echo "Changing SSH port to 39000..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i 's/#Port 22/Port 39000/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' 
/etc/ssh/sshd_config
sudo systemctl restart ssh

# Update UFW rules
echo "Updating UFW rules..."
sudo ufw allow 39000/tcp
sudo ufw delete allow ssh

# Install Fail2ban
echo "Installing Fail2ban..."
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Install CMake and Ninja
echo "Installing CMake and Ninja..."
sudo apt install -y cmake ninja-build g++

# Install Netdata dependencies
echo "Installing Netdata dependencies..."
sudo apt install -y zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf 
autogen automake pkg-config curl jq nodejs python3 python3-mysqldb 
python3-psycopg2 libbpf-dev

# Install Netdata using kickstart.sh
echo "Installing Netdata..."
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh 
&& sh /tmp/netdata-kickstart.sh --disable-telemetry

# Start and enable Netdata
sudo systemctl start netdata
sudo systemctl enable netdata

# Configure automatic updates
echo "Configuring automatic updates..."
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Secure shared memory
echo "Securing shared memory..."
sudo bash -c 'echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> 
/etc/fstab'
sudo mount -o remount /run/shm

# Enable Docker Content Trust
echo "Enabling Docker Content Trust..."
export DOCKER_CONTENT_TRUST=1

# Instructions for installing Docker in rootless mode
echo "To install Docker in rootless mode, please log in as a non-root user 
and run the following commands:"
echo "curl -fsSL https://get.docker.com/rootless | sh"
echo "export PATH=/usr/bin:\$PATH"
echo "export DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock"
echo "systemctl --user start docker"
echo "systemctl --user enable docker"
echo "sudo loginctl enable-linger \$(whoami)"

# Fragen Sie den Benutzer, ob er Vaultwarden installieren möchte
read -p "Do you want to install Vaultwarden? (y/n): " install_vaultwarden
if [ "$install_vaultwarden" == "y" ]; then
    install_vaultwarden
fi

# Fragen Sie den Benutzer, ob er Jellyfin installieren möchte
read -p "Do you want to install Jellyfin? (y/n): " install_jellyfin
if [ "$install_jellyfin" == "y" ]; then
    install_jellyfin
fi

echo "Setup complete. You can now access the Samba shares, manage Docker 
containers via Portainer, monitor the system with Netdata, and connect via 
SSH on port 39000."
