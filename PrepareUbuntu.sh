#!/bin/bash
# Install Commons Apps for Ubuntu
#
# Autor: Edwin Mantilla Santamaría
# Usage: ./PrepareUbuntu.sh

KEYS_DIR="/etc/apt/trusted.gpg.d"
SOURCES_DIR="/etc/apt/sources.list.d"
SSH_DIR="${HOME}/.ssh"
SSL_DIR="/etc/ssl/private"
TEMP_DIR="/tmp"
DOMAIN="hackpro.co"

USER_NAME="Edwin Mantilla Santamaria"
USER_EMAIL="hackpro.ems@gmail.com"
USER_REGION="CO"
USER_CITY="Bogota D.C"
USER_COMPANY="HACKPRO TEAM"
USER_TEAM="Developer Team"

SSL_TYPE="rsa"
SSL_SIZE="4096"

#####################
# General Functions #
#####################
function install_repository_keys {
  local KEY_NAME="${1}"
  local KEY_URL="${2}"
  local SOURCE_NAME="${3}"
  local SOURCE_INFO="${4}"

  if [[ -z "${KEY_NAME}" ]]; then
    echo "Missing parameter KEY_NAME."
    exit 1
  fi

  if [[ -z "${KEY_URL}" ]]; then
    echo "Missing parameter KEY_URL."
    exit 2
  fi

  if [[ -z "${SOURCE_NAME}" ]]; then
    echo "Missing parameter SOURCE_NAME."
    exit 3
  fi

  if [[ -z "${SOURCE_INFO}" ]]; then
    echo "Missing parameter SOURCE_INFO."
    exit 4
  fi

  curl -sS -o "${TEMP_DIR}/${KEY_NAME}.tmp" "${KEY_URL}"
  gpg --dearmor -o "${TEMP_DIR}/${KEY_NAME}" "${TEMP_DIR}/${KEY_NAME}.tmp"
  sudo install -o "root" -g "root" -m "644" "${TEMP_DIR}/${KEY_NAME}" "${KEYS_DIR}"
  rm -f "${TEMP_DIR}/${KEY_NAME}.tmp" "${TEMP_DIR}/${KEY_NAME}"

  echo "${SOURCE_INFO}" | sudo tee "${SOURCES_DIR}/${SOURCE_NAME}"
}

##########################
# Install Pre-Requisites #
##########################
# Install required packages
sudo apt install apt-transport-https ca-certificates curl dirmngr gdebi-core gvfs jq libjson-perl net-tools sed software-properties-common wget


#############################
# Install and Configure SSH #
#############################
sudo apt install openssh-server
sudo systemctl status ssh

# Create SSL Certicate for hackpro.co
sudo openssl req -x509 -nodes -days 1825 -newkey "${SSL_TYPE}:${SSL_SIZE}" -keyout "${SSL_DIR}/${DOMAIN}.key" -out "${SSL_DIR}/${DOMAIN}.cer" -subj "/C=${USER_REGION}/ST=${USER_CITY}/L=${USER_CITY}/O=${USER_COMPANY}/OU=${USER_TEAM}/emailAddress=${USER_EMAIL}/CN=*.${DOMAIN}"
sudo chmod -R g+r "${SSL_DIR}/${DOMAIN}.key"

# Create SSH Key
ssh-keygen -t "${SSL_TYPE}" -b "${SSL_SIZE}" -C "${USER_EMAIL}"
eval "$(ssh-agent -s)"
ssh-add "${SSH_DIR}/id_${SSL_TYPE}"
cat "${SSH_DIR}/id_${SSL_TYPE}.pub"

ssh-keygen -f "${SSH_DIR}/id_${SSL_TYPE}.pub" -e -m PKCS8 > "${SSH_DIR}/id_${SSL_TYPE}.pem.pub"


