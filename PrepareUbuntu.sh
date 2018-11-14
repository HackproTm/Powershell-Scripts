##########################
# Install Pre-Requisites #
##########################
sudo apt-get install curl apt-transport-https gvfs-bin


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
curl -o /tmp/install.sh https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash /tmp/install.sh


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
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
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

