CONFIG=localmodconfig # or oldconfig
CLEAN=true

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

CWD=$(pwd)

mkdir tmp && cd tmp

sudo dnf install -y make automake gcc gcc-c++ kernel-devel openssl-devel \
		    fakeroot ncurses-devel patch flex elfutils-libelf-devel \
		    --downloadonly --destdir=./

sudo dnf install -y *.rpm

cd $CWD

cd kernel-src/
cd $LINUX_DIR

patch -p1 < <(gunzip -c ../$PATCH)

cp /boot/config-$(uname -r) .config && make $CONFIG

if [ $CONFIG = "localmodconfig" ]; then
	make menuconfig
fi

make bzImage

make modules

sudo make modules_install

sudo make install

if [ $CLEAN = true ]; then
	cd $CWD/tmp
	if [ "$(ls)" != "" ]; then
		sudo dnf -y remove *.rpm
	fi
fi
