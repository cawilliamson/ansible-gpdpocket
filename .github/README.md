## Goal

The goal of this project is to automatically apply and update all of the various changes needed to make Linux work properly on the GPD Pocket.

## Install / Update

###### Supported Linux Distributions
- Arch-based distributions (ArchLinux, Manjaro, etc.)
- Debian-based distributions (Debian, Kali, Mint, Ubuntu, etc.)
- Fedora-based distributions (experimental – could really use some feedback!)
- Gentoo-based distributions (Funtoo, Gentoo, etc.)

###### Bootstrap ISO

1.  Setup a Linux environment (Virtualbox + Ubuntu LiveCD is a quick option.) An existing Linux install using any of the above listed distros will work also. Please **make sure** /var has at least 20GB available and /root has at least 10GB available.

2.  Download your ISO to this Linux machine – you can do this using: `wget http://url.here/file.iso`. Netinstall images won't work, you need a full install ISO.

3.  Run the following to build the ISO (replacing ISO_FILENAME with the actual name of the file.)

        git clone https://github.com/cawilliamson/ansible-gpdpocket.git
        cd ansible-gpdpocket
        bash bootstrap-iso.sh ISO_FILENAME

4.  Write the file to USB by running the following (replacing USB_DEVICE with the actual device path for your USB drive):

        fdisk -l /dev/sd* # find the disk ID of your USB drive and use in command below.
        dd bs=1m if=~/bootstrap.iso of=USB_DEVICE

5.  Boot your GPD Pocket using the USB drive and you should have a completely working installer for your distribution of choice.

###### Bootstrap system

In order to install my Ansible playbooks on an existing install (e.g. one which you've set up with the `nomodeset fbcon=rotate:1` kernel parameters) please complete the following steps:

1.  Start by downloading the latest ZIP of my ansible playbooks from:  
    https://github.com/cawilliamson/ansible-gpdpocket/archive/master.zip

2.  Copy this file to a USB drive and insert that drive in to the GPD Pocket

3.  Mount the USB drive somewhere (`mount /dev/sda1 /mnt` for example)

4.  Using `cd` navigate to that new directory (for example: `cd /mnt`)

5.  Run the following command:

        sudo bash bootstrap-system.sh

###### Update system

1. Run `sudo gpd-update` – be aware that this process can take multiple hours if there is a kernel update available since it will be compiled on the GPD Pocket.

2. Reboot if any changes were made to ensure they get applied properly.

## Status

###### Known Issues

- Distorted audio (kernel bug – https://bugzilla.kernel.org/show_bug.cgi?id=196351 )
- Suspend Issues (Enhancement: [#25](https://github.com/cawilliamson/ansible-gpdpocket/issues/25))
- USB-C Data Connectivity (hansdegoede is working on this currently)
- (DEBIAN) When installing you will be informed modules cannot be loaded. If you select "Yes" to continue anyway this will allow you to continue. (Enhancement: [#22](https://github.com/cawilliamson/ansible-gpdpocket/issues/22))
- (FEDORA) When installing Fedora you will need to select the option **without** the media checking functionality. Performing a media check will result in a checksum failure. (Enhancement: [#21](https://github.com/cawilliamson/ansible-gpdpocket/issues/21))
- (FEDORA) Currently the Fedora installer is broken - please do not attempt to use this until I have removed this note. (Bug: [#66](https://github.com/cawilliamson/ansible-gpdpocket/issues/66))

###### Working

- Accelerated Video
- Audio
- Battery manager
- Bluetooth
- Display brightness
- Display rotation
- Suspend (sleep/wake)
- Thermal control
- Touchscreen
- Wi-Fi

## Contributors

- efluffy at https://github.com/efluffy/gpdfand – great work on actually getting the fans in this thing to work.
- hansdegoede at http://hansdegoede.livejournal.com/17445.html – absolutely EVERYTHING related to the kernel was this guy.
- linuxiumcomau at http://linuxiumcomau.blogspot.com/ – inspired my work on bootstrapping install isos.
- stockmind at https://github.com/stockmind/gpd-pocket-ubuntu-respin – various code contributions and ideas.

## Donate
If this project helped you – feel free to buy me a coffee (I could sure use one!)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=JGZUV7JA5A44E)