############################################
# Install Disk and Partition Manager Tools #
############################################
# -Source: https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer
sudo add-apt-repository ppa:danielrichter2007/grub-customizer
sudo apt update
sudo apt install grub-customizer

sudo apt install gparted

# -Source: https://www.omgubuntu.co.uk/2017/06/create-bootable-windows-10-usb-ubuntu
sudo add-apt-repository ppa:tomtomtom/woeusb
sudo apt update
sudo apt install woeusb-frontend-wxgtk


#######################
# Install Pulse Audio #
#######################
sudo apt install pulseaudio pavucontrol


################
# Install Java #
################
# -Source: https://www.digitalocean.com/community/tutorials/how-to-install-java-with-apt-on-ubuntu-18-04
sudo apt install default-jdk
JAVAPATH=$(update-alternatives --query java | grep "Value: " | cut -c8-)
ROW_MATCH=$(sudo grep -n -m1 -E "^JAVA_HOME=.*$" "/etc/environment" | cut -d: -f1)
if [[ -n "${ROW_MATCH}" ]]; then
  sudo sed -i -e "${ROW_MATCH}s|.*|JAVA_HOME=${JAVAPATH:0:-4}|" "/etc/environment"
else
  echo "JAVA_HOME=${JAVAPATH:0:-4}" | sudo tee -a "/etc/environment"
fi
# shellcheck source=/dev/null
source "/etc/environment"


###############
# Install Git #
###############
# -Source: https://www.digitalocean.com/community/tutorials/how-to-install-git-on-ubuntu-18-04
sudo apt install git
sudo apt install git-cola

git config --global user.name "${USER_NAME}"
git config --global user.email "${USER_EMAIL}"


#########################
# Install Google Chrome #
#########################
FILENAME="google-chrome-stable_current_amd64.deb"
wget "https://dl.google.com/linux/direct/${FILENAME}" --directory-prefix="${TEMP_DIR}"
sudo dpkg --install "${TEMP_DIR}/${FILENAME}"
rm -f "${TEMP_DIR}/${FILENAME}"


##############################
# Install Apache HTTP Server #
##############################
# -Source: https://www.digitalocean.com/community/tutorials/como-instalar-el-servidor-web-apache-en-ubuntu-18-04-es
sudo apt install apache2
sudo ufw allow "Apache Full"
sudo mkdir -p "/var/www/${DOMAIN}/html"
sudo chown -R "${USER}:${USER}" "/var/www/${DOMAIN}/html"
sudo chmod -R 755 "/var/www/${DOMAIN}"

# Configure Apache HTTP Server
sudo sh -c "cat <<EOT > /var/www/${DOMAIN}/html/index.html
<html>
  <head>
    <title>Bienvenido a Hackpro Team</title>
  </head>
  <body>
    <h1>El proceso ha sido exitoso. El bloque de servidor ${DOMAIN} se encuentra en funcionamiento.</h1>
  </body>
</html>
EOT"

sudo sh -c "cat <<EOT >> /etc/apache2/sites-available/${DOMAIN}.conf
<VirtualHost *:80>
  ServerAdmin ${USER_EMAIL}
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot /var/www/${DOMAIN}/html
  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOT"

sudo a2ensite "${DOMAIN}.conf"
sudo a2dissite "000-default.conf"

ROW_MATCH=$(sudo grep -n -m1 -E "^ServerName .*$" "/etc/apache2/apache2.conf" | cut -d: -f1)
if [[ -z "${ROW_MATCH}" ]]; then
  echo "ServerName 127.0.0.1" | sudo tee -a "/etc/apache2/apache2.conf"
fi

# Check Apache services
sudo apache2ctl configtest
sudo systemctl restart apache2
sudo systemctl status apache2


################################
# Install Node Version Manager #
################################
# -Source: https://github.com/nvm-sh/nvm#install-script
curl -sS -o "${TEMP_DIR}/install_nvm.sh" "https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh"
bash "${TEMP_DIR}/install_nvm.sh"
rm -f "${TEMP_DIR}/install_nvm.sh"
# shellcheck source=/dev/null
source "${HOME}/.profile"


