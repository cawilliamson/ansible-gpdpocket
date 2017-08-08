#!/bin/bash

# set bash options
set -e -x

# set variables
TMPDIR=/var/tmp/bootstrap-iso

# clean up from previous run
umount -lf ${TMPDIR}/squashfs || true
rm -rf ${TMPDIR}

# install dependencies
if [ -f /usr/bin/pacman ]; then
  pacman -Sy --noconfirm squashfs-tools xorriso
elif [ -f /usr/bin/apt-get ]; then
  apt-get update
  apt-get -y install squashfs-tools xorriso
elif [ -f /usr/bin/yum ]; then
  apt-get update
  yum install -y squashfs-tools xorriso
elif [ -f /usr/sbin/emerge ]; then
  emerge --sync
  USE="lz4 lzma lzo xz" emerge dev-libs/libisoburn sys-fs/squashfs-tools
fi

# extract iso
mkdir -p ${TMPDIR}
xorriso -osirrox on -indev "${1}" -extract / ${TMPDIR}

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

# prepare squashfs system files files for chroot
if [ -f ${TMPDIR}/squashfs/LiveOS/rootfs.img ]; then
  mount -t ext4 -o loop,rw ${TMPDIR}/squashfs/LiveOS/rootfs.img ${TMPDIR}/squashfs
else
  mount --bind ${TMPDIR}/squashfs ${TMPDIR}/squashfs
fi
rm -f ${TMPDIR}/squashfs/etc/resolv.conf
cp /etc/resolv.conf ${TMPDIR}/squashfs/etc/resolv.conf
mount --bind /dev ${TMPDIR}/squashfs/dev
mount -t tmpfs -o nosuid,nodev,noexec shm ${TMPDIR}/squashfs/dev/shm
chmod 1777 ${TMPDIR}/squashfs/dev/shm
mount -t proc none ${TMPDIR}/squashfs/proc

# run ansible playbook against system files
cp bootstrap-system.sh ${TMPDIR}/squashfs/tmp/bootstrap-system.sh
chroot ${TMPDIR}/squashfs /bin/bash -c "/bin/bash /tmp/bootstrap-system.sh"

# fix squashfs system files after chroot
rm -rf \
    ${TMPDIR}/squashfs/etc/resolv.conf \
    ${TMPDIR}/squashfs/usr/src/ansible-gpdpocket \
    ${TMPDIR}/squashfs/tmp/bootstrap-system.sh

# copy kernel and initrd images in to place
while read -r KERNEL_PATH; do
  INITRD_PATH=$(find $(dirname ${KERNEL_PATH}) -maxdepth 1 -type f -regex '.*\(img\|lz\|gz\).*$' -print -quit)
  
  # check if initrd is install image
  if [ ! -z ${INITRD_PATH} ]; then
    if [[ "${KERNEL_PATH}" == *'/install/'* ]] || [[ "${KERNEL_PATH}" == *'/d-i/'* ]]; then
      mkdir -p ${TMPDIR}/install-initrd ${TMPDIR}/live-initrd
      
      cd ${TMPDIR}/install-initrd
      zcat ${INITRD_PATH} | cpio --extract --make-directories
      
      cd ${TMPDIR}/live-initrd
      zcat ${TMPDIR}/squashfs/boot/initrd.img-*bootstrap | cpio --extract --make-directories
      
      cp -ar ${TMPDIR}/live-initrd/lib/modules/*-bootstrap ${TMPDIR}/install-initrd/lib/modules/
      
      cd ${TMPDIR}/install-initrd
      find . | cpio --create --format='newc' | gzip -c > ${INITRD_PATH}
      
      rm -rf ${TMPDIR}/install-initrd ${TMPDIR}/live-initrd
    else
      cp ${TMPDIR}/squashfs/boot/initrd.img-*bootstrap ${INITRD_PATH}
    fi
  fi
  
  cp ${TMPDIR}/squashfs/boot/vmlinuz-*-bootstrap ${KERNEL_PATH}
done <<< "${KERNEL_PATHS}"

# calculate filesizes
umount -lf ${TMPDIR}/squashfs
if [ -f ${TMPDIR}/casper/filesystem.size ]; then
  printf $(du -sx --block-size=1 ${TMPDIR}/squashfs | cut -f1) > ${TMPDIR}/casper/filesystem.size
elif [ -f ${TMPDIR}/live/filesystem.size ]; then
  printf $(du -sx --block-size=1 ${TMPDIR}/squashfs | cut -f1) > ${TMPDIR}/live/filesystem.size
fi

# re-compress squashfs
mksquashfs ${TMPDIR}/squashfs ${SQUASHFS_PATH}
rm -rf ${TMPDIR}/squashfs

# add distro-specific checksums
if [ -f ${TMPDIR}/arch/x86_64/airootfs.md5 ]; then
  md5sum ${SQUASHFS_PATH} > ${TMPDIR}/arch/x86_64/airootfs.md5
elif [ -f ${TMPDIR}/md5sum.txt ]; then
  find ${TMPDIR} -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > ${TMPDIR}/md5sum.txt
fi

# re-assemble iso
dd if="${1}" bs=512 count=1 of=${TMPDIR}/isolinux/isohdpfx.bin
ISO_LABEL=$(blkid -o value -s LABEL "${1}")
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