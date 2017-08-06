#!/bin/bash

# set bash options
set -e -x

# set variables
TMPDIR=/var/tmp/bootstrap-iso

# install dependencies
if [ -f /usr/bin/pacman ]; then
  pacman -Sy --noconfirm squashfs-tools xorriso
elif [ -f /usr/bin/apt-get ]; then
  apt-get update
  apt-get -y install squashfs-tools xorriso
elif [ -f /usr/sbin/emerge ]; then
  emerge --sync
  USE="lz4 lzma lzo xz" emerge dev-libs/libisoburn sys-fs/squashfs-tools
fi

# extract iso
mkdir -p ${TMPDIR}
xorriso -osirrox on -indev ${1} -extract / ${TMPDIR}

# find paths
EFI_PATH=$(find ${TMPDIR} -type f -iname 'efi*.img' -print -quit)
SQUASHFS_PATH=$(find ${TMPDIR} -type f -regex '.*\(sfs\|squashfs\)$' -print -quit)
KERNEL_PATH=$(find ${TMPDIR} -type f -iname '*vmlinuz*' -print -quit)
INITRD_PATH=$(find $(dirname ${KERNEL_PATH}) -type f -regex '.*\(img\|lz\|gz\)$' -print -quit)

# extract squashfs
unsquashfs -d ${TMPDIR}/squashfs/ -f ${SQUASHFS_PATH}
rm -f ${SQUASHFS_PATH}

# prepare squashfs system files files for chroot
rm -f ${TMPDIR}/squashfs/etc/resolv.conf
cp -L /etc/resolv.conf ${TMPDIR}/squashfs/etc/resolv.conf
mount --bind ${TMPDIR}/squashfs ${TMPDIR}/squashfs
mount --bind /dev ${TMPDIR}/squashfs/dev
mount -t proc none ${TMPDIR}/squashfs/proc

# run ansible playbook against system files
cp -L bootstrap-system.sh ${TMPDIR}/squashfs/tmp/bootstrap-system.sh
chroot ${TMPDIR}/squashfs/ /bin/bash -c "/bin/bash /tmp/bootstrap-system.sh"

# fix squashfs system files after chroot
rm -rf \
    ${TMPDIR}/squashfs/etc/resolv.conf \
    ${TMPDIR}/squashfs/usr/src/ansible-gpdpocket \
    ${TMPDIR}/squashfs/tmp/bootstrap-system.sh

# copy kernel in to place
cp -L ${TMPDIR}/squashfs/boot/initrd.img-*bootstrap ${INITRD_PATH}
cp -L ${TMPDIR}/squashfs/boot/vmlinuz-*-bootstrap ${KERNEL_PATH}

# re-compress squashfs
umount -lf ${TMPDIR}/squashfs
mksquashfs ${TMPDIR}/squashfs ${SQUASHFS_PATH}
rm -rf ${TMPDIR}/squashfs

# add distro-specific checksums
if [ -f ${TMPDIR}/arch/x86_64/airootfs.md5 ]; then
  md5sum ${SQUASHFS_PATH} > ${TMPDIR}/arch/x86_64/airootfs.md5
elif [ -f ${TMPDIR}/md5sum.txt ]; then
  find ${TMPDIR} -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > ${TMPDIR}/md5sum.txt
fi

# re-assemble iso
dd if=${1} bs=512 count=1 of=${TMPDIR}/isolinux/isohdpfx.bin
ISO_LABEL=$(blkid -o value -s LABEL ${1})
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${ISO_LABEL}" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr ${TMPDIR}/isolinux/isohdpfx.bin \
    -eltorito-alt-boot \
    -e $(sed "s,${TMPDIR}/,," - <<< ${EFI_PATH}) \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output ${HOME}/bootstrap.iso \
    ${TMPDIR}

# clean up build environment
rm -rf ${TMPDIR}

# write information
echo "Your ISO has been successfully created and is at ${HOME}/bootstrap.iso"