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

#echo $OPTS
#exit 
export OPENSSL_DIR=$(brew --prefix openssl@1.1)
export PKG_CONFIG_ALLOW_CROSS=1


# change the current directory to the root of the repository
pushd "${SCRIPT_DIR}/../" > /dev/null
  echo "Using RUST ${RUST_VER}"
  rustup default "${RUST_VER}"
  if [ "$OPT_CLEAN" == "true" ]; then
    echo "Cleaning previous build"
    rm -rf libindy/target
    rm -rf libindy/out_pod
  fi
  pushd "libindy"
    echo "Build for the following architecture(s): ${_targets}"
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
  popd > /dev/null # libindy
popd > /dev/null # <root>
