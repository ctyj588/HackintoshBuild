#!/bin/bash

start=$(date +%s)
url=$1
cd "$url"
dir=hackintosh_Plugins
if [ ! -e $dir ]; then
    mkdir -p $dir/Release
    mkdir -p $dir/Sources
fi
cd "$dir/Sources"

proxy=$3
if [ $proxy!='' ]; then
export http_proxy=$proxy
export https_proxy=$proxy
fi

path=$5

echo -e "正在检测编译环境完整性：\n"

################# nasm ##################
echo "正在验证 mtoc"

mtoc_hash=$(curl -L "https://github.com/acidanthera/ocbuild/raw/master/external/mtoc-mac64.sha256") || exit 1

if [ "${mtoc_hash}" = "" ]; then
  echo "Cannot obtain the latest compatible mtoc hash!"
  exit 1
fi

valid_mtoc=false
if [ "$(which mtoc)" != "" ]; then
  mtoc_path=$(which mtoc)
  mtoc_hash_user=$(shasum -a 256 "${mtoc_path}" | cut -d' ' -f1)
  if [ "${mtoc_hash}" = "${mtoc_hash_user}" ]; then
    valid_mtoc=true
  elif [ "${IGNORE_MTOC_VERSION}" = "1" ]; then
    echo "Forcing the use of UNKNOWN mtoc version due to IGNORE_MTOC_VERSION=1"
    valid_mtoc=true
  elif [ "${mtoc_path}" != "/usr/local/bin/mtoc" ]; then
    echo "Custom UNKNOWN mtoc is installed to ${mtoc_path}!"
    echo "Hint: Remove this mtoc or use IGNORE_MTOC_VERSION=1 at your own risk."
    exit 1
  else
    echo "Found incompatible mtoc installed to ${mtoc_path}!"
    echo "Expected SHA-256: ${mtoc_hash}"
    echo "Found SHA-256:    ${mtoc_hash_user}"
    echo "Hint: Reinstall this mtoc or use IGNORE_MTOC_VERSION=1 at your own risk."
  fi
fi

if ! $valid_mtoc; then
echo "尚未安装 mtoc 或 mtoc 版本不符，现在为您安装"
osascript <<EOF
do shell script "mkdir -p /usr/local/bin || exit 1; cp ${path%/*}/mtoc /usr/local/bin/mtoc || exit 1; cp ${path%/*}/mtoc /usr/local/bin/mtoc.NEW || exit 1" with prompt "安装 mtoc 需要授权" with administrator privileges
EOF
fi

################# nasm ##################
echo "正在验证 nasm"

if [ "$(nasm -v)" = "" ] || [ "$(nasm -v | grep Apple)" != "" ]; then
echo "您尚未安装 nasm，现在为您安装"
osascript <<EOF
do shell script "mkdir -p /usr/local/bin || exit 1; cp ${path%/*}/nasm /usr/local/bin/ || exit 1; cp ${path%/*}/ndisasm /usr/local/bin/ || exit 1" with prompt "安装 nsam 需要授权" with administrator privileges
EOF
fi

################# xcodebuild ##################
echo "正在验证 xcodebuild"

if [ "$(xcodebuild -version)" = "" ]; then
echo "未找到 xcodebuild，正在检测 Xcode"
if [ -d "/Applications/Xcode.app" ]; then
echo "检测到 Xcode.app，执行 xcode-select"
osascript <<EOF
do shell script "xcode-select --switch /Applications/Xcode.app/Contents/Developer" with prompt "xcode-select 需要授权" with administrator privileges
EOF
elif [ -d "/Applications/Xcode-beta.app" ]; then
echo "检测到 Xcode-beta.app，执行 xcode-select"
osascript <<EOF
do shell script "xcode-select --switch /Applications/Xcode-beta.app/Contents/Developer" with prompt "xcode-select 需要授权" with administrator privileges
EOF
else
echo "未找到 Xcode，请先安装 Xcode"
exit 1
fi
fi

if [ "$(xcodebuild -version)" = "" ]; then
    echo $(xcodebuild -version)
    echo "xcodebuild 环境检测失败，程序结束。"
    exit 1
fi

echo "环境完整性验证完成，进入编译阶段。"

buildArray=(
'OpenCore,https://github.com/acidanthera/OpenCorePkg.git'
'Lilu,https://github.com/acidanthera/Lilu.git'
'AirportBrcmFixup,https://github.com/acidanthera/AirportBrcmFixup.git'
'AppleALC,https://github.com/acidanthera/AppleALC.git'
'ATH9KFixup,https://github.com/chunnann/ATH9KFixup.git'
'BT4LEContinuityFixup,https://github.com/acidanthera/BT4LEContinuityFixup.git'
'CPUFriend,https://github.com/acidanthera/CPUFriend.git'
'HibernationFixup,https://github.com/acidanthera/HibernationFixup.git'
'NoTouchID,https://github.com/al3xtjames/NoTouchID.git'
'RTCMemoryFixup,https://github.com/acidanthera/RTCMemoryFixup.git'
'SystemProfilerMemoryFixup,https://github.com/Goldfish64/SystemProfilerMemoryFixup.git'
'VirtualSMC,https://github.com/acidanthera/VirtualSMC.git'
'acidanthera_WhateverGreen,https://github.com/acidanthera/WhateverGreen.git'
'bugprogrammer_WhateverGreen,https://github.com/bugprogrammer/WhateverGreen.git'
'IntelMausi,https://github.com/acidanthera/IntelMausi.git'
'AtherosE2200Ethernet,https://github.com/Mieze/AtherosE2200Ethernet.git'
'RTL8111,https://github.com/Mieze/RTL8111_driver_for_OS_X.git'
'NVMeFix,https://github.com/acidanthera/NVMeFix.git'
'MacProMemoryNotificationDisabler,https://github.com/IOIIIO/MacProMemoryNotificationDisabler.git'
)

