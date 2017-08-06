#!/bin/bash

case $1 in
  pre)
    # stop fan control script
    systemctl stop gpd-fan.service
    ;;
  post)
    # start fan control script
    systemctl start gpd-fan.service
    ;;
esac
