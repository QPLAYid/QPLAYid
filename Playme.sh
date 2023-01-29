
#! /bin/sh
set -e o pipefail

KERNEL_DIR=$PWD
TG_BOT_TOKEN=$1
CHATID=$2
PREFIX=$3

exports() {
	export KBUILD_BUILD_USER="archie"
	export KBUILD_BUILD_HOST="HyperBeast"
	export ARCH=arm64
	export SUBARCH=arm64
	export CROSS_COMPILE_ARM32=$KERNEL_DIR/linaro32/bin/armv8l-linux-gnueabihf-
# 	export KBUILD_COMPILER_STRING=$($KERNEL_DIR/clang-llvm/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
# 	LD_LIBRARY_PATH=$KERNEL_DIR/clang-llvm/lib64:$LD_LIBRARY_PATH
# 	export LD_LIBRARY_PATH
	export CROSS_COMPILE=$KERNEL_DIR/linaro/bin/aarch64-linux-gnu-
# 	PATH=$KERNEL_DIR/clang-llvm/bin/:$KERNEL_DIR/aarch64-linux-android-4.9/bin/:$PATH
# 	export PATH
	export BOT_MSG_URL="https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument"
	export PROCS=$(nproc --all)
	DEFCONFIG=chef_defconfig
}

clone() {
	echo " "
	echo "★★Cloning GCC Toolchain from GitHub .."
	git clone --progress -j32 --depth 1 --no-single-branch https://github.com/archie9211/linaro -b master linaro
	git clone --progress -j32 --depth 1 --no-single-branch https://github.com/archie9211/linaro -b arm32 linaro32

	echo "★★GCC cloning done"
	echo ""
# 	echo "★★Cloning Clang 9 sources"
# 	wget $CLANG_URL
# 	mkdir clang-llvm
# 	tar -C clang-llvm -xvf clang*.tar.gz
# 	rm -rf clang*.tar.gz
# 	echo "★★Clang Done, Now Its time for AnyKernel .."
	git clone --depth 1 --no-single-branch https://github.com/archie9211/AnyKernel2 anykernel
# 	echo "★★Cloning libufdt"
# 	git clone https://android.googlesource.com/platform/system/libufdt $KERNEL_DIR/scripts/ufdt/libufdt
	echo "★★Cloning Kinda Done..!!!"
}

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

tg_post_build() {
	curl --progress-bar -F document=@"$1" $BOT_BUILD_URL \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3"  
}

build_kernel() {
	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	tg_post_msg "<b>NEW CI DarkOne Build Triggered</b>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>chef</code>%0A<b>Pipeline Host : </b><code>Github Actions</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>" "$CHATID"
	make -j$PROCS O=out \
		CROSS_COMPILE=$CROSS_COMPILE \
		CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 2>&1 | tee error.log
# 		CC=$CC \
# 		CLANG_TRIPLE=aarch64-linux-gnu- 2>&1 | tee error.log
	#make dtbo image
# 	make O=out dtbo.img
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	check_img
}
check_img() {
	if [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ] 
	    then
		gen_zip
	else
		tg_post_build "error.log" "$CHATID" "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
	fi
}
gen_zip() {
# 	mv $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb anykernel/Image.gz-dtb
# 	mv $KERNEL_DIR/out/arch/arm64/boot/dtbo.img AnyKernel2/dtbo.img
	cd $KERNEL_DIR/anykernel
	zip -r9 DarkOne-v3.0-chef-$PREIFIX * -x .git README.md
	MD5CHECK=$(md5sum $ZIPNAME-$ARG1-$DATE.zip | cut -d' ' -f1)
	tg_post_build DarkOne-v3.0-chef-$PREFIX.zip "$CHATID" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s) | MD5 Checksum : <code>$MD5CHECK</code>"
	cd ..
}
exports
# clone
# build_kernel
gen_zip
