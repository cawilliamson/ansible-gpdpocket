#!/bin/bash

# set bash options
set -e -x

# set paths
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

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
  if [ -f /etc/apt/sources.list ]; then
    sed -i 's,main restricted,main restricted universe multiverse,g' /etc/apt/sources.list
  elif [ -f /etc/apt/sources.list.d/base.list ]; then
    sed -i 's,main,main contrib non-free,g' /etc/apt/sources.list.d/base.list
  fi
  apt-get update
  apt-get -y install dirmngr
  mkdir -p /etc/apt/sources.list.d
  echo 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main' > /etc/apt/sources.list.d/ansible.list
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
  apt-get update
  apt-get -y install ansible git
elif [ -f /usr/bin/yum ]; then
  yum -y install ansible git
elif [ -f /usr/sbin/emerge ]; then
  emerge --sync
  USE="blksha1 curl webdav" emerge app-admin/ansible dev-vcs/git
elif [ -f /usr/bin/eopkg ]; then
  eopkg install ansible git
fi

# update ansible code
if grep -wq -- --nogit <<< "$@"; then
  echo "skip pulling source from git"
else
  rm -rf /usr/src/ansible-gpdpocket
  git clone --depth 1 https://github.com/cawilliamson/ansible-gpdpocket.git /usr/src/ansible-gpdpocket
fi
cd /usr/src/ansible-gpdpocket

# run ansible scripts
ANSIBLE_NOCOWS=1 ansible-playbook system.yml -e "bootstrap=true" -v
