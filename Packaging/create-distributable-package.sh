#!/bin/sh
set -e

info()
{
    local green="\033[1;32m"
    local normal="\033[0m"
    echo "[${green}Package${normal}] $1"
}

spushd()
{
    pushd "$1" > /dev/null
}

spopd()
{
    popd > /dev/null
}

append_framework_from_archive()
{
    archive_name="$1"
    framework_path="$BUILD_DIR/${archive_name}.xcarchive/Products/Library/Frameworks/VLCKit.framework"
    dsym_path="$BUILD_DIR/${archive_name}.xcarchive/dSYMs/VLCKit.framework.dSYM"

    if [ -d "$framework_path" ]; then
        frameworks="$frameworks -framework $framework_path"
        if [ -d "$dsym_path" ]; then
            frameworks="$frameworks -debug-symbols $dsym_path"
        fi
    fi
}

append_license_debug_sources()
{
    debug_zip="$1"
    manifest="$2"

    if [ ! -f "$manifest" ]; then
        return
    fi

    while IFS="$(printf '\t')" read -r _ source_path _; do
        if [ -z "$source_path" ]; then
            continue
        fi

        case "$source_path" in
            /*)
                file_path="$source_path"
                ;;
            *)
                file_path="$source_path"
                ;;
        esac

        if [ -f "$file_path" ]; then
            zip -y -q "$debug_zip" "$file_path"
        fi
    done < "$manifest"
}

IOS=no
TVOS=no
MACOS=no
XROS=no
WATCHOS=no
BUILDFORALL=no
VERBOSE=no
USEZIP=no
USECOMPRESSEDARCHIVE=yes
USEDMG=no

usage()
{
cat << EOF
usage: $0 [options]

Package VLCKit

  By default, VLCKit will be packaged as a tar.xz archive.
  You can use the options below to package a different flavor of VLCKit
  or/and to store the binaries in a zip or a dmg file instead.

OPTIONS:
   -h            Show some help
   -v            Be verbose
   -x            Package VLCKit for macOS
   -m            Package VLCKit for iOS
   -t            Package VLCKit for tvOS
   -i            Package VLCKit for xrOS
   -w            Package VLCKit for watchOS
   -a            Package VLCKit for all enabled OS
   -z            Use zip file format
   -d            Use dmg file format
EOF

}

while getopts "hvmxiwtzad" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         m)
             IOS=yes
             ;;
         t)
             TVOS=yes
             ;;
         i)
             XROS=yes
             ;;
         w)
             WATCHOS=yes
             ;;
         x)
             MACOS=yes
             ;;
         a)
             BUILDFORALL=yes
             ;;
         z)
             USEZIP=yes
             ;;
         d)
             USEDMG=yes
             USECOMPRESSEDARCHIVE=no
             ;;
     esac
done
shift $(($OPTIND - 1))

out="/dev/null"
verbose_flag=""
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
   verbose_flag="-v"
fi

if [ "x$1" != "x" ]; then
    usage
    exit 1
fi

root=`dirname $0`/../

DMGFOLDERNAME=""
DMGITEMNAME=""

if [ "$MACOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-macOS-binary"
    else
        DMGFOLDERNAME="VLCKit for macOS - binary package"
    fi
    DMGITEMNAME="VLCKit-macOS-REPLACEWITHVERSION"
fi
if [ "$IOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-iOS-binary"
    else
        DMGFOLDERNAME="VLCKit for iOS - binary package"
    fi
    DMGITEMNAME="VLCKit-iOS-REPLACEWITHVERSION"
fi
if [ "$TVOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-tvOS-binary"
    else
        DMGFOLDERNAME="VLCKit for tvOS - binary package"
    fi
    DMGITEMNAME="VLCKit-tvOS-REPLACEWITHVERSION"
fi
if [ "$XROS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-xrOS-binary"
    else
        DMGFOLDERNAME="VLCKit for xrOS - binary package"
    fi
    DMGITEMNAME="VLCKit-xrOS-REPLACEWITHVERSION"
fi
if [ "$WATCHOS" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-watchOS-binary"
    else
        DMGFOLDERNAME="VLCKit for watchOS - binary package"
    fi
    DMGITEMNAME="VLCKit-watchOS-REPLACEWITHVERSION"
fi
if [ "$BUILDFORALL" = "yes" ]; then
    if [ "$USECOMPRESSEDARCHIVE" = "yes" ]; then
        DMGFOLDERNAME="VLCKit-binary"
    else
        DMGFOLDERNAME="VLCKit - binary package"
    fi
    DMGITEMNAME="VLCKit-REPLACEWITHVERSION"
fi

info "checking for distributable binary package"

BUILD_DIR=`pwd`/build
frameworks=""

spushd ${root}
if [ "$MACOS" = "yes" ]; then
    if [ ! -e "build/macOS/VLCKit.xcframework" ]; then
        info "VLCKit for macOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -x -f -r ${verbose_flag}
    fi
    append_framework_from_archive "VLCKit-macosx"
fi
if [ "$TVOS" = "yes" ]; then
    if [ ! -e "build/tvOS/VLCKit.xcframework" ]; then
        info "VLCKit for tvOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -f -t ${verbose_flag}
    fi
    append_framework_from_archive "VLCKit-appletvsimulator"
    append_framework_from_archive "VLCKit-appletvos"
fi
if [ "$IOS" = "yes" ]; then
    if [ ! -e "build/iOS/VLCKit.xcframework" ]; then
        info "VLCKit for iOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -f -r ${verbose_flag}
    fi
    append_framework_from_archive "VLCKit-iphonesimulator"
    append_framework_from_archive "VLCKit-iphoneos"
fi
if [ "$XROS" = "yes" ]; then
    if [ ! -e "build/xrOS/VLCKit.xcframework" ]; then
        info "VLCKit for xrOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -i -f ${verbose_flag}
    fi
    append_framework_from_archive "VLCKit-xrsimulator"
    append_framework_from_archive "VLCKit-xros"
fi
if [ "$WATCHOS" = "yes" ]; then
    if [ ! -e "build/watchOS/VLCKit.xcframework" ]; then
        info "VLCKit for xrOS not found for distribution, creating... this will take long"
        ./compileAndBuildVLCKit.sh -w -f ${verbose_flag}
    fi
    append_framework_from_archive "VLCKit-watchsimulator"
    append_framework_from_archive "VLCKit-watchos"
fi

info "Deleting previous data"
rm -rf "${DMGFOLDERNAME}"

info "Collecting items"
mkdir -p "${DMGFOLDERNAME}"
mkdir -p "${DMGFOLDERNAME}/Sample Code"

platform_count=0
if [ "$MACOS" = "yes" ]; then
    platform_count=$((platform_count + 1))
fi
if [ "$IOS" = "yes" ]; then
    platform_count=$((platform_count + 1))
fi
if [ "$TVOS" = "yes" ]; then
    platform_count=$((platform_count + 1))
fi
if [ "$XROS" = "yes" ]; then
    platform_count=$((platform_count + 1))
fi
if [ "$WATCHOS" = "yes" ]; then
    platform_count=$((platform_count + 1))
fi

if [ "$BUILDFORALL" = "yes" ] || [ $platform_count -gt 1 ]; then
	PROJECT_DIR=`pwd`
	rm -rf build/VLCKit.xcframework
    xcodebuild -create-xcframework $frameworks -output build/VLCKit.xcframework
    cp -R build/VLCKit.xcframework "${DMGFOLDERNAME}"
else
if [ "$MACOS" = "yes" ]; then
    cp -R build/macOS/VLCKit.xcframework "${DMGFOLDERNAME}"
    cp -R Examples/macOS/* "${DMGFOLDERNAME}/Sample Code"
fi
if [ "$TVOS" = "yes" ]; then
    cp -R build/tvOS/VLCKit.xcframework "${DMGFOLDERNAME}"
fi
if [ "$XROS" = "yes" ]; then
    cp -R build/xrOS/VLCKit.xcframework "${DMGFOLDERNAME}"
fi
if [ "$WATCHOS" = "yes" ]; then
    cp -R build/watchOS/VLCKit.xcframework "${DMGFOLDERNAME}"
fi
if [ "$IOS" = "yes" ]; then
    cp -R build/iOS/VLCKit.xcframework "${DMGFOLDERNAME}"
    cp -R Examples/iOS/* "${DMGFOLDERNAME}/Sample Code"
fi
fi
cp -R Documentation "${DMGFOLDERNAME}"
cp COPYING "${DMGFOLDERNAME}"
cp NEWS "${DMGFOLDERNAME}"
info "Extracting license notices"
"${root}/Packaging/extract-license-notices.sh" --output "${DMGFOLDERNAME}/License Notices" --evidence-root "${DMGFOLDERNAME}"
info "Creating license notices archive"
rm -f "${DMGITEMNAME}-LicenseNotices.zip"
zip -y -q -r "${DMGITEMNAME}-LicenseNotices.zip" "${DMGFOLDERNAME}/License Notices"
info "Creating license debug archive"
rm -f "${DMGITEMNAME}-LicenseDebug.zip"
zip -y -q -r "${DMGITEMNAME}-LicenseDebug.zip" "${DMGFOLDERNAME}/License Notices"
zip -y -q "${DMGITEMNAME}-LicenseDebug.zip" COPYING libvlc/vlc/COPYING libvlc/vlc/COPYING.LIB 2> /dev/null || true
append_license_debug_sources "${DMGITEMNAME}-LicenseDebug.zip" "${DMGFOLDERNAME}/License Notices/manifests/candidate-license-files.tsv"
if [ -d "libvlc/vlc" ]; then
    find libvlc/vlc -path '*/static-lib/static-libs-list' -type f | while IFS= read -r static_list; do
        zip -y -q "${DMGITEMNAME}-LicenseDebug.zip" "$static_list"
    done
fi
spushd "${DMGFOLDERNAME}"
mv NEWS NEWS.txt
mv COPYING COPYING.txt
spopd

if [ "$USEDMG" = "yes" ]; then
    info "Creating disk-image"
    rm -f ${DMGITEMNAME}-rw.dmg
    hdiutil create -srcfolder "${DMGFOLDERNAME}" "${DMGITEMNAME}-rw.dmg" -scrub -format UDRW
    mkdir -p ./mount

    info "Moving file icons around"
    hdiutil attach -readwrite -noverify -noautoopen -mountRoot ./mount ${DMGITEMNAME}-rw.dmg
    if [ "$MOBILE" = "no" ]; then
    osascript Packaging/dmg_setup.scpt "${DMGFOLDERNAME}"
    else
        if [ "$TV" = "no" ]; then
            osascript Packaging/mobile_dmg_setup.scpt "${DMGFOLDERNAME}"
        fi
    fi
    hdiutil detach ./mount/"${DMGFOLDERNAME}"

    info "Compressing disk-image"
    rm -f ${DMGITEMNAME}.dmg
    hdiutil convert "${DMGITEMNAME}-rw.dmg" -format UDBZ -o "${DMGITEMNAME}.dmg"
    rm -f ${DMGITEMNAME}-rw.dmg
    rm -rf "${DMGFOLDERNAME}"
else
    if [ "$USEZIP" = "yes" ]; then
        info "Creating zip-archive"
        zip -y -r ${DMGITEMNAME}.zip "${DMGFOLDERNAME}"
    else
        info "Creating xz-archive"
        tar -cJf ${DMGITEMNAME}.tar.xz "${DMGFOLDERNAME}"
    fi
fi

spopd

info "Distributable package created"
