#!/bin/bash

# set bash options
set -e -x

# check if iso is supported
shopt -s nocasematch
if ! [[ "${1}" =~ (antergos|arch|centos|debian|fedora|kali|manjaro|mint|redhat|solus|gentoo|ubuntu) ]]; then
  echo "The ISO you provided is NOT supported. This could be due to it being incorrectly named - it must contain the name of the distribution which it contains."
  exit 1
fi

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
elif [ -f /usr/bin/eopkg ]; then
  eopkg install ansible git
fi

# update ansible code
if [ -d .git -a "x" == "x$GPD_BOOTSTRAP_NO_GIT_PULL" ]; then
  git reset --hard
  git pull
fi

# run ansible scripts
ANSIBLE_NOCOWS=1 ansible-playbook iso.yml -e "iso='${1}'" -v

# write information
echo "Your ISO has been successfully created and is at /root/bootstrap.iso"
