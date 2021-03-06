#! /bin/bash

# This script is used to manually prepare an Ubuntu 16.04 server for DetectionLab building
export DEBIAN_FRONTEND=noninteractive
export SERIALNUMBER="SECRET"
export LICENSEFILE="SECRET"

sed -i 's/archive.ubuntu.com/us.archive.ubuntu.com/g' /etc/apt/sources.list

if [[ "$VAGRANT_ONLY" -eq 1 ]] && [[ "$PACKER_ONLY" -eq 1 ]]; then
  echo "Somehow this build is configured as both packer-only and vagrant-only. This means something has gone horribly wrong."
  exit 1
fi

# Install VMWare Workstation 15
apt-get update
apt-get install -y linux-headers-"$(uname -r)" build-essential unzip git ufw apache2 python-pip ubuntu-desktop
pip install awscli --upgrade --user
export PATH=$PATH:/root/.local/bin

wget -O VMware-Workstation-Full-15.0.4-12990004.x86_64.bundle "https://download3.vmware.com/software/wkst/file/VMware-Workstation-Full-15.0.4-12990004.x86_64.bundle?HashKey=6f83753e4d9e94da7f920c32b5808033&params=%7B%22custnumber%22%3A%22KipkcHRoJWVlZA%3D%3D%22%2C%22sourcefilesize%22%3A%22472.70+MB%22%2C%22dlgcode%22%3A%22WKST-1504-LX%22%2C%22languagecode%22%3A%22en%22%2C%22source%22%3A%22DOWNLOADS%22%2C%22downloadtype%22%3A%22manual%22%2C%22eula%22%3A%22Y%22%2C%22downloaduuid%22%3A%225caee685-d5ad-4f6b-94db-2ddc4f7f3a97%22%2C%22purchased%22%3A%22N%22%2C%22dlgtype%22%3A%22Product+Binaries%22%2C%22productversion%22%3A%2215.0.4%22%2C%22productfamily%22%3A%22VMware+Workstation+Pro%22%7D&AuthKey=1556427011_a994b5252f29429710c077c8dcab1c19"
chmod +x VMware-Workstation-Full-15.0.4-12990004.x86_64.bundle
sudo sh VMware-Workstation-Full-15.0.4-12990004.x86_64.bundle --console --required --eulas-agreed --set-setting vmware-workstation serialNumber $SERIALNUMBER

# Set up firewall
ufw allow ssh
ufw default allow outgoing
ufw --force enable

git clone https://github.com/clong/DetectionLab.git /opt/DetectionLab

# Install Vagrant
mkdir /opt/vagrant
cd /opt/vagrant || exit 1
wget --progress=bar:force https://releases.hashicorp.com/vagrant/2.2.4/vagrant_2.2.4_x86_64.deb
dpkg -i vagrant_2.2.4_x86_64.deb
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-vmware-desktop
echo $LICENSEFILE | base64 -d > /tmp/license.lic
vagrant plugin license vagrant-vmware-desktop /tmp/license.lic
wget --progress=bar:force "https://releases.hashicorp.com/vagrant-vmware-utility/1.0.7/vagrant-vmware-utility_1.0.7_x86_64.deb"
dpkg -i vagrant-vmware-utility_1.0.7_x86_64.deb

# Make the Vagrant instances headless
cd /opt/DetectionLab/Vagrant || exit 1
sed -i 's/v.gui = true/v.gui = false/g' Vagrantfile

# Install Packer
mkdir /opt/packer
cd /opt/packer || exit 1
wget --progress=bar:force https://releases.hashicorp.com/packer/1.3.2/packer_1.3.2_linux_amd64.zip
unzip packer_1.3.2_linux_amd64.zip
cp packer /usr/local/bin/packer

# Make the Packer images headless
cd /opt/DetectionLab/Packer || exit 1
for file in *.json; do
  sed -i 's/"headless": false,/"headless": true,/g' "$file";
done

# Ensure the script is executable
chmod +x /opt/DetectionLab/build.sh
cd /opt/DetectionLab || exit 1
