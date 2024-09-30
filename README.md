# Linux Server Setup Script

**Version:** 3.0 
**Author:** Sebastian Palencsár

# NAS Setup Script

This script automates the setup of a Network Attached Storage (NAS) system on Ubuntu 22.04 and later versions.

## Features

- Configures SSH with custom port and user
- Sets up Samba file sharing
- Installs and configures Docker
- Implements basic security measures (firewall, fail2ban)
- Configures automatic system updates
- Optionally installs additional components (Vaultwarden, Jellyfin, Portainer, Netdata)

## Requirements

- Ubuntu 22.04 or later
- Root or sudo access
- Internet connection

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/nas-setup-script.git
   ```

2. Navigate to the script directory:
   ```
   cd nas-setup-script
   ```

3. Make the script executable:
   ```
   chmod +x setup_script.sh
   ```

4. Run the script:
   ```
   sudo ./setup_script.sh
   ```

5. Follow the on-screen prompts to configure your NAS.

## Configuration

You can modify the default settings in the `config.sh` file before running the script.

## Contributing

Contributions are welcome! Please see the [CONTRIBUTING.md](CONTRIBUTING.md) file for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script is provided "as is" without warranty of any kind. Use at your own risk.

## Contributing
Contributions are welcome! Please fork this repository and submit a pull request for any improvements or bug fixes.
