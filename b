CROSS_COMPILER_PATH="$HOME/opt/cross"
GCC="$CROSS_COMPILER_PATH/bin/x86_64-elf-gcc"
AR="$CROSS_COMPILER_PATH/bin/x86_64-elf-ar"

POSIXVALA_DIR="$HOME/posixvala"
BECAVSE_DIR="$HOME/becavse"

VALA_COMPILE_PRE="-m64 -c"
VALA_COMPILE_POST="-Wall -Wno-unused-but-set-variable -nostdlib -nostartfiles -nodefaultlibs -nostdinc -ffreestanding -I $POSIXVALA_DIR/include -I $BECAVSE_DIR/newlib/include -I $CROSS_COMPILER_PATH/lib/gcc/x86_64-elf/4.8.1/include"

rm -rf tmp
mkdir tmp

echo compiling kernel bits

bvala(){
  local tmpsrc=tmp/$1
  local c=`echo $tmpsrc | sed -e 's/vala/c/g'`
  local obj=`echo $tmpsrc | sed -e 's/vala/o/g'`

  cp $1 $tmpsrc

  echo $1 :: vala to c
  $POSIXVALA_DIR/posixvala -C $tmpsrc || exit
  rm $tmpsrc

  # sed in-place syntax differs for bsd and gnu sed,
  #  so we do this weak sauce instead.
  sed -e 's/!GLIB_CHECK_VERSION (2,35,0)/false/g' $c > ${c}.mangled
  rm $c && mv ${c}.mangled $c

  echo $1 :: compile c
  $GCC $VALA_COMPILE_PRE -o $obj $c $VALA_COMPILE_POST || exit
}

bvala main.vala

echo assemble bits.asm
/usr/local/bin/nasm -f elf64 -o tmp/bits.o bits.asm

echo linking flat 64bit kernel binary
# we use /usr/bin/local/ld b/c i compile on a mac and the default ld is inadequate.
# /usr/bin/local/ld can be installed by doing 'brew install binutils' if you have homebrew.
# if you already have gnu ld, you can just use that instead.
#
$HOME/opt/cross/bin/x86_64-elf-ld -T linker64.ld -o tmp/kernel64.sys tmp/main.o tmp/bits.o lib/posixvala-libglib.a lib/newlib-libm.a lib/newlib-libc.a lib/newlib-libnosys.a || exit


echo composing disk image for Parallels Desktop
rm -rf disk.hdd
cp -r pure64/pure64.hdd disk.hdd
/Applications/Parallels\ Desktop.app/Contents/Applications/Parallels\ Mounter.app/Contents/MacOS/Parallels\ Mounter disk.hdd >boring.log &
sleep 1
MOUNTED_PARALLELS_DISK=`find /Volumes/.PEVolumes | grep pure64.sys | sed -e 's/\/pure64.sys//g'`
cp tmp/kernel64.sys ${MOUNTED_PARALLELS_DISK}/kernel64.sys || exit
hdiutil detach ${MOUNTED_PARALLELS_DISK}

#echo composing disk image for VirtualBox/Bochs/etc
#rm -rf disk.img
#cp pure64/Pure64.img disk.img
#echo attaching >boring.log
#hdiutil attach disk.img >>boring.log
#cp tmp/kernel64.sys /Volumes/BECAUSE/kernel64.sys
#echo detaching >>boring.log
#hdiutil detach /Volumes/BECAUSE >>boring.log

#echo creating actual image for VirtualBox
#rm -rf disk.vdi
#echo converting image using vboxmanage >>boring.log
#VBoxManage convertfromraw disk.img disk.vdi --uuid '{4c2c12cf-ee32-4a37-afe9-8a4bd88abbca}' >>boring.log

echo done.