##################
# Install NodeJs #
##################
# -Source: https://github.com/creationix/nvm#usage
# -Prerequisites: Install Node Version Manager
nvm install --lts
nvm alias default stable
nvm use --lts


################
# Install Yarn #
################
# -Source: https://yarnpkg.com/en/docs/install#debian-stable
# -Prerequisites: Install NodeJs
install_repository_keys "yarnpkg.gpg" "https://dl.yarnpkg.com/debian/pubkey.gpg"

echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee "${SOURCES_DIR}/yarn.list"
sudo apt update
sudo apt install --no-install-recommends yarn


##############################
# Install Visual Studio Code #
##############################
KEY_NAME="microsoft"
curl -sS -o "${TEMP_DIR}/${KEY_NAME}.asc" "https://packages.microsoft.com/keys/microsoft.asc"
gpg --dearmor -o "${TEMP_DIR}/${KEY_NAME}.gpg" "${TEMP_DIR}/${KEY_NAME}.asc"
sudo install -o root -g root -m 644 "${TEMP_DIR}/${KEY_NAME}.gpg" "${KEYS_DIR}"
echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee "${SOURCES_DIR}/vscode.list"
sudo apt update
sudo apt install code
sudo update-alternatives --set editor /usr/bin/code
extensions="
  donjayamanne.githistory
  dotjoshjohnson.xml
  eamodio.gitlens
  fnando.linter
  jakob101.relativepath
  joshx.workspace-terminals
  pkief.material-icon-theme
  ryu1kn.partial-diff
  ms-azuretools.vscode-docker
  ms-python.python
  ms-python.vscode-pylance
  ms-vscode.powershell


  uvbrain.angular2
  angular.ng-template
  cyrilletuzi.angular-schematics
  johnpapa.angular2
  formulahendry.auto-close-tag
  steoates.autoimport
  formulahendry.auto-rename-tag
  abusaidm.html-snippets
  thavarajan.ionic2
  danielehrhardt.ionic3-vs-ionview-snippets
  smobile.cordova-tools
  loiane.ionic-extension-pack
  ionic-preview.ionic-preview
  jgw9617.ionic2-vscode
  pkosta2006.rxjs-snippets
  robertohuertasm.vscode-icons
  eg2.tslint
  eg2.vscode-npm-script
  donjayamanne.githistory
	bierner.markdown-preview-github-styles
	editorconfig.editorconfig"

for e in ${extensions}; do
  code --install-extension "${e}";
done


######################
# Install PostgreSQL #
######################
# -Source: https://wiki.postgresql.org/wiki/Apt
sudo apt install postgresql postgresql-contrib
sudo usermod postgres -aG root,ssl-cert

KEY_NAME="microsoft"
curl -sS -o "${TEMP_DIR}/${KEY_NAME}.asc" "https://packages.microsoft.com/keys/microsoft.asc"
gpg --dearmor -o "${TEMP_DIR}/${KEY_NAME}.gpg" "${TEMP_DIR}/${KEY_NAME}.asc"
sudo install -o root -g root -m 644 "${TEMP_DIR}/${KEY_NAME}.gpg" "${KEYS_DIR}"
echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee "${SOURCES_DIR}/vscode.list"

curl -sS -o "${TEMP_DIR}/ACCC4CF8.asc" "https://www.postgresql.org/media/keys/ACCC4CF8.asc"
sudo apt-key add /tmp/ACCC4CF8.asc
sudo sh -c "echo ""deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main"" > /etc/apt/sources.list.d/pgdg.list"
sudo apt update
sudo apt install pgadmin4

