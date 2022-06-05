#!/bin/bash -e
# reference - https://github.com/oleganza/CoreBitcoin/blob/master/build_libraries.sh
# https://bignerdranch.com/blog/building-an-ios-app-in-rust-part-1-getting-started-with-rust/
# https://medium.com/@priya_talreja/create-custom-universal-framework-in-ios-aef7fa6fd51e
# https://stackoverflow.com/a/65315026
# https://github.com/bielikb/xcframeworks
# https://gist.github.com/surpher/bbf88e191e9d1f01ab2e2bbb85f9b528#file-rust_to_swift-md



# -- Library: Indy.xcframework/ios-x86_64-simulator/Indy.framework/Indy
# Non-fat file: Indy.xcframework/ios-x86_64-simulator/Indy.framework/Indy is architecture: x86_64
# -- Library: Indy.xcframework/ios-arm64_armv7/Indy.framework/Indy
# Architectures in the fat file: Indy.xcframework/ios-arm64_armv7/Indy.framework/Indy are: armv7 arm64 

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
POSITIONAL_ARGS=()
#1.55.0
export RUST_VER=1.60.0
#export RUST_VER=1.41.0
target_simulators='x86_64-apple-ios,aarch64-apple-ios-sim'
target_devices="aarch64-apple-ios" #,armv7-apple-ios"
if [ "$RUST_VER" == "1.41.0" ]; then # for old compiler
  target_simulators='x86_64-apple-ios'
  target_simulators="x86_64-apple-ios,armv7s-apple-ios" #,i386-apple-ios"
fi
_targets="${target_devices},${target_simulators}"

# TODO: What ro do with aarch64-apple-ios-sim?

# Simulators: aarch64-apple-ios-sim, x86_64-apple-ios
# Devices: aarch64-apple-ios

while [[ $# -gt 0 ]]; do
  case $1 in
    --targets)
      _targets="$2"
      shift # past argument
      shift # past value
      ;;
    --component)
      if [ "$2" == "core" ]; then
        BUILD_CORE="true"
      elif [ "$2" == "framework" ]; then
        BUILD_FRAMEWORK="true"
      fi
      shift # past argument
      shift # past value
      ;;
    --clean)
      OPT_CLEAN="true"
      shift # past argument
      ;;
    --all)
      BUILD_CORE="true"
      BUILD_FRAMEWORK="true"
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

#echo $OPTS
#exit 
export OPENSSL_DIR=$(brew --prefix openssl@1.1)
export PKG_CONFIG_ALLOW_CROSS=1

