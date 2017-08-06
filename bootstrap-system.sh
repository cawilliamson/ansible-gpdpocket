#!/bin/bash

# set bash options
set -e -x

# set paths
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# enable wifi (when not in chroot)
if [ "$(stat -c %d:%i /)" == "$(stat -c %d:%i /proc/1/root/.)" ]; then
  echo "enabling wifi..."
  
  mkdir -p /lib/firmware/brcm
  cp -f roles/wifi/files/brcmfmac4356-pcie.* /lib/firmware/brcm/
  
  modprobe -r brcmfmac && modprobe brcmfmac

  echo "If you do not see the WiFi option in your desktop environment - you may need to use a USB ethernet adapter. This is due to an incompatibility on the Linux kernel your distribution is using. This will be resolved once the bootstrap script has run successfully for the first time but that will require an Internet connection to be present."
  echo
  echo "Please connect to a WiFi network (using internal chipset) or wired network (via USB adapter), then press return to continue:"
  read
fi

# wait for internet connection
while ! ping -c1 8.8.8.8 &>/dev/null; do
  sleep 1
done

# install essential packages
if [ -f /usr/bin/pacman ]; then
  pacman-key --init
  pacman-key --populate archlinux
  pacman -Sy --noconfirm ansible git
elif [ -f /usr/bin/apt-get ]; then
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    sleep 1
  done
  DEBIAN_FRONTEND=noninteractive
  sed -i 's,main restricted,main restricted universe multiverse,g' /etc/apt/sources.list
  mkdir -p /etc/apt/sources.list.d
  apt-get update
  apt-get -y install dirmngr
  echo 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main' > /etc/apt/sources.list.d/ansible.list
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 93C4A3FD7BB9C367
  apt-get update
  apt-get -y install ansible git
elif [ -f /usr/sbin/emerge ]; then
  emerge --sync
  USE="blksha1 curl webdav" emerge app-admin/ansible dev-vcs/git
fi

# update ansible code
if [ -d /usr/src/ansible-gpdpocket/.git ]; then
  cd /usr/src/ansible-gpdpocket
  git pull || (cd && rm -rf /usr/src/ansible-gpdpocket && git clone https://github.com/cawilliamson/ansible-gpdpocket.git /usr/src/ansible-gpdpocket)
else
  git clone https://github.com/cawilliamson/ansible-gpdpocket.git /usr/src/ansible-gpdpocket
fi
cd /usr/src/ansible-gpdpocket
git fetch --all
git reset --hard origin/master

# run ansible scripts
ANSIBLE_NOCOWS=1 ansible-playbook site.yml -e "bootstrap=true"