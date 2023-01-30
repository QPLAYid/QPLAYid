#! /bin/sh
set -e o pipefail

KERNEL_DIR=$PWD
ARG1=$1 #It is the devicename [generally codename]
ARG2=$2 #It is the make arguments, whether clean / dirty / def_regs [regenerates defconfig]
ARG3=$3 #Build should be pushed or not [PUSH / NOPUSH]
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
export ZIPNAME="DarkOne-chef-Oreo-Pie-" #Specifies the name of kernel
##---------------------------------------------------##

#START : Argument 3 [ARG3] Check
case "$ARG3" in
  "PUSH" ) # Push build to TG Channel
      build_push=true
  ;;
  "NOPUSH" ) # Do not push
      build_push=false
  ;;
  * ) echo -e "\nError..!! Unknown command. Please refer README.\n"
      return
  ;;
esac # END : Argument 3 [ARG3] Check

##-----------------------------------------------------##

else
  echo -e "\nToo many Arguments..!! Provided - $# , Required - 3\nCheck README"
  return
#Get outta
fi

##------------------------------------------------------##

#Now Its time for other stuffs like cloning, exporting, etc

clone() {
	echo " "
	echo "★★Cloning GCC Toolchain from GitHub .."
	git clone --progress -j32 --depth 1 --no-single-branch https://github.com/archie9211/linaro -b master linaro
	git clone --progress -j32 --depth 1 --no-single-branch https://github.com/archie9211/linaro -b arm32 linaro32

	echo "★★GCC cloning done"
	echo ""
	git clone --depth 1 --no-single-branch https://github.com/archie9211/AnyKernel2 anykernel
	echo "★★Cloning Kinda Done..!!!"
}

##------------------------------------------------------##

function exports {
	export KBUILD_BUILD_USER="archie"
	export KBUILD_BUILD_HOST="HyperBeast"
	export ARCH=arm64
	export SUBARCH=arm64
	export CROSS_COMPILE_ARM32=$KERNEL_DIR/linaro32/bin/armv8l-linux-gnueabihf-
	export CROSS_COMPILE=$KERNEL_DIR/linaro/bin/aarch64-linux-gnu-
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	export PROCS=$(nproc --all)
}

##---------------------------------------------------------##

function tg_post_msg {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

function tg_post_build {
	curl --progress-bar -F document=@"$1" $BOT_BUILD_URL \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3"  
}

##----------------------------------------------------------##


##----------------------------------------------------------##

function build_kernel {
	if [ "$build_push" = true ]; then
		tg_post_msg "<b>$CIRCLE_BUILD_NUM CI Build Triggered</b>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$DEVICE</code>%0A<b>Pipeline Host : </b><code>CircleCI</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : %0A Branch : </b><code>$CIRCLE_BRANCH</code>%0A<b>Status : </b>#Nightly" "$CHATID"
	fi
	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	make -j$PROCS O=out \
		CROSS_COMPILE=$CROSS_COMPILE \
		CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 2>&1 | tee error.log
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	check_img
}

##-------------------------------------------------------------##

function check_img {
	if [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ] 
	    then
		gen_zip
	else
		tg_post_build "error.log" "$CHATID" "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
	fi
}

##--------------------------------------------------------------##

function gen_zip {
	mv $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb AnyKernel2/Image.gz-dtb
# 	mv $KERNEL_DIR/out/arch/arm64/boot/dtbo.img AnyKernel2/dtbo.img
	cd anykernel
	zip -r9 $ZIPNAME-$DATE * -x .git README.md
	MD5CHECK=$(md5sum $ZIPNAME-$DATE.zip | cut -d' ' -f1)
	tg_post_build $ZIPNAME* "$CHATID" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s) | MD5 Checksum : <code>$MD5CHECK</code>"
	cd ..
}

clone
exports
build_kernel

##----------------*****-----------
