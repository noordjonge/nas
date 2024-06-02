**NAS Ubuntu 22.4 Setup Script**

Dieses Skript verwandelt ein Ubuntu 22.04 System in ein kleines NAS (Network Attached Storage) System. Es installiert und konfiguriert verschiedene Dienste wie Vaultwarden, Jellyfin, Docker, Portainer, Samba und mehr.

## Inhaltsverzeichnis
- [Über das Projekt](#über-das-projekt)
- [Installation](#installation)
- [Verwendung](#verwendung)
- [Dienste](#dienste)
- [Sicherheit](#sicherheit)
- [Konfiguration](#konfiguration)
- [Beitrag](#beitrag)
- [Lizenz](#lizenz)

## Über das Projekt

Dieses Projekt wurde entwickelt, um die Einrichtung eines NAS-Systems auf einem Ubuntu 22.04 Server zu vereinfachen. Es automatisiert die Installation und Konfiguration von wichtigen Diensten und bietet eine benutzerfreundliche Möglichkeit, ein Heimnetzwerk zu verwalten.

## Installation

### Voraussetzungen
- Ubuntu 22.04 Server
- Grundlegende Kenntnisse in der Nutzung von Terminal und SSH

### Schritte zur Installation
1. Klonen Sie das Repository:
   ```bash
   git clone https://github.com/IhrBenutzername/nas-setup.git
   ```
2. Wechseln Sie in das Verzeichnis:
   ```bash
   cd nas-setup
   ```
3. Machen Sie das Skript ausführbar:
   ```bash
   chmod +x nas.sh
   ```
4. Führen Sie das Skript aus:
   ```bash
   ./nas.sh
   ```

## Verwendung

Das Skript führt Sie durch die Installation und Konfiguration der verschiedenen Dienste. Sie werden aufgefordert, Benutzernamen und Passwörter für Samba und andere Dienste einzugeben.

## Dienste

- **Vaultwarden**: Passwortmanager, der als Docker-Container läuft.
- **Jellyfin**: Medienserver, der als Docker-Container läuft.
- **Docker**: Container-Plattform zur Verwaltung von Anwendungen.
- **Portainer**: Webbasierte Benutzeroberfläche zur Verwaltung von Docker-Containern.
- **Samba**: Ermöglicht die Dateifreigabe im Netzwerk.
- **Netdata**: Systemüberwachungstool.

## Sicherheit

Das Skript implementiert mehrere Sicherheitsmaßnahmen:
- Ändert den SSH-Port auf 39000.
- Installiert und konfiguriert Fail2ban zum Schutz vor Brute-Force-Angriffen.
- Aktiviert Docker Content Trust.

## Konfiguration

### Samba
Das Skript erstellt und konfiguriert Samba-Benutzer und Verzeichnisse. Es sichert auch die Samba-Konfigurationsdatei und fügt die notwendigen Einstellungen hinzu.

### Time Machine
Ein separater Benutzer und ein Verzeichnis für Time Machine Backups werden erstellt und konfiguriert.

### Avahi
Avahi wird konfiguriert, um Time Machine im Netzwerk zu bewerben.

## Beitrag

Beiträge zu diesem Projekt sind willkommen. Bitte öffnen Sie ein Issue oder einen Pull Request auf GitHub, um Änderungen vorzuschlagen.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert. Weitere Informationen finden Sie in der LICENSE-Datei.

## Detaillierte Beschreibung der Skriptfunktionen

### Systemaktualisierung und Docker-Installation

1. **Systemaktualisierung**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
   Das Skript aktualisiert das System und installiert alle verfügbaren Updates, um sicherzustellen, dass alle Pakete auf dem neuesten Stand sind.

2. **Docker-Installation**:
   ```bash
   sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt update
   sudo apt install -y docker-ce docker-ce-cli containerd.io
   sudo systemctl start docker
   sudo systemctl enable docker
   ```
   Docker wird installiert und konfiguriert, um beim Systemstart automatisch zu starten.

### Installation und Konfiguration von Diensten

3. **Vaultwarden**:
   ```bash
   sudo docker run -d --name vaultwarden -e ROCKET_PORT=8080 -e WEBSOCKET_ENABLED=true -v /home/$(whoami)/vaultwarden:/data -p 8080:80 --restart=unless-stopped vaultwarden/server:latest
   ```
   Vaultwarden wird als Docker-Container installiert, um als Passwortmanager zu dienen.

4. **Jellyfin**:
   ```bash
   sudo docker run -d --name jellyfin -v /home/$(whoami)/jellyfin/config:/config -v /home/$(whoami)/jellyfin/cache:/cache -v /home/$(whoami)/media:/media -p 8096:8096 -p 8920:8920 --restart=unless-stopped jellyfin/jellyfin:latest
   ```
   Jellyfin wird als Docker-Container installiert, um als Medienserver zu fungieren.

5. **Portainer**:
   ```bash
   sudo docker volume create portainer_data
   sudo docker run -d -p 9000:9000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
   ```
   Portainer wird installiert, um die Verwaltung von Docker-Containern zu erleichtern.

6. **Samba**:
   ```bash
   sudo apt install -y samba avahi-daemon
   ```
   Samba wird installiert, um Dateifreigaben im Netzwerk zu ermöglichen.

### Benutzer- und Verzeichnisverwaltung

7. **Samba-Benutzer und Verzeichnisse**:
   ```bash
   read -p "Enter the username for Samba: " samba_user
   sudo adduser $samba_user
   sudo smbpasswd -a $samba_user
   sudo mkdir -p /home/$samba_user/Downloads /home/$samba_user/Dokumente /home/$samba_user/Bilder /home/$samba_user/Videos
   sudo chown -R $samba_user:$samba_user /home/$samba_user
   sudo chmod -R 0700 /home/$samba_user
   ```
   Ein neuer Benutzer für Samba wird erstellt und entsprechende Verzeichnisse werden angelegt und konfiguriert.

8. **Time Machine Benutzer und Verzeichnis**:
   ```bash
   sudo adduser --system --no-create-home --ingroup nogroup --shell /usr/sbin/nologin tmuser
   sudo smbpasswd -a tmuser
   sudo mkdir -p /home/tmuser/timemachine
   sudo chown tmuser:nogroup /home/tmuser/timemachine
   sudo chmod 700 /home/tmuser/timemachine
   ```
   Ein separater Benutzer und ein Verzeichnis für Time Machine Backups werden erstellt.

### Konfiguration und Sicherheit

9. **Samba-Konfiguration**:
   ```bash
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
   sudo systemctl restart smbd
   ```
   Die Samba-Konfigurationsdatei wird gesichert und angepasst, um die neuen Benutzer und Verzeichnisse zu berücksichtigen.

10. **Avahi-Konfiguration für Time Machine**:
    ```bash
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
    ```
    Avahi wird konfiguriert, um Time Machine im Netzwerk zu bewerben.

11. **Ändern des SSH-Ports**:
    ```bash
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sudo sed -i 's/#Port 22/Port 39000/' /etc/ssh/sshd_config
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    ```
    Der SSH-Port wird auf 39000 geändert, um die Sicherheit zu erhöhen.

12. **Aktualisieren der UFW-Regeln**:
    ```bash
    sudo ufw allow 39000/tcp
    sudo ufw delete allow ssh
    ```
    Die Firewall-Regeln werden aktualisiert, um den neuen SSH-Port zu berücksichtigen.

13. **Fail2ban-Installation**:
    ```bash
    sudo apt install -y fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    ```
    Fail2ban wird installiert und konfiguriert, um Brute-Force-Angriffe zu verhindern.

14. **Installation von CMake und Ninja**:
    ```bash
    sudo apt install -y cmake ninja-build g++
    ```
    CMake und Ninja werden installiert, um die Kompilierung von Software zu erleichtern.

15. **Installation von Netdata-Abhängigkeiten**:
    ```bash
    sudo apt install -y zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autogen automake pkg-config curl jq nodejs python3 python3-mysqldb python3-psycopg2 libbpf-dev
    ```
    Die notwendigen Abhängigkeiten für Netdata werden installiert.

16. **Netdata-Installation**:
    ```bash
    wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh --disable-telemetry
    sudo systemctl start netdata
    sudo systemctl enable netdata
    ```
    Netdata wird installiert und konfiguriert, um das System zu überwachen.

17. **Automatische Updates konfigurieren**:
    ```bash
    sudo apt install -y unattended-upgrades
    sudo dpkg-reconfigure --priority=low unattended-upgrades
    ```
    Automatische Updates werden konfiguriert, um das System aktuell zu halten.

18. **Sichern des Shared Memory**:
    ```bash
    sudo bash -c 'echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab'
    sudo mount -o remount /run/shm
    ```
    Shared Memory wird gesichert, um die Sicherheit zu erhöhen.

19. **Docker Content Trust aktivieren**:
    ```bash
    export DOCKER_CONTENT_TRUST=1
    ```
    Docker Content Trust wird aktiviert, um die Integrität der Docker-Images zu gewährleisten.

### Benutzerinteraktion

20. **Vaultwarden-Installation abfragen**:
    ```bash
    read -p "Do you want to install Vaultwarden? (y/n): " install_vaultwarden
    if [ "$install_vaultwarden" == "y" ]; then
        install_vaultwarden
    fi
    ```
    Der Benutzer wird gefragt, ob Vaultwarden installiert werden soll.

21. **Jellyfin-Installation abfragen**:
    ```bash
    read -p "Do you want to install Jellyfin? (y/n): " install_jellyfin
    if [ "$install_jellyfin" == "y" ]; then
        install_jellyfin
    fi
    ```
    Der Benutzer wird gefragt, ob Jellyfin installiert werden soll.

### Abschluss

22. **Abschlussmeldung**:
    ```bash
    echo "Setup complete. You can now access the Samba shares, manage Docker containers via Portainer, monitor the system with Netdata, and connect via SSH on port 39000."
    ```
    Das Skript gibt eine Abschlussmeldung aus, die den Benutzer darüber informiert, dass die Einrichtung abgeschlossen ist und die verschiedenen Dienste nun verfügbar sind.


**Diese README-Datei enthält alle wesentlichen Informationen, die Benutzer benötigen, um das Skript zu verstehen, zu installieren und zu verwenden. Sie bietet auch klare Anweisungen zur Installation und Konfiguration der verschiedenen Dienste sowie Informationen zur Sicherheit und Benutzerinteraktion.**

## Citations:
[1] https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/19140425/78b43616-5650-4b90-ab6f-8701faff4248/nas.sh<br>
[2] https://www.freecodecamp.org/news/how-to-write-a-good-readme-file/<br>
[3] https://github.com/matiassingers/awesome-readme<br>
[4] https://www.makeareadme.com<br>
[5] https://github.com/jehna/readme-best-practices<br>
[6] https://github.com/othneildrew/Best-README-Template<br>
[7] https://dev.to/yuridevat/how-to-create-a-good-readmemd-file-4pa2<br>
[8] https://www.hatica.io/blog/best-practices-for-github-readme/<br>
[9] https://gist.github.com/DomPizzie/7a5ff55ffa9081f2de27c315f5018afc<br>
[10] https://www.reddit.com/r/learnprogramming/comments/vxfku6/how_to_write_a_readme/<br>
[11] https://tilburgsciencehub.com/topics/collaborate-share/share-your-work/content-creation/readme-best-practices/<br>
[12] https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax<br>
[13] https://docs.readme.com/main/docs/best-practices<br>
[14] https://bulldogjob.com/readme/how-to-write-a-good-readme-for-your-github-project<br>
[15] https://www.linkedin.com/pulse/readmemd-documentation-best-practices-effective-roman-kulibaba-jwavf<br>
[16] https://github.com/abhisheknaiidu/awesome-github-profile-readme<br>
[17] https://dev.to/merlos/how-to-write-a-good-readme-bog<br>
[18] https://everhour.com/blog/github-readme-template/<br>
[19] https://news.ycombinator.com/item?id=36773022<br>
[20] https://gist.github.com/PurpleBooth/109311bb0361f32d87a2