# Configure PostgreSQL Server
configdirs=$(pg_lsclusters -j | jq -r '.[].configdir')
for c in ${configdirs}; do
  sudo cp "${c}/postgresql.conf" "${c}/postgresql.conf.old"
  sudo sed -i 's/#listen_addresses/listen_addresses/g' "${c}/postgresql.conf"
  sudo sed -i 's/ssl_cert_file = '\''\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem'\''/ssl_cert_file = '\''\/etc\/ssl\/private\/hackpro.cer'\''/g' "${c}/postgresql.conf"
  sudo sed -i 's/ssl_key_file = '\''\/etc\/ssl\/private\/ssl-cert-snakeoil.key'\''/ssl_key_file = '\''\/etc\/ssl\/private\/hackpro.key'\''/g' "${c}/postgresql.conf"
done

# Restart PostgreSQL services
versions=$(pg_lsclusters -j | jq -r '.[].version')
for v in ${versions}; do
  clusters=$(pg_lsclusters -j "${v}"| jq -r '.[].cluster')
  for c in ${clusters}; do
    sudo pg_ctlcluster "${v}" "${c}" restart
  done
done
# Check PostgreSQL services
sudo systemctl status postgres*


####################################
# Install and Configure FTP Server #
####################################
# -Source: https://www.hostinger.co/tutoriales/como-configurar-servidor-ftp-en-ubuntu-vps/
sudo apt install vsftpd
# Add Allowed ports into Ubuntu Firewall
sudo ufw allow from any to any port 20,21,22,990,10000:10010 proto tcp
sudo iptables -I INPUT -p tcp --destination-port 20:22 -j ACCEPT
sudo iptables -I INPUT -p tcp --destination-port 990 -j ACCEPT
sudo iptables -I INPUT -p tcp --destination-port 10000:10010 -j ACCEPT
sudo iptables-save -c
sudo iptables -v -n -x -L
# Edit FTP Service configuration
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.backup
sudo sed -i 's/#anonymous_enable/anonymous_enable/g' /etc/vsftpd.conf
sudo sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd.conf
sudo sed -i 's/#local_enable/local_enable/g' /etc/vsftpd.conf
sudo sed -i 's/local_enable=NO/local_enable=YES/g' /etc/vsftpd.conf
sudo sed -i 's/#write_enable/write_enable/g' /etc/vsftpd.conf
sudo sed -i 's/write_enable=NO/write_enable=YES/g' /etc/vsftpd.conf
sudo sed -i '0,/#chroot_local_user/ s/#chroot_local_user/chroot_local_user/g' /etc/vsftpd.conf
sudo sed -i '0,/chroot_local_user=NO/ s/chroot_local_user=NO/chroot_local_user=YES/g' /etc/vsftpd.conf
sudo sed -i 's/#rsa_cert_file/rsa_cert_file/g' /etc/vsftpd.conf
sudo sed -i 's/rsa_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/rsa_cert_file=\/etc\/ssl\/private\/hackpro.cer/g' /etc/vsftpd.conf
sudo sed -i 's/#rsa_private_key_file/rsa_private_key_file/g' /etc/vsftpd.conf
sudo sed -i 's/rsa_private_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/rsa_private_key_file=\/etc\/ssl\/private\/hackpro.key/g' /etc/vsftpd.conf
sudo sed -i 's/#ssl_enable/ssl_enable/g' /etc/vsftpd.conf
sudo sed -i 's/ssl_enable=NO/ssl_enable=YES/g' /etc/vsftpd.conf
sudo sed -i 's/#ftpd_banner=/ftpd_banner=/g' /etc/vsftpd.conf
sudo sed -i 's/ftpd_banner=Welcome to blah FTP service./ftpd_banner=Welcome to HACKPRO FTP service./g' /etc/vsftpd.conf
sudo sed -i '$ a \\n#\n# Add Security options to configuration' /etc/vsftpd.conf
sudo sed -i '$ a user_sub_token=\$USER' /etc/vsftpd.conf
sudo sed -i '$ a local_root=/home/\$USER' /etc/vsftpd.conf
sudo sed -i '$ a pasv_enable=YES' /etc/vsftpd.conf
sudo sed -i '$ a pasv_min_port=10000' /etc/vsftpd.conf
sudo sed -i '$ a pasv_max_port=10010' /etc/vsftpd.conf
sudo sed -i '$ a userlist_enable=YES' /etc/vsftpd.conf
sudo sed -i '$ a userlist_file=/etc/vsftpd.userlist' /etc/vsftpd.conf
sudo sed -i '$ a userlist_deny=NO' /etc/vsftpd.conf
sudo sed -i '$ a allow_writeable_chroot=YES' /etc/vsftpd.conf
sudo sed -i '$ a allow_anon_ssl=NO' /etc/vsftpd.conf
sudo sed -i '$ a force_local_data_ssl=YES' /etc/vsftpd.conf
sudo sed -i '$ a force_local_logins_ssl=YES' /etc/vsftpd.conf
sudo sed -i '$ a ssl_tlsv1=YES' /etc/vsftpd.conf
sudo sed -i '$ a ssl_sslv2=NO' /etc/vsftpd.conf
sudo sed -i '$ a ssl_sslv3=NO' /etc/vsftpd.conf
sudo sed -i '$ a require_ssl_reuse=NO' /etc/vsftpd.conf
sudo sed -i '$ a ssl_ciphers=HIGH' /etc/vsftpd.conf
# Add users to FTP Service configuration
echo "${USER}" | sudo tee -a /etc/vsftpd.userlist
# Restart Service for update changes
sudo systemctl restart vsftpd
sudo systemctl status vsftpd