# change the current directory to the root of the repository
pushd "${SCRIPT_DIR}/../" > /dev/null
  if [ "$BUILD_CORE" == "true" ]; then
    echo "Using RUST ${RUST_VER}"
    rustup default "${RUST_VER}"
    if [ "$OPT_CLEAN" == "true" ]; then
      echo "Cleaning previous build"
      rm -rf libindy/target
      rm -rf libindy/out_pod
    fi
    pushd "libindy"
      if [ "$RUST_VER" == "1.41.0.x" ]; then # for old compiler
        lib_out_file="target/universal/release/libindy.a"
        if [ ! -f "${lib_out_file}" ]; then
          for target in ${_targets//,/ }; do
            rustup target add "${target}"
          done
          cargo lipo --release --targets ${_targets};
        else
          echo "Skipping build of libindy [${_targets}] (reusing from cache libindy/${lib_out_file})"
        fi
      else
        echo "Build for the following platforms: ${_targets}"
        for target in ${_targets//,/ }; do
          lib_out_file="target/${target}/release/libindy.a"
          if [ ! -f "${lib_out_file}" ]; then
            echo "Building for ${target}"
            mkdir -p "target"
            if [ "$target" == "armv7-apple-ios.x" ]; then
              OPENSSL_DIR=$(brew --prefix openssl@1.1) PKG_CONFIG_ALLOW_CROSS=1 cargo +nightly build -Z unstable-options -Z build-std --release  --target "${target}"
            elif [ "$target" == "armv7-apple-ios" ]; then
              OPENSSL_DIR=$(brew --prefix openssl@1.1) PKG_CONFIG_ALLOW_CROSS=1 cargo build -Z build-std --release  --target "${target}" &> "target/${target}.build.log"
            else
              rustup target add "${target}"
              OPENSSL_DIR=$(brew --prefix openssl@1.1) PKG_CONFIG_ALLOW_CROSS=1 cargo build --release  --target "${target}" &> "target/${target}.build.log"
            fi
            echo "Build for ${target} is complete"
          else
            echo "Skipping build of libindy [${target}] (reusing from cache libindy/${lib_out_file})"
          fi
        done
        ## devices
        lipo_device_args=""
        for target in ${target_devices//,/ }; do 
          lipo_device_args="$lipo_device_args target/${target}/release/libindy.a"
        done
        #set -x


        ## simulators
        lipo_simulator_args=""
        for target in ${target_simulators//,/ }; do 
          lipo_simulator_args="$lipo_simulator_args target/${target}/release/libindy.a"
        done

        set -x
        mkdir -p target/ios-sim/release
        xcrun lipo -create -output "target/ios-sim/release/libindy-simulator.a" $lipo_simulator_args

        mkdir -p target/ios-device/release
        xcrun lipo -create -output "target/ios-device/release/libindy-device.a" $lipo_device_args

        xcrun lipo -info "target/ios-device/release/libindy.a"
        xcrun lipo -info "target/ios-sim/release/libindy.a"
        rm -rf  "target/Indy.xcframework"
        rm -rf  "target/Indy-device.xcframework"
        rm -rf  "target/Indy-sim.xcframework"
        echo ""
        #xcodebuild -create-xcframework -library "target/aarch64-apple-ios/release/libindy.a" -headers  ./include/  -output "target/Indy-device.xcframework"
        #echo ""
        #xcodebuild -create-xcframework -library "target/x86_64-apple-ios/release/libindy.a" -headers ./include/ -library "target/aarch64-apple-ios-sim/release/libindy.a" -headers ./include/  -output "target/Indy-sim.xcframework"
        xcrun xcodebuild -create-xcframework -library "target/ios-device/release/libindy-device.a" -headers ./include/ -library "target/ios-sim/release/libindy-simulator.a"  -headers ./include/ -output "libindy/target/Indy.xcframework"

      fi 
      echo "done" && exit
      rm -rf out_pod
      mkdir -p out_pod
      cp include/*.h out_pod
      cp ../LICENSE out_pod
      cp target/universal/release/libindy.a out_pod
      pushd out_pod > /dev/null
        tar -czf "libindy.tar.gz" *
      popd > /dev/null # out_pod
    popd > /dev/null # libindy
  fi

  file "libindy/target/universal/release/libindy.a"

  if [ "$BUILD_FRAMEWORK" == "true" ]; then
    pushd wrappers/ios/libindy-pod > /dev/null
      #if [ "$OPT_CLEAN" == "true" ] || [ ! -d Pods/Pods.xcodeproj ]; then
          if [ -d Pods/Pods.xcodeproj ]; then
            pod deintegrate Indy.xcodeproj
          fi
          pod cache clean libindy
          pod install
          file "Pods/libindy/libindy.a"
      #else
      #    echo "Skipping 'pod install' (reusing from previous run)"
      #fi

      BUILD_DIR="$(pwd)/build"
      FRAMEWORK_DEVICE_PATH='build/iphoneos/Build/Products/Release-iphoneos/Indy.framework'
      FRAMEWORK_SIMULATOR_PATH='build/iphonesimulator/Build/Products/Release-iphonesimulator/Indy.framework'

      if [ "$OPT_CLEAN" == "true" ]; then
        rm -rf "build"
      fi

      mkdir -p build/iphoneos
      declare -a xcodebuild_args
      xcodebuild_args=(-workspace Indy.xcworkspace -scheme Indy -configuration Release SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES only_active_arch=no defines_module=yes)
      if [ ! -d "${FRAMEWORK_DEVICE_PATH}" ]; then
        echo "Building for iOS devices"
        declare -a xcodebuild_args_device
        xcodebuild_args_device=(-destination "generic/platform=iOS") # works
        echo "EXCLUDED_ARCHS=armv7" >> build/iphoneos/config.xcconfig
        xcodebuild "${xcodebuild_args[@]}" "${xcodebuild_args_device[@]}" -derivedDataPath "build/iphoneos" -xcconfig build/iphoneos/config.xcconfig -showBuildSettings build > build/iphoneos/build-config.log
        xcodebuild "${xcodebuild_args[@]}" "${xcodebuild_args_device[@]}" -derivedDataPath "build/iphoneos" -xcconfig build/iphoneos/config.xcconfig clean build > build/iphoneos/build.log
      else
        echo "Skipping build for iOS devices (reusing from previous run)"
      fi

      mkdir -p build/iphonesimulator
      if [ ! -d "${FRAMEWORK_SIMULATOR_PATH}" ]; then
        echo "Building for iOS simulators"
        declare -a xcodebuild_args_simulator
        xcodebuild_args_simulator=(-destination 'generic/platform=iOS Simulator')
        #xcodebuild_args_simulator=(-sdk iphonesimulator  -arch x86_64 -arch i386 -arch armv7) # works
        echo "" > build/iphonesimulator/config.xcconfig
        if [ "$RUST_VER" == "1.41.0" ]; then
          echo "EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64 i386" >> build/iphonesimulator/config.xcconfig
        else
          echo "EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64 i386" >> build/iphonesimulator/config.xcconfig
        fi
        #echo "EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386" >> build/iphonesimulator/config.xcconfig
        xcodebuild "${xcodebuild_args[@]}" "${xcodebuild_args_simulator[@]}" -derivedDataPath "build/iphonesimulator" -xcconfig build/iphonesimulator/config.xcconfig -showBuildSettings build  > build/iphonesimulator/build-config.log
        xcodebuild "${xcodebuild_args[@]}" "${xcodebuild_args_simulator[@]}" -derivedDataPath "build/iphonesimulator" -xcconfig build/iphonesimulator/config.xcconfig  clean build  > build/iphonesimulator/build.log
      else
        echo "Skipping build for iOS simulators (reusing from previous run)"
      fi
      FRAMEWORK_NAME="Indy"
      
      XCFRAMEWORK_UNIVERSAL_PATH='build/universal/Indy.xcframework'
      
      [ -d "${XCFRAMEWORK_UNIVERSAL_PATH}" ] && rm -rf "${XCFRAMEWORK_UNIVERSAL_PATH}"
      rm -rf "${XCFRAMEWORK_UNIVERSAL_PATH}"
      xcrun xcodebuild -create-xcframework -framework "${FRAMEWORK_DEVICE_PATH}" -framework "${FRAMEWORK_SIMULATOR_PATH}" -output "${XCFRAMEWORK_UNIVERSAL_PATH}"

      # FRAMEWORK_UNIVERSAL_PATH='build/universal/Indy.framework'
      # [ -d "${FRAMEWORK_UNIVERSAL_PATH}" ] && rm -rf "${FRAMEWORK_UNIVERSAL_PATH}"
      # mkdir -p "${FRAMEWORK_UNIVERSAL_PATH}"
      # #Copy the device version of framework.
      # cp -r "${FRAMEWORK_DEVICE_PATH}/" "${FRAMEWORK_UNIVERSAL_PATH}"

      # ## Merging the device and simulator frameworks' executables with lipo.
      # lipo -create -output "${FRAMEWORK_UNIVERSAL_PATH}/${FRAMEWORK_NAME}" "${FRAMEWORK_DEVICE_PATH}/${FRAMEWORK_NAME}" "${FRAMEWORK_SIMULATOR_PATH}/${FRAMEWORK_NAME}"
      # file "${FRAMEWORK_UNIVERSAL_PATH}/${FRAMEWORK_NAME}"

      # # Copy Swift module mappings for simulator into the framework. 
      # cp -r "${FRAMEWORK_SIMULATOR_PATH}/Modules/${FRAMEWORK_NAME}.swiftmodule/" "${FRAMEWORK_UNIVERSAL_PATH}/Modules/${FRAMEWORK_NAME}.swiftmodule"

      # # Merge Swift header
      # COMBINED_SWIFT_HEADER_FILE="${FRAMEWORK_UNIVERSAL_PATH}/Headers/${FRAMEWORK_NAME}-Swift.h"

      # touch "${COMBINED_SWIFT_HEADER_FILE}"
      # echo "#ifndef TARGET_OS_SIMULATOR" > "${COMBINED_SWIFT_HEADER_FILE}"
      # echo "#include <TargetConditionals.h>" >> "${COMBINED_SWIFT_HEADER_FILE}"
      # echo "#endif" >> "${COMBINED_SWIFT_HEADER_FILE}"
      # echo "#if TARGET_OS_SIMULATOR" >> "${COMBINED_SWIFT_HEADER_FILE}"
      # cat "${FRAMEWORK_SIMULATOR_PATH}/Headers/${FRAMEWORK_NAME}-Swift.h" >> "${COMBINED_SWIFT_HEADER_FILE}"
      # echo "#else" >> "${COMBINED_SWIFT_HEADER_FILE}"
      # echo "//Start of iphoneos" >> "${COMBINED_SWIFT_HEADER_FILE}"
      # cat "${FRAMEWORK_DEVICE_PATH}/Headers/${FRAMEWORK_NAME}-Swift.h" >> "${COMBINED_SWIFT_HEADER_FILE}"
      # echo "#endif" >> "${COMBINED_SWIFT_HEADER_FILE}"

      rm -rf "${BUILD_DIR}/cocoapods"
      mkdir -p "${BUILD_DIR}/cocoapods/build/Frameworks"

      pushd "${BUILD_DIR}/cocoapods/build/Frameworks/" > /dev/null
        #ln -sf '../../../iphonesimulator/Build/Products/Release-iphonesimulator/Indy.framework'
        ln -sf '../../../universal/Indy.xcframework'
        #zip -r "${BUILD_DIR}/libindy-objc.zip" "Indy.framework"
        #tar -cvzf "${BUILD_DIR}/libindy-objc.tar.gz" "Indy.framework"
        while IFS='' read -r -d '' filename; do
          echo "-- Library: ${filename}"
          #file "${filename}"
          lipo -info "${filename}"
        done < <(find -L Indy.xcframework -type f -name 'Indy' -print0)
      popd > /dev/null # dirname "${FRAMEWORK_SIMULATOR_PATH}"
      pushd "${BUILD_DIR}/cocoapods" > /dev/null
        echo "Creating libindy-objc.zip"
        zip -qr libindy-objc.zip "build"
      popd > /dev/null

      #rm -rf "${HOME}/Documents/GitHub/bc-wallet-mobile/app/ios/Pods/Frameworks/Indy.framework"
      #mkdir -p "${HOME}/Documents/GitHub/bc-wallet-mobile/app/ios/Pods/Frameworks"
      #cp -r "${FRAMEWORK_SIMULATOR_PATH}" "${HOME}/Documents/GitHub/bc-wallet-mobile/app/ios/Pods/Frameworks/"
    popd > /dev/null # wrappers/ios/libindy-pod
  fi
  pushd "../bc-wallet-mobile/app" > /dev/null
    pushd "ios" > /dev/null
    if [ -d Pods/Pods.xcodeproj ]; then
      pod deintegrate BCWallet.xcodeproj
    fi
    pod cache clean libindy
    pod cache clean libindy-objc
    pod install
    popd > /dev/null #bc-wallet-mobile/app/ios
    mkdir -p build
    npm run ios -- --simulator "iPhone 13" > build/build-ios.log
  popd > /dev/null #bc-wallet-mobile/app
popd > /dev/null # <root>
