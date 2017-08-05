#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-

from time import sleep
import argparse
import os
import subprocess

# parse command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('--screen', type=int, help='Should we rotate screen?', default=1)
parser.add_argument('--touchscreen', type=int, help='Should we rotate touchscreen?', default=1)
args = parser.parse_args()

# create local environment variable
local_env = os.environ.copy()

# wait for xorg to start
sleep(5)

# determine DISPLAY environment variable
if int(subprocess.check_output('pgrep Xorg -c', shell=True)) == 1:
    local_env['DISPLAY'] = ':0'
else:
    local_env['DISPLAY'] = ':1'

# determine XAUTHORITY environment variable
xorg_proc = subprocess.check_output('pgrep Xorg -a -n', shell=True)
local_env['XAUTHORITY'] = xorg_proc.split('-auth ')[1].split(' ')[0]

# check if screen rotation is enabled
if args.screen == 1:
    # rotate display
    subprocess.call('xrandr --output DSI1 --rotate right', shell=True, env=local_env)

# check if touchscreen rotation is enabled
if args.touchscreen == 1:
    # Wait for display to rotate
    sleep(5)
    
    # determine touchscreen ID
    touchscreen_id = subprocess.check_output('xinput list --id-only pointer:"Goodix Capacitive TouchScreen"', shell=True, env=local_env).rstrip()

    # rotate touchscreen
    subprocess.call('xinput set-prop %s "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1' % touchscreen_id, shell=True, env=local_env)