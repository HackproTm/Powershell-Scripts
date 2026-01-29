#!/bin/bash

# Install Prerequisites
sudo apt-get -y install wget gdebi-core snapd snapd-xdg-open apt-transport-https ca-certificates software-properties-common
sudo apt-get -y install qemu-kvm libvirt-bin ubuntu-vm-builder virtinst bridge-utils lib32z1 lib32ncurses5 cpu-checker


# Install Notepad++
# Source:
#         https://websiteforstudents.com/install-notepad-on-ubuntu-16-04-17-10-18-04-via-snap/
sudo snap install notepad-plus-plus

sudo snap connect notepad-plus-plus:process-control

sudo snap connect notepad-plus-plus:removable-media

sudo snap connect notepad-plus-plus:hardware-observe

sudo snap connect notepad-plus-plus:cups-control


# Install Slack
# Source:
#         https://linuxconfig.org/how-to-install-slack-on-ubuntu-18-04-bionic-beaver-linux
file=slack-desktop-3.2.1-amd64.deb

wget -qO /tmp/$file https://downloads.slack-edge.com/linux_releases/$file

sudo gdebi /tmp/$file


# Install Git
# Source:
#         https://git-scm.com/download/linux
#         https://www.liquidweb.com/kb/install-git-ubuntu-16-04-lts/
#         https://blog.sleeplessbeastie.eu/2012/08/12/git-how-to-avoid-typing-your-password-repeatedly/
sudo add-apt-repository ppa:git-core/ppa

sudo apt-get update

sudo apt-get -y install git

git config --global user.name "Edwin Mantilla"

git config --global user.email "Edwin.Mantilla@e-hps.com"

git config --global credential.helper 'cache --timeout=28800'



# Install Java
# Source:
#         https://www.digitalocean.com/community/tutorials/como-instalar-java-con-apt-get-en-ubuntu-16-04-es
sudo add-apt-repository ppa:webupd8team/java

sudo apt-get update

sudo apt-get -y install oracle-java8-installer

sudo update-alternatives --config java

sudo update-alternatives --config javac

sudo update-alternatives --config javadoc

sudo echo 'export JAVA_HOME="/usr/lib/jvm/java-8-oracle"' >> ~/.bashrc

sudo echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.bashrc

source ~/.profile


# Install Python
# Source:
#         https://github.com/pyenv/pyenv-installer
#         https://github.com/pyenv/pyenv
wget -qO /tmp/pyenv-installer.sh https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer

sudo bash /tmp/pyenv-installer.sh

sudo echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc

sudo echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc

sudo echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.bashrc

source ~/.profile

sudo pyenv update

sudo pyenv install 3.5.4


# Install NodeJS
# Source:
#         https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-18-04#installing-using-nvm
wget -qO /tmp/install_nvm.sh https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh

sudo bash /tmp/install_nvm.sh

source ~/.profile

nvm install 8.9.4

nvm alias default 8.9.4

nvm use default


# Install Docker
# Source:
#         https://docs.docker.com/install/linux/docker-ce/ubuntu/
#         https://docs.docker.com/install/linux/linux-postinstall/
sudo apt-get -y remove docker docker-engine docker.io

sudo apt-get update

wget -qO /tmp/gpg https://download.docker.com/linux/ubuntu/gpg

sudo apt-key add /tmp/gpg

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable edge"

sudo apt-get update

sudo apt-get -y install docker-ce

sudo docker run hello-world

sudo groupadd docker

sudo usermod -aG docker $USER

sudo mkdir /home/"$USER"/.docker

sudo chown "$USER":"$USER" /home/"$USER"/.docker -R

sudo chmod g+rwx "/home/$USER/.docker" -R


# Install Docker Machine
# Source:
#         https://docs.docker.com/machine/install-machine/
base=https://github.com/docker/machine/releases/download/v0.14.0

wget -qO /tmp/docker-machine $base/docker-machine-$(uname -s)-$(uname -m)

sudo install /tmp/docker-machine /usr/local/bin/docker-machine

sudo chmod +x /usr/local/bin/docker-machine

base=https://raw.githubusercontent.com/docker/machine/v0.14.0

for i in docker-machine-prompt.bash docker-machine-wrapper.bash docker-machine.bash
do
  sudo wget "$base/contrib/completion/bash/${i}" -P /etc/bash_completion.d
done


# Install Docker Compose
# Source:
#         https://docs.docker.com/compose/install/
#         https://docs.docker.com/compose/completion/
base=https://github.com/docker/compose/releases/download/1.21.2

sudo wget -qO /usr/local/bin/docker-compose $base/docker-compose-$(uname -s)-$(uname -m)

sudo chmod +x /usr/local/bin/docker-compose

base=https://raw.githubusercontent.com/docker/compose/1.21.2/contrib/completion/bash

sudo wget -qO /etc/bash_completion.d/docker-compose $base/docker-compose 

# docker-compose down -v
# docker rmi $(docker images -q) -f


# Configure Android Studio
# Source:
#         https://developer.android.com/studio/run/emulator-acceleration?utm_source=android-studio#vm-linux
#         https://help.ubuntu.com/community/KVM/Installation
sudo egrep -c '(vmx|svm)' /proc/cpuinfo

sudo kvm-ok

sudo groupadd libvirtd

sudo groupadd kvm

sudo adduser `id -un` libvirtd

sudo adduser `id -un` kvm

sudo chown "$USER":"$USER" /dev/kvm -R

sudo chmod g+rwx /dev/kvm


# Install Appium
# Source:
#         https://github.com/appium/appium/blob/master/docs/en/about-appium/getting-started.md
#         https://github.com/appium/appium-desktop
npm install -g appium

npm install -g appium-doctor

npm install appium --chromedriver_version="3.40"


# Install MongoDB
# Source:
#         https://docs.mongodb.com/master/tutorial/install-mongodb-on-ubuntu/
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list

sudo apt-get update

sudo apt-get -y install mongodb-org

file=robo3t-1.2.1-linux-x86_64-3e50a65

sudo wget -qO /tmp/$file.tar.gz https://download.robomongo.org/1.2.1/linux/$file.tar.gz

sudo tar -xvzf /tmp/$file.tar.gz -C /tmp

sudo mkdir -p /usr/local/bin/robomongo

sudo mv -f /tmp/$file/* /usr/local/bin/robomongo

sudo chmod +x /usr/local/bin/robomongo/bin/robo3t

sudo echo 'alias robomongo="/usr/local/bin/robomongo/bin/robo3t"' >> ~/.bash_aliases

source ~/.profile

