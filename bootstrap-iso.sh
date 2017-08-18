#!/bin/bash

# set bash options
set -e -x

# install dependencies
if [ -f /usr/bin/pacman ]; then
  pacman -Sy --needed --noconfirm ansible git
elif [ -f /usr/bin/apt-get ]; then
  DEBIAN_FRONTEND=noninteractive
  mkdir -p /etc/apt/sources.list.d
  echo 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main' > /etc/apt/sources.list.d/ansible.list
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
  apt-get update
  apt-get -y install ansible git
elif [ -f /usr/bin/yum ]; then
  yum install -y ansible git
elif [ -f /usr/sbin/emerge ]; then
  emerge --sync
  USE="blksha1 curl" emerge app-admin/ansible dev-vcs/git
fi

# update ansible code
rm -rf /usr/src/ansible-gpdpocket
git clone --depth 1 https://github.com/cawilliamson/ansible-gpdpocket.git /usr/src/ansible-gpdpocket

# run ansible scripts
ANSIBLE_NOCOWS=1 ansible-playbook /usr/src/ansible-gpdpocket/iso.yml -e "iso='$(readlink -f \"${1}\")'"

# write information
echo "Your ISO has been successfully created and is at /root/bootstrap.iso"

# update ansible code
rm -rf /usr/src/ansible-gpdpocket
