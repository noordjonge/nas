# Linux Server Setup Script

**Version:** 1.4  
**Author:** Sebastian Palencsár

## Overview

This script automates the setup of a Linux server by configuring SSH, installing and setting up Samba, and optionally installing Docker along with additional components like Vaultwarden, Jellyfin, Portainer, and Netdata.

## Features

- **SSH Configuration:** Changes the default SSH port to 39000 and disables root login. A new user is created with sudo privileges.
- **Samba Setup:** Installs and configures Samba. Optionally sets up Time Machine support.
- **Docker Installation:** Installs Docker and Docker Compose if desired.
- **Optional Components:** Installs Vaultwarden, Jellyfin, Portainer, and Netdata based on user preference.
- **Security Enhancements:** Configures automatic updates and secures shared memory.

## Requirements

- **Operating System:** Designed for Ubuntu-based systems. Tested on Ubuntu 22.04 LTS.
- **Permissions:** Root or sudo access is required to execute the script.

## Installation

### Step 1: Clone the Repository

```shell
git clone https://github.com/yourusername/linux-server-setup.git
cd linux-server-setup
```

### Step 2: Review the Configuration

Open config.sh to review and modify any configuration settings as needed.

### Step 3: Run the Script

Execute the setup script with root privileges:

```shell
sudo ./setup_script.sh
```
### Step 4: Follow On-Screen Prompts

The script will guide you through various configuration options:

- Configure SSH settings
- Set up Samba with optional Time Machine support
- Decide whether to install Docker
- Choose additional components to install (Vaultwarden, Jellyfin, etc.)

## Usage

Once installed, you can manage your server using the configured services. 

For example:

- Access Jellyfin at http://yourserverip:8096
- Manage Docker containers using Portainer at http://yourserverip:9000

## Configuration

The script can be customized by editing the config.sh file:

- SSH Port: Change the default port from 39000 to another value if needed.
- User Settings: Specify a different username for SSH and Samba access.

## Known Issues

Ensure that all dependencies are installed before running the script.
Check network configurations if services are not accessible externally.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing
Contributions are welcome! Please fork this repository and submit a pull request for any improvements or bug fixes.
