
# debapps - Bash scripts to simplify Debian Linux app installations.
### Compatible with most [x64] Debian based Linux distros (including Kali, Ubuntu, PopOS)

- These scripts will work with most Debian based Linux distros such as Ubuntu, Kali and Pop!_OS.
- Includes menu options to both installing and also removing the applications.

### Usage Options
Option 1. (Quick) Copy and paste the one line terminal command below:
```
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/bradsec/debapps/main/debapps.sh)"
```

### Example of main menu:
```terminal
     ____  __________  ___    ____  ____  _____
    / __ \/ ____/ __ )/   |  / __ \/ __ \/ ___/
   / / / / __/ / __  / /| | / /_/ / /_/ /\__ \ 
  / /_/ / /___/ /_/ / ___ |/ ____/ ____/___/ / 
 /_____/_____/_____/_/  |_/_/   /_/    /____/  

 ========================
  Application Categories 
 ========================

  1. Password manager apps
  2. Note apps
  3. Messenger apps
  4. Office apps
  5. Collaboration apps
  6. Web browsers and other web apps
  7. Code editor apps
  8. Virtual machine apps
  9. Burp Suite apps

 10. Go (golang) installer
 11. Unifi Network Application (controller) for Raspberry Pi

 12. Exit

```

Option 2. Clone the repo and run the required script on the local machine.
```terminal
git clone https://github.com/bradsec/debapps.git
sudo bash ./debapps/passwordapps.sh
```
Option 3. Alternatively run the required specific application script remotely. 
```
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/bradsec/debapps/main/src/passwordapps.sh)"
```



Scriptname | Compatability | Applications
---|---|---
<a href="https://github.com/bradsec/debapps/tree/main/src/passwordapps.sh" target="_blank">passwordapps.sh</a> | Debian/Ubuntu | Bitwarden, KeePassXC |
<a href="https://github.com/bradsec/debapps/tree/main/src/noteapps.sh" target="_blank">noteapps.sh</a> | Debian/Ubuntu | Joplin, Standard Notes, Obsidian |
<a href="https://github.com/bradsec/debapps/tree/main/src/messengerapps.sh" target="_blank">messengerapps.sh</a> | Debian/Ubuntu | Signal, Threema
<a href="https://github.com/bradsec/debapps/tree/main/src/officeapps.sh" target="_blank">officeapps.sh</a> | Debian/Ubuntu | OnlyOffice, LibreOffice
<a href="https://github.com/bradsec/debapps/tree/main/src/collabapps.sh" target="_blank">collabapps.sh</a> | Debian/Ubuntu | Discord, Slack, Zoom, Microsoft Teams
<a href="https://github.com/bradsec/debapps/tree/main/src/webapps.sh" target="_blank">webapps.sh</a> | Debian/Ubuntu | Firefox, Google Chrome, Brave, TOR Browser, Postman API Tool
<a href="https://github.com/bradsec/debapps/tree/main/src/codeeditapps.sh" target="_blank">codeeditapps.sh</a> | Debian/Ubuntu | Sublime-Text 3 & 4, Visual Studio Codium, Microsoft Visual Studio Code (VSCode)
<a href="https://github.com/bradsec/debapps/tree/main/src/vmapps.sh" target="_blank">vmapps.sh</a> | Debian/Ubuntu | VMWare Workstation & Player, Oracle VirtualBox - GUI Installer
<a href="https://github.com/bradsec/debapps/tree/main/src/burpapps.sh" target="_blank">burpapps.sh</a> | Debian/Ubuntu | PortSwigger Burp Suite Community or Professional Editions - GUI Installer
<a href="https://github.com/bradsec/debapps/tree/main/src/goapps.sh" target="_blank">goapps.sh</a> | Debian/Ubuntu | Go (golang) Programming Language (**)
<a href="https://github.com/bradsec/debapps/tree/main/src/unifiapps.sh" target="_blank">unifiapps.sh</a> | Raspberry Pi | Unifi Network Application (Controller) (**)

### Notes
* **As the scripts need to install files and change permissions outside of user home directories they require `sudo` or superuser priviledges.**
* Scripts inherit common functions from the imported <a href="https://github.com/bradsec/debapps/tree/main/src/templates" target="_blank">templates</a>.
* Menu options for application installation and removal are provided in each script.  
* Where possible installers will use latest sources from original author/publisher sites or github release repos instead of using Flatpaks or Snap Store package installs. AppImages are used for some applications.  
* File hashes (MD5, SHA1, SHA256) will be shown during installation for any downloaded packages or files for security comparison with the publisher.
* **UPGRADING** For applications which do not auto-update or update by running `sudo apt update && sudo apt upgrade`, just re-run the install option/script to upgrade the package.
* Most of the Debian app installers fetch x64 sources, the script sources may need modification to run on other system architecture such as x86 (32-bit) or arm processors.

### Troubleshooting 

- If an install fails. Try running the remove app option then try install again. If it continues to fail raise an issue with details including hardware and OS version details.
- Some GNOME desktop icons may not appear until GNOME is shell is reloaded. Try logging out and back in.

#### ** Go (golang) install
If the Go path is not found for a non-root user try running the following command:  
`source /etc/profile.d/go.sh`

#### ** Raspberry Pi Unifi Network Application (Controller) install
* Reboot Raspberry Pi after installation or removal.  
* **After install be patient** - The unifi service can a couple of minutes to start-up. After 2-5 minutes the service should change from `activating to active`.
* Restoring from a backup unifi configuration file also takes a few minutes. If you are concerned the controller has hung or frozen run the `top` terminal command you can see if unifi java processes are running.
* If you get a Java error (in status of service) on service start-up try stopping and restarting the service or rebooting.
* **Tested on May-05-2023** - Unifi Network Application 7.3.83 on RPI 3 Model B running Raspberry Pi OS 64-bit Debian 11 (bullseye)
* Check status of unifi service using: `sudo systemctl status unifi`  
```terminal
#### Sample output of running (sudo systemctl status unifi) check for [Active: active (running)]
● unifi.service - unifi
     Loaded: loaded (/lib/systemd/system/unifi.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2023-05-03 16:35:14 AEST; 369ms ago
    Process: 526 ExecStartPre=/usr/sbin/unifi-network-service-helper init (code=exited, status=0/SUCCESS)
    Process: 585 ExecStartPre=/usr/sbin/unifi-network-service-helper init-uos (code=exited, status=0/SUCCESS)
    Process: 606 ExecStartPost=/usr/sbin/unifi-network-service-helper healthcheck (code=exited, status=0/SUCCESS)
   Main PID: 605 (java)
      Tasks: 85 (limit: 779)
        CPU: 4min 3.558s
     CGroup: /system.slice/unifi.service
             ├─ 605 /usr/bin/java -Dfile.encoding=UTF-8 -Djava.awt.headless=true -Dapple.awt.UIElement=true -Dunifi.cor>
             └─2108 bin/mongod --dbpath /usr/lib/unifi/data/db --port 27117 --unixSocketPrefix /usr/lib/unifi/run --log>
```
* Once the service is running you can access the Unifi controller via a browser - https://localhost:8443 or https://unifihostipaddress:8443
* This needs to be HTTPS not HTTP otherwise you will get bad request. The Unifi controller runs on port 8443 by default. If you don't specify this at the end of the address you will get unable to connect or not found. 
* You will receive a self-signed certificate (SSL) warning which you will need to accept and elect to continue. If you are running on your own domain there are options to use a LetsEncrypt or other certificate provider to use your own certificate to remove this warning. This is out of scope of this guide as it will require a fair bit setup and depends on your network configuration.  
