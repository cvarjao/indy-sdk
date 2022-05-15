#!/bin/bash -e
# reference - https://github.com/oleganza/CoreBitcoin/blob/master/build_libraries.sh
# https://bignerdranch.com/blog/building-an-ios-app-in-rust-part-1-getting-started-with-rust/
# https://medium.com/@priya_talreja/create-custom-universal-framework-in-ios-aef7fa6fd51e
# https://stackoverflow.com/a/65315026

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
POSITIONAL_ARGS=()
_targets="aarch64-apple-ios,armv7-apple-ios,armv7s-apple-ios,i386-apple-ios,x86_64-apple-ios"

while [[ $# -gt 0 ]]; do
  case $1 in
    --targets)
      _targets="$2"
      shift # past argument
      shift # past value
      ;;
    --clean)
      OPT_CLEAN="true"
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

set
#echo $OPTS
#exit 
export OPENSSL_DIR=$(brew --prefix openssl@1.1)
#1.55.0
export RUST_VER=1.41.0
export PKG_CONFIG_ALLOW_CROSS=1

# change the current directory to the root of the repository
pushd "${SCRIPT_DIR}/../"
rustup default "${RUST_VER}"
rustup target add aarch64-apple-ios armv7-apple-ios armv7s-apple-ios i386-apple-ios x86_64-apple-ios
if [ "$OPT_CLEAN" == "true" ]; then
    echo "Cleaning previous build"
    rm -rf libindy/target
    rm -rf libindy/out_pod
fi

if [ ! -d libindy/target ]; then
    ./ci/ios-build.sh libindy "${_targets}"
else
    echo "Skipping build of libindy (reusing from cache libindy/target)"
fi

file libindy/out_pod/libindy.a

pushd wrappers/ios/libindy-pod

# Indy.xcworkspace
if [ ! -d Pods/Pods.xcodeproj ]; then
    pod install
else
    echo "Skipping 'pod install' (reusing from previous run)"
fi

BUILD_DIR="$(pwd)/build"
FRAMEWORK_DEVICE_PATH='build/iphoneos/Build/Products/Release-iphoneos/Indy.framework'
FRAMEWORK_SIMULATOR_PATH='build/iphonesimulator/Build/Products/Release-iphonesimulator/Indy.framework'

mkdir -p build/iphoneos
if [ ! -d "${FRAMEWORK_DEVICE_PATH}" ]; then
    echo "Building for iOS devices"
    #xcodebuild -workspace Indy.xcworkspace -scheme Indy -configuration Release -sdk iphoneos -archivePath Indy-Device.xcarchive -verbose clean archive
    xcodebuild -workspace Indy.xcworkspace -scheme Indy -configuration Release -arch arm64 -arch armv7 only_active_arch=no defines_module=yes -sdk "iphoneos" -derivedDataPath "build/iphoneos" clean build > build/iphoneos/build.log
else
    echo "Skipping build for iOS devices (reusing from previous run)"
fi

mkdir -p build/iphonesimulator
if [ ! -d "${FRAMEWORK_SIMULATOR_PATH}" ]; then
    echo "Building for iOS simulators"
    #xcodebuild -workspace Indy.xcworkspace -scheme Indy -configuration Release -sdk iphonesimulator -archivePath Indy-Simulator.xcarchive -verbose clean archive
    xcodebuild -workspace Indy.xcworkspace -scheme Indy -configuration Release -arch x86_64 -arch i386 only_active_arch=no defines_module=yes -sdk "iphonesimulator" -derivedDataPath "build/iphonesimulator" clean build > build/iphonesimulator/build.log
else
    echo "Skipping build for iOS simulators (reusing from previous run)"
fi




FRAMEWORK_UNIVERSAL_PATH='build/universal/Indy.framework'

FRAMEWORK_NAME="Indy"
if [ -d "${FRAMEWORK_UNIVERSAL_PATH}" ]; then
    rm -rf "${FRAMEWORK_UNIVERSAL_PATH}"
fi
mkdir -p "${FRAMEWORK_UNIVERSAL_PATH}"

#Copy the device version of framework.
cp -r "${FRAMEWORK_DEVICE_PATH}/" "${FRAMEWORK_UNIVERSAL_PATH}"

## Merging the device and simulator frameworks' executables with lipo.
lipo -create -output "${FRAMEWORK_UNIVERSAL_PATH}/${FRAMEWORK_NAME}" "${FRAMEWORK_DEVICE_PATH}/${FRAMEWORK_NAME}" "${FRAMEWORK_SIMULATOR_PATH}/${FRAMEWORK_NAME}"
file "${FRAMEWORK_UNIVERSAL_PATH}/${FRAMEWORK_NAME}"

# Copy Swift module mappings for simulator into the framework. 
cp -r "${FRAMEWORK_SIMULATOR_PATH}/Modules/${FRAMEWORK_NAME}.swiftmodule/" "${FRAMEWORK_UNIVERSAL_PATH}/Modules/${FRAMEWORK_NAME}.swiftmodule"

# Merge Swift header
COMBINED_SWIFT_HEADER_FILE="${FRAMEWORK_UNIVERSAL_PATH}/Headers/${FRAMEWORK_NAME}-Swift.h"

touch "${COMBINED_SWIFT_HEADER_FILE}"
echo "#ifndef TARGET_OS_SIMULATOR" > "${COMBINED_SWIFT_HEADER_FILE}"
echo "#include <TargetConditionals.h>" >> "${COMBINED_SWIFT_HEADER_FILE}"
echo "#endif" >> "${COMBINED_SWIFT_HEADER_FILE}"
echo "#if TARGET_OS_SIMULATOR" >> "${COMBINED_SWIFT_HEADER_FILE}"
cat "${FRAMEWORK_SIMULATOR_PATH}/Headers/${FRAMEWORK_NAME}-Swift.h" >> "${COMBINED_SWIFT_HEADER_FILE}"
echo "#else" >> "${COMBINED_SWIFT_HEADER_FILE}"
echo "//Start of iphoneos" >> "${COMBINED_SWIFT_HEADER_FILE}"
cat "${FRAMEWORK_DEVICE_PATH}/Headers/${FRAMEWORK_NAME}-Swift.h" >> "${COMBINED_SWIFT_HEADER_FILE}"
echo "#endif" >> "${COMBINED_SWIFT_HEADER_FILE}"



# xcrun xcodebuild -create-xcframework -framework /path/to/ios.framework -framework /path/to/sim.framework -output combined.xcframework

mkdir -p "${BUILD_DIR}/cocoapods/build/Frameworks"

pushd "${BUILD_DIR}/cocoapods/build/Frameworks/"
ln -sf '../../../iphonesimulator/Build/Products/Release-iphonesimulator/Indy.framework'
#zip -r "${BUILD_DIR}/libindy-objc.zip" "Indy.framework"
#tar -cvzf "${BUILD_DIR}/libindy-objc.tar.gz" "Indy.framework"
popd # dirname "${FRAMEWORK_SIMULATOR_PATH}"
pushd "${BUILD_DIR}/cocoapods"
zip -r libindy-objc.zip "build"
popd

#rm -rf "${HOME}/Documents/GitHub/bc-wallet-mobile/app/ios/Pods/Frameworks/Indy.framework"
#mkdir -p "${HOME}/Documents/GitHub/bc-wallet-mobile/app/ios/Pods/Frameworks"
#cp -r "${FRAMEWORK_SIMULATOR_PATH}" "${HOME}/Documents/GitHub/bc-wallet-mobile/app/ios/Pods/Frameworks/"


popd # wrappers/ios/libindy-pod
popd # <root>