###############
# Install VLC #
###############
sudo snap install vlc


################
# Install 7Zip #
################
sudo apt install p7zip-full p7zip-rar


#################
# Install Slack #
#################
curl -o /tmp/slack-desktop-3.3.3-amd64.deb https://downloads.slack-edge.com/linux_releases/slack-desktop-3.3.3-amd64.deb
sudo gdebi /tmp/slack-desktop-3.3.3-amd64.deb


#####################
# Install RetroArch #
#####################
sudo add-apt-repository ppa:libretro/stable
sudo apt update
sudo apt install retroarch


###################
# Install AnyDesk #
###################
KEY_NAME="anydesk.gpg"
curl -sS -o "${TEMP_DIR}/temp_${KEY_NAME}" "https://keys.anydesk.com/repos/DEB-GPG-KEY"
gpg --dearmor -o "${TEMP_DIR}/${KEY_NAME}" "${TEMP_DIR}/temp_${KEY_NAME}"
sudo install -o root -g root -m 644 "${TEMP_DIR}/${KEY_NAME}" "/etc/apt/trusted.gpg.d/"
echo "deb http://deb.anydesk.com/ all main" | sudo tee "/etc/apt/sources.list.d/anydesk-stable.list"
sudo apt update
sudo apt install anydesk
rm -f "${TEMP_DIR}/anydesk*.gpg"


#########################
# Install Brave Browser #
#########################
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update
sudo apt install brave-browser


##################
# Install Stacer #
##################
sudo add-apt-repository ppa:oguzhaninan/stacer
sudo apt update
sudo apt install stacer


####################
# Install OpenShot #
####################
sudo add-apt-repository ppa:openshot.developers/ppa
sudo apt update
sudo apt install openshot-qt python3-openshot


#######################
# Install qBittorrent #
#######################
sudo add-apt-repository ppa:qbittorrent-team/qbittorrent-stable
sudo apt update
sudo apt install qbittorrent


######################
# Change Default Mic #
######################
# Edit .profile file
MIC_NAME='Redragon'
MIC_INFO=$(pactl list short sources | awk '/alsa_input./ { print $2 }' | grep "${MIC_NAME}")
if [[ -n "${MIC_INFO}" ]]; then
  pactl set-default-source "${MIC_INFO}"