liluPlugins='AirportBrcmFixup AppleALC ATH9KFixup BT4LEContinuityFixup CPUFriend HibernationFixup NoTouchID RTCMemoryFixup SystemProfilerMemoryFixup VirtualSMC acidanthera_WhateverGreen bugprogrammer_WhateverGreen NVMeFix MacProMemoryNotificationDisabler'

bootLoader='OpenCore'

if [[ $4 == "" ]]; then
    logs=/dev/null
else
    if [ -e $4/buildlog ]; then
        rm -rf $4/buildlog
    fi
    mkdir $4/buildlog
fi

selectList=$2
selectedArray=(`echo $selectList | tr ',' ' '`)
for i in ${selectedArray[*]}; do
    if [[ $4 != "" ]]; then
        logs=$4/buildlog/${buildArray[$i]%,*}.log
    fi
    if [ -e ../Release/${buildArray[$i]%,*} ]; then
        rm -rf ../Release/${buildArray[$i]%,*}
    fi
    mkdir -p ../Release/${buildArray[$i]%,*}/Release
    mkdir -p ../Release/${buildArray[$i]%,*}/Debug
    if [ -e ./${buildArray[$i]%,*} ]; then
        rm -rf ./${buildArray[$i]%,*}
    fi
    echo "正在下载源码："${buildArray[$i]%,*}
    git clone -q ${buildArray[$i]##*,} ${buildArray[$i]%,*} -b master --depth=1
    pushd ${buildArray[$i]%,*} >> $logs

    if [[ $bootLoader =~ ${buildArray[$i]%,*} ]]; then
        echo "正在编译："${buildArray[$i]%,*}
        echo "（该过程需要下载较多依赖，请保持网络畅通，耗时较长请耐心等待。如中途停止请生成日志查看原因。）"
        ./build_oc.tool >> $logs || exit 1
        if [ -e Binaries/RELEASE/ ]; then
            cp Binaries/RELEASE/*.zip ../../Release/${buildArray[$i]%,*}/Release >> $logs || exit 1

            cp Binaries/DEBUG/*.zip ../../Release/${buildArray[$i]%,*}/Debug >> $logs || exit 1
        else
            cp Binaries/*-RELEASE.zip ../../Release/${buildArray[$i]%,*}/Release >> $logs || exit 1

            cp Binaries/*-DEBUG.zip ../../Release/${buildArray[$i]%,*}/Debug >> $logs || exit 1
        fi

        echo "编译成功："${buildArray[$i]%,*}
    else
        if [[ $liluPlugins =~ ${buildArray[$i]%,*} ]]; then
            if [ ! -e *.kext ]; then
                echo "编译 "${buildArray[$i]%,*}" 需要依赖 Lilu"
                if [ ! -e $url/$dir/Sources/Lilu/build/Debug/Lilu.kext ]; then
                    pushd $url/$dir/Sources >> $logs
                    echo "未找到缓存，正在下载源码：Lilu"
                    git clone -q https://github.com/acidanthera/Lilu.git -b master --depth=1 && cd Lilu
                    echo "正在编译：Lilu"
                    xcodebuild -configuration Debug >> $logs || exit 1
                    popd >> $logs
                    echo "正在拷贝：Lilu"
                    cp -Rf $url/$dir/Sources/Lilu/build/Debug/Lilu.kext . >> $logs || exit 1
                else
                    echo "找到缓存，正在拷贝：Lilu"
                    cp -Rf $url/$dir/Sources/Lilu/build/Debug/Lilu.kext . >> $logs || exit 1
                fi
            fi
        fi
        echo "正在编译："${buildArray[$i]%,*}
        xcodebuild -configuration Release >> $logs || exit 1
        xcodebuild -configuration Debug >> $logs || exit 1
        if [ -e build/Release/*.zip ]; then
            cp -Rf build/Release/*.zip ../../Release/${buildArray[$i]%,*}/Release >> $logs || exit 1
            cp -Rf build/Debug/*.zip ../../Release/${buildArray[$i]%,*}/Debug >> $logs || exit 1
            echo "编译成功："${buildArray[$i]%,*}
        else
            cp -Rf build/Release/*.kext ../../Release/${buildArray[$i]%,*}/Release/${buildArray[$i]%,*}-Release.kext >> $logs || exit 1
            cp -Rf build/Debug/*.kext ../../Release/${buildArray[$i]%,*}/Debug/${buildArray[$i]%,*}-Debug.kext >> $logs || exit 1
            echo "编译成功："${buildArray[$i]%,*}
        fi
    fi
    popd >> $logs
done;

if [[ $4 != "" ]]; then
    open $4/buildlog/
fi
open "$url/$dir/Release"

end=$(date +%s)
take=$(( end - start ))
echo 编译结束程序执行了${take}秒。
