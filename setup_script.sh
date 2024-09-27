#!/bin/bashhttps://github.com/noordjonge/nas/blob/main/nas.sh

# Copyright - Sebastian Palencsár - Version 1.4
# Disclaimer: This script is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the script or the use or other dealings in the script.

set -euo pipefail

# Logging configuration
LOG_FILE="/var/log/setup_script.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
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

configure_ssh() {
	local ssh_port="$1"
	local user="$2"

	log_info "Changing SSH port to $ssh_port..."
	handle_error sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
	handle_error sudo sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
	handle_error sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

	if id "$user" &>/dev/null; then
	   log_info "User $user already exists!"
	else
	   handle_error sudo adduser "$user"
	   handle_error sudo usermod -aG sudo "$user"
	fi

	handle_error sudo systemctl restart ssh
}

setup_samba() {
	local user="$1"

	log_info "Installing Samba..."
	handle_error sudo apt install -y samba avahi-daemon

	if ! sudo pdbedit -L | grep -q "$user"; then
		handle_error sudo smbpasswd -a "$user"
	fi

	if ask_yes_no "Do you want to configure Time Machine?"; then
		log_info "Configuring Time Machine..."
		handle_error sudo mkdir -p /home/tmuser/timemachine
		handle_error sudo chown tmuser:nogroup /home/tmuser/timemachine
		handle_error sudo chmod 700 /home/tmuser/timemachine

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
   fi 
}

install_docker() {
   log_info "Installing Docker..."
   handle_error sudo apt install -y apt-transport-https ca-certificates curl software-properties-common uidmap 
   handle_error curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 
   handle_error echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 
   handle_error sudo apt update 
   handle_error sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 

   export DOCKER_CONTENT_TRUST=1 
   
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

install_vaultwarden() {
   local user="$1"
   local data_dir="/home/${user}/vaultwarden"
   local port="8080"

   log_info "Installing Vaultwarden..."
   
   if [[ ! -d "$data_dir" ]]; then 
	  handle_error sudo mkdir -p "$data_dir"
	  handle_error sudo chown "${user}:${user}" "$data_dir"
   fi 

   handle_error sudo docker run -d --name vaultwarden \
	  -e ROCKET_PORT="$port" \
	  -e WEBSOCKET_ENABLED=true \
	  -v "${data_dir}:/data" \
	  -p "${port}:80" \
	  --restart=unless-stopped \
	  vaultwarden/server:latest 

   log_info "Vaultwarden installed successfully and running on port $port."
}

install_jellyfin() {
   local user="$1"
   local config_dir="/home/${user}/jellyfin/config"
   local cache_dir="/home/${user}/jellyfin/cache"
   local media_dir="/home/${user}/media"
   local port="8096"

   log_info "Installing Jellyfin..."
   
   for dir in "$config_dir" "$cache_dir" "$media_dir"; do 
	  if [[ ! -d "$dir" ]]; then 
		 handle_error sudo mkdir -p "$dir"
		 handle_error sudo chown "${user}:${user}" "$dir"
	  fi 
   done 

   handle_error sudo docker run -d --name jellyfin \
	  -v "${config_dir}:/config" \
	  -v "${cache_dir}:/cache" \
	  -v "${media_dir}:/media" \
	  -p "${port}:8096" \
	  --restart=unless-stopped \
	  jellyfin/jellyfin:latest 

   log_info "Jellyfin installed successfully and running on port $port."
}

install_portainer() {
   local port="9000"

   log_info "Installing Portainer CE..."
   
   handle_error sudo docker volume create portainer_data 
   handle_error sudo docker run -d -p "${port}:9000" -p 9443:9443 --name portainer \
	  --restart=always \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  -v portainer_data:/data portainer/portainer-ce:latest 

   log_info "Portainer installed successfully and running on port $port."
}

install_netdata() {
   log_info "Installing Netdata..."
   
   bash <(curl -Ss https://my-netdata.io/kickstart.sh) --non-interactive || true 

   log_info "Netdata installed successfully."
}

secure_shared_memory() {
echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' | sudotee-a/etc/fstab||true  
handle_errorsudo mount-o remount/run/shm||true  
log_info'Secured shared memory.'  
}
secure_shared_memory||true  

configure_automatic_updates() {
log_info'Configuring automatic updates...'  
handle_errorsudo apt install-y unattended-upgrades||true  
handle_errorsudo dpkg-reconfigure--priority=low unattended-upgrades||true  
}
configure_automatic_updates||true  

# Main script execution starts here.
NEW_SSH_PORT=39000
NEW_USER="new_user"

configure_ssh "$NEW_SSH_PORT" "$NEW_USER"
setup_samba "$NEW_USER"

if ask_yes_no 'Do you want to install Docker?'; then install_docker; fi

if ask_yes_no 'Do you want to install additional components?'; then 
if ask_yes_no 'Do you want to install Vaultwarden?'; then install_vaultwarden "$NEW_USER"; fi  
if ask_yes_no 'Do you want to install Jellyfin?'; then install_jellyfin "$NEW_USER"; fi  
if ask_yes_no 'Do you want to install Portainer?'; then install_portainer; fi  
if ask_yes_no 'Do you want to install Netdata?'; then install_netdata; fi  
else  
log_info'Installation of additional components skipped.'  
fi  

log_info'Setup complete. User$NEW_USER has been created with sudo and Samba access. Installation of optional components completed.'  
