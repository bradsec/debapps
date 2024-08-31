
# debapps - Bash scripts to simplify Debian Linux app installations.

- These scripts will work with most Debian based Linux distros such as Ubuntu, Kali and Pop!_OS.
- Includes menu options to both installing and also removing the applications.

### USAGE
Option 1. (Quick) Copy and paste the one line terminal command below:
```
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/bradsec/debapps/main/debapps.sh)"
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

### Example of main menu:
```terminal
     ____  __________  ___    ____  ____  _____
    / __ \/ ____/ __ )/   |  / __ \/ __ \/ ___/
   / / / / __/ / __  / /| | / /_/ / /_/ /\__ \ 
  / /_/ / /___/ /_/ / ___ |/ ____/ ____/___/ / 
 /_____/_____/_____/_/  |_/_/   /_/    /____/  

 Bash scripts to simplify Linux app installations.
 Compatible with most [x64] Debian based distros.

 ========================
  Application Categories 
 ========================

  1. Password Manager apps
  2. Note apps
  3. Messenger apps
  4. Office apps
  5. Collaboration apps
  6. Web Browsers and Web API Tools
  7. Code Editor apps
  8. Virtual Machine (VM) apps
  9. Burp Suite apps

 10. Exit

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