fi


##################
# Install lsyncd #
##################
# Live Syncing Deamon
# -Source: https://github.com/lsyncd/lsyncd/blob/master/INSTALL
# -Sample: https://www.howtoforge.com/how-to-synchronize-directories-using-lsyncd-on-ubuntu/
sudo apt install lua5.3 liblua5.3-0 liblua5.3-dev
sudo apt install lsyncd

sudo mkdir /etc/lsyncd
sudo mkdir /var/log/lsyncd

sudo sh -c "cat <<EOT > /etc/lsyncd/lsyncd.conf.lua
settings {
   logfile = '/var/log/lsyncd/lsyncd.log',
   statusFile = '/var/log/lsyncd/lsyncd.status',
   statusInterval = 20,
   nodaemon   = false
}

sync {
   default.rsync,
   source = '/home/hackpro/HACKPRO/ONEDRIVE/DB',
   target = '/home/hackpro/HACKPRO/GDRIVE/DB'
}
EOT"

sudo systemctl start lsyncd
sudo systemctl enable lsyncd
sudo systemctl status lsyncd

###################
# Install Calibre #
###################
# Book Reader
# -Source: https://calibre-ebook.com/es_MX/download_linux
sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin


#####################
# Install Filezilla #
#####################
# -Source: https://filezillapro.com/docs/v3/basic-usage-instructions/install-filezilla-pro-on-debian-linux
FILENAME="FileZilla_3.60.1_x86_64-linux-gnu.tar.bz2"
curl -o "/tmp/${FILENAME}" "https://dl4.cdn.filezilla-project.org/client/${FILENAME}?h=AZF3xQTeW6zgyoHsJpgovw&x=1657816654"
sudo tar xvf "/tmp/${FILENAME}" -C /opt
sudo sed -i 's/#anonymous_enable/anonymous_enable/g' /opt/FileZilla3/share/applications/filezilla.desktop
sudo cp /opt/FileZilla3/share/applications/filezilla.desktop /usr/local/share/applications/


#########################
# Install AWS Workspace #
#########################
# -Source: https://clients.amazonworkspaces.com/linux-install
wget -q -O - https://workspaces-client-linux-public-key.s3-us-west-2.amazonaws.com/ADB332E7.asc | sudo apt-key add -
echo "deb [arch=amd64] https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu bionic main" | sudo tee /etc/apt/sources.list.d/amazon-workspaces-clients.list
sudo apt update
sudo apt install workspacesclient

# Ubuntu Version 22.04
wget http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
sudo apt install ./libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb


######################
# Install KeePass XC #
######################
sudo apt install keepassxc


#################
# Install Teams #
#################
curl "https://packages.microsoft.com/keys/microsoft.asc" | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/ms-teams stable main" > /etc/apt/sources.list.d/teams.list'
sudo apt update
sudo apt install teams


###############################
# Install Powershell y DotNet #
###############################
# Update the list of packages
sudo apt update
# Download the Microsoft repository GPG keys
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
# Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb
# Update the list of packages after we added packages.microsoft.com
sudo apt update
# Install PowerShell
sudo apt install -y powershell
# Install DotNet
sudo apt install -y dotnet-sdk-6.0


###################
# Install Remmina #
###################
sudo apt-add-repository ppa:remmina-ppa-team/remmina-next
sudo apt update
sudo apt install remmina remmina-plugin-rdp remmina-plugin-secret

#####################
# Install Flameshot #
#####################
sudo apt install flameshot


#######################
# Install MonoDevelop #
#######################
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
echo "deb https://download.mono-project.com/repo/ubuntu vs-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-vs.list
sudo apt update
sudo apt install monodevelop

#################
# Install CopyQ #
#################
sudo apt install software-properties-common python-software-properties
sudo add-apt-repository ppa:hluk/copyq
sudo apt update
sudo apt install copyq
