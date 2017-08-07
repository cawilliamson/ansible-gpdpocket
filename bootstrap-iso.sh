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
BOOT_CONFIGS=$(find ${TMPDIR} -type f -regex '.*\(grub/.+.cfg\|isolinux/.+.cfg\)')
EFI_PATH=$(find ${TMPDIR} -type f -iname 'efi*.img' -print -quit)
SQUASHFS_PATH=$(find ${TMPDIR} -type f -regex '.*\(squashfs\.img\|\.sfs\|\.squashfs\)$' -print -quit)
KERNEL_PATHS=$(find ${TMPDIR} -type f -iname '*vmlinuz*')

# patch kernel boot options
while read -r BOOT_CONFIG; do
  sed -i 's, splash,,g' ${BOOT_CONFIG}
  sed -i 's, quiet, boot=live,g' ${BOOT_CONFIG}
done <<< "${BOOT_CONFIGS}"

# extract squashfs
unsquashfs -d ${TMPDIR}/squashfs/ -f ${SQUASHFS_PATH}
rm -f ${SQUASHFS_PATH}

# check for double squashed images (WTF?!)
if [ -f ${TMPDIR}/squashfs/LiveOS/rootfs.img ]; then
  unsquashfs -d ${TMPDIR}/squashfs/rootfs/ -f ${TMPDIR}/squashfs/LiveOS/rootfs.img
  rm -f ${TMPDIR}/squashfs/LiveOS/rootfs.img
  SQUASH_TMPDIR=${TMPDIR}/squashfs/rootfs
else
  SQUASH_TMPDIR=${TMPDIR}/squashfs
fi

# prepare squashfs system files files for chroot
rm -f ${SQUASH_TMPDIR}/etc/resolv.conf
cp -L /etc/resolv.conf ${SQUASH_TMPDIR}/etc/resolv.conf
mount --bind ${SQUASH_TMPDIR} ${SQUASH_TMPDIR}
mount --bind /dev ${SQUASH_TMPDIR}/dev
mount -t proc none ${SQUASH_TMPDIR}/proc

# run ansible playbook against system files
cp -R $(pwd)/. ${SQUASH_TMPDIR}/usr/src/ansible-gpdpocket/
chroot ${SQUASH_TMPDIR} /bin/bash -c "/bin/bash /usr/src/ansible-gpdpocket/bootstrap-system.sh"

# fix squashfs system files after chroot
rm -rf \
    ${SQUASH_TMPDIR}/etc/resolv.conf \
    ${SQUASH_TMPDIR}/usr/src/ansible-gpdpocket \
    ${SQUASH_TMPDIR}/tmp/bootstrap-system.sh

# copy kernels in to place
while read -r KERNEL_PATH; do
  INITRD_PATH=$(find $(dirname ${KERNEL_PATH}) -maxdepth 1 -type f -regex '.*\(img\|lz\|gz\)$' -print -quit)
  if [ ! -z ${INITRD_PATH} ]; then
    cp -L ${SQUASH_TMPDIR}/boot/initrd.img-*bootstrap ${INITRD_PATH}
  fi
  cp -L ${SQUASH_TMPDIR}/boot/vmlinuz-*-bootstrap ${KERNEL_PATH}
done <<< "${KERNEL_PATHS}"

# calculate filesizes
umount -lf ${SQUASH_TMPDIR}
if [ -f ${TMPDIR}/casper/filesystem.size ]; then
  printf $(du -sx --block-size=1 ${SQUASH_TMPDIR} | cut -f1) > ${TMPDIR}/casper/filesystem.size
elif [ -f ${TMPDIR}/live/filesystem.size ]; then
  printf $(du -sx --block-size=1 ${SQUASH_TMPDIR} | cut -f1) > ${TMPDIR}/live/filesystem.size
fi

# re-compress squashfs
if [[ ${SQUASH_TMPDIR} = *"/rootfs"* ]]; then
  mksquashfs ${SQUASH_TMPDIR} ${TMPDIR}/squashfs/LiveOS/rootfs.img
  rm -rf ${SQUASH_TMPDIR}
  mksquashfs ${TMPDIR}/squashfs ${SQUASHFS_PATH}
else
  mksquashfs ${SQUASH_TMPDIR} ${SQUASHFS_PATH}
  rm -rf ${SQUASH_TMPDIR}
fi

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