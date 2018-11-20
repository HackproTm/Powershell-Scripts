#!/bin/bash
# Install Commons Apps for Ubuntu
#
# Autor: Edwin Mantilla Santamaría
# Usage: ./PrepareUbuntu.sh


##########################
# Install Pre-Requisites #
##########################
# Install required packages
sudo apt-get install curl ca-certificates apt-transport-https gvfs-bin sed net-tools gdebi-core
# Create SSL Certicate for hackpro.co
sudo openssl req -x509 -nodes -days 1825 -newkey rsa:4096 -keyout /etc/ssl/private/hackpro.key -out /etc/ssl/private/hackpro.cer -subj "/C=CO/ST=Bogota D.C/L=Bogota D.C/O=HACKPRO TEAM/OU=Developer Team/emailAddress=hackpro.ems@gmail.com/CN=*.hackpro.co"


#######################################
# Install GRUB Customizer and GParted #
#######################################
# -Source: https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer
sudo add-apt-repository ppa:danielrichter2007/grub-customizer
sudo apt-get update
sudo apt-get install grub-customizer
sudo apt-get install gparted


###############
# Install Git #
###############
sudo apt-get install git
git config --global user.name "Edwin Mantilla"
git config --global user.email "hackpro.ems@gmail.com"

sudo apt-get install git-cola


################################
# Install Node Version Manager #
################################
# -Source: https://github.com/creationix/nvm#install-script
curl -o /tmp/install.sh https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh
bash /tmp/install.sh
source ~/.bashrc


##################
# Install NodeJs #
##################
# -Source: https://github.com/creationix/nvm#usage
nvm install 10.13.0
npm install -g angular-cli/latest
npm install -g typescript


##############################
# Install Visual Studio Code #
##############################
curl -o /tmp/microsoft.asc https://packages.microsoft.com/keys/microsoft.asc
gpg --dearmor -o /tmp/microsoft.gpg /tmp/microsoft.asc
sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt-get update
sudo apt-get install code
sudo update-alternatives --set editor /usr/bin/code
code --install-extension uvbrain.angular2
code --install-extension angular.ng-template
code --install-extension cyrilletuzi.angular-schematics
code --install-extension johnpapa.angular2
code --install-extension formulahendry.auto-close-tag
code --install-extension steoates.autoimport
code --install-extension formulahendry.auto-rename-tag
code --install-extension abusaidm.html-snippets
code --install-extension thavarajan.ionic2
code --install-extension danielehrhardt.ionic3-vs-ionview-snippets
code --install-extension vsmobile.cordova-tools
code --install-extension loiane.ionic-extension-pack
code --install-extension ionic-preview.ionic-preview
code --install-extension jgw9617.ionic2-vscode
code --install-extension pkosta2006.rxjs-snippets
code --install-extension robertohuertasm.vscode-icons
code --install-extension eg2.tslint
code --install-extension eg2.vscode-npm-script
code --install-extension donjayamanne.githistory


######################
# Install PostgreSQL #
######################
# -Source: https://wiki.postgresql.org/wiki/Apt
sudo apt-get install postgresql postgresql-contrib
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update
sudo apt-get install pgadmin4


####################################
# Install and Configure FTP Server #
####################################
# -Source: https://www.hostinger.co/tutoriales/como-configurar-servidor-ftp-en-ubuntu-vps/
sudo apt-get install vsftpd
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
sudo sed -i 's/rsa_cert_file=\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/rsa_cert_file=\/etc\/ssl\/private\/vsftpd.cer/g' /etc/vsftpd.conf
sudo sed -i 's/#rsa_private_key_file/rsa_private_key_file/g' /etc/vsftpd.conf
sudo sed -i 's/rsa_private_key_file=\/etc\/ssl\/private\/ssl-cert-snakeoil.key/rsa_private_key_file=\/etc\/ssl\/private\/vsftpd.key/g' /etc/vsftpd.conf
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
sudo apt-get install p7zip-full p7zip-rar


#################
# Install Slack #
#################
curl -o /tmp/slack-desktop-3.3.3-amd64.deb https://downloads.slack-edge.com/linux_releases/slack-desktop-3.3.3-amd64.deb
sudo gdebi /tmp/slack-desktop-3.3.3-amd64.deb


###############################
# Prepare GitHub Repositories #
###############################
cd $HOME
mkdir -p GitHub/HackproTm
cd GitHub/HackproTm
git clone https://github.com/HackproTm/IonicExercises
git clone https://github.com/kaikcreator/AngularComponents101
rm -rf AngularComponents101/.git
mv AngularComponents101/ IonicExercises/
cd IonicExercises/AngularComponents101/
npm install
