RT_URL=$(lynx --dump -listonly https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/ \
         | grep  $(lynx --dump -listonly https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/ \
         | grep -P "\d+.\d+" -o -A 0 | sort -V | tail -1) | grep -P "https.*\/\Z" -o)
PATCH_URL=$(lynx --dump -listonly $RT_URL | grep -P "(?:^|\W)patch(?:$|\W)" | grep -P "https.*gz" -o)
KERNEL_VER=$(echo $PATCH_URL | grep -P "(?<=patch-).*(?=-rt)" -o)
KERNEL_MAJOR_VER=$(echo $KERNEL_VER | grep -P "^\d" -o)
KERNEL_MINOR_VER=$(echo $KERNEL_VER | grep -P "(?<=\.)\d+(?=\.)" -o)
KERNEL_MINOR_INDEX=$(echo $KERNEL_VER | grep -P "\d+\Z" -o)

KERNEL_URL="https://mirrors.edge.kernel.org/pub/linux/kernel/v$KERNEL_MAJOR_VER.x/linux-$KERNEL_VER.tar.gz"
LINUX=$(echo $KERNEL_URL | grep -P "[^\/]+$" -o)
PATCH=$(echo $PATCH_URL | grep -P "[^\/]+$" -o)
LINUX_DIR=$(echo $LINUX | grep -P ".*(?=(.tar.gz))" -o)

echo "KERNEL_URL is $KERNEL_URL"
echo "PATCH_URL is $PATCH_URL"
echo "Fetching files"
wget $KERNEL_URL -O $LINUX
wget $PATCH_URL -O $PATCH

echo "unpacking kernel into src directory"
FILE_SIZE=$(stat -c %s $LINUX)
tar -xf $LINUX -C kernel-src/ --checkpoint-action=ttyout="%{}T bytes of $FILE_SIZE total  \r"

mv $PATCH kernel-src/

sudo dnf install make automake gcc gcc-c++ kernel-devel openssl-devel
sudo dnf install fakeroot ncurses-devel patch flex elfutils-libelf-devel

CWD=$(pwd)
cd kernel-src/
cd $LINUX_DIR

patch -p1 < <(gunzip -c ../patch-4.18.7-rt5.patch.gz)

cp /boot/config-$(uname -r) .config && make oldconfig

make bzImage

make modules

sudo make modules_install

sudo make install
