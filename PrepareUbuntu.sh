#!/bin/bash
# Install Commons Apps for Ubuntu
#
# Autor: Edwin Mantilla Santamaría
# Usage: ./PrepareUbuntu.sh


##########################
# Install Pre-Requisites #
##########################
# Install required packages
sudo apt install curl ca-certificates apt-transport-https gvfs-bin sed net-tools gdebi-core jq libjson-perl
# Create SSL Certicate for hackpro.co
sudo openssl req -x509 -nodes -days 1825 -newkey rsa:4096 -keyout /etc/ssl/private/hackpro.key -out /etc/ssl/private/hackpro.cer -subj "/C=CO/ST=Bogota D.C/L=Bogota D.C/O=HACKPRO TEAM/OU=Developer Team/emailAddress=hackpro.ems@gmail.com/CN=*.hackpro.co"
sudo chmod -R g+r /etc/ssl/private/hackpro.key


#######################################
# Install GRUB Customizer and GParted #
#######################################
# -Source: https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer
sudo add-apt-repository ppa:danielrichter2007/grub-customizer
sudo apt update
sudo apt install grub-customizer
sudo apt install gparted


################
# Install Java #
################
# -Source: https://www.digitalocean.com/community/tutorials/how-to-install-java-with-apt-on-ubuntu-18-04
sudo apt install default-jdk
javapath=$(update-alternatives --query java | grep "Value: " | cut -c8-)
echo "JAVA_HOME=${javapath:0:-4}" | sudo tee -a /etc/environment
source /etc/environment


###############
# Install Git #
###############
# -Source: https://www.digitalocean.com/community/tutorials/how-to-install-git-on-ubuntu-18-04
sudo apt install git
git config --global user.name "Edwin Mantilla"
git config --global user.email "hackpro.ems@gmail.com"

sudo apt install git-cola


##############################
# Install Apache HTTP Server #
##############################
# -Source: https://www.digitalocean.com/community/tutorials/como-instalar-el-servidor-web-apache-en-ubuntu-18-04-es
sudo apt install apache2
sudo ufw allow 'Apache Full'
sudo mkdir -p /var/www/hackpro.co/html
sudo chown -R $USER:$USER /var/www/hackpro.co/html
sudo chmod -R 755 /var/www/hackpro.co


################################
# Install Node Version Manager #
################################
# -Source: https://github.com/creationix/nvm#install-script
curl -o /tmp/install.sh https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh
bash /tmp/install.sh
source ~/.profile


##################
# Install NodeJs #
##################
# -Source: https://github.com/creationix/nvm#usage
# -Prerequisites: Install Node Version Manager
nvm install 10.13.0
nvm alias default 10.13.0
nvm use default


################
# Install Yarn #
################
# -Source: https://yarnpkg.com/en/docs/install#debian-stable
# -Prerequisites: Install NodeJs
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install --no-install-recommends yarn


##############################
# Install Visual Studio Code #
##############################
curl -o /tmp/microsoft.asc https://packages.microsoft.com/keys/microsoft.asc
gpg --dearmor -o /tmp/microsoft.gpg /tmp/microsoft.asc
sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install code
sudo update-alternatives --set editor /usr/bin/code
extensions="uvbrain.angular2
    angular.ng-template
    cyrilletuzi.angular-schematics
    johnpapa.angular2
    formulahendry.auto-close-tag
    steoates.autoimport
    formulahendry.auto-rename-tag
    abusaidm.html-snippets
    thavarajan.ionic2
    danielehrhardt.ionic3-vs-ionview-snippets
    vsmobile.cordova-tools
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

for e in $extensions; do code --install-extension $e; done


######################
# Install PostgreSQL #
######################
# -Source: https://wiki.postgresql.org/wiki/Apt
sudo apt install postgresql postgresql-contrib
sudo usermod postgres -aG root,ssl-cert
curl -o /tmp/ACCC4CF8.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
sudo apt-key add /tmp/ACCC4CF8.asc
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt update
sudo apt install pgadmin4

# Configure PostgreSQL Server
configdirs=$(pg_lsclusters -j | jq -r '.[].configdir')
for c in $configdirs; do
    sudo cp $c/postgresql.conf $c/postgresql.conf.old
    sudo sed -i 's/#listen_addresses/listen_addresses/g' $c/postgresql.conf
    sudo sed -i 's/ssl_cert_file = '\''\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem'\''/ssl_cert_file = '\''\/etc\/ssl\/private\/hackpro.cer'\''/g' $c/postgresql.conf
    sudo sed -i 's/ssl_key_file = '\''\/etc\/ssl\/private\/ssl-cert-snakeoil.key'\''/ssl_key_file = '\''\/etc\/ssl\/private\/hackpro.key'\''/g' $c/postgresql.conf
done

# Restart PostgreSQL services
versions=$(pg_lsclusters -j | jq -r '.[].version')
for v in $versions; do
    clusters=$(pg_lsclusters -j $v| jq -r '.[].cluster')
    for c in $clusters; do
        sudo pg_ctlcluster $v $c restart
    done
done


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
sudo service iptables save
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
echo "$USER" | sudo tee -a /etc/vsftpd.userlist
# Restart Service for update changes
sudo systemctl restart vsftpd


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
