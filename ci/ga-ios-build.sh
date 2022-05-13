#!/bin/sh

set -e
set -x

if [ "$1" = "--help" ] ; then
  echo "Usage: <package> <targets>"
  return
fi

package="$1"

[ -z ${package} ] && exit 1

if [ -z "${LIBINDY_POD_VERSION}" ]; then
    echo "ERROR: LIBINDY_POD_VERSION environment variable must be specified"
fi

if [ -z "${RUST_VER}" ]; then
    export RUST_VER=1.58.0
    echo "ERROR: RUST_VER environment variable not specified, using $RUST_VER"
fi

if [ -z "${OPENSSL_DIR}" ]; then
    export OPENSSL_DIR=$(brew --prefix openssl@1.1)
    echo "OPENSSL_DIR not specified, using $OPENSSL_DIR"
fi

export PKG_CONFIG_ALLOW_CROSS=1
export CARGO_INCREMENTAL=1
export POD_FILE_NAME=${package}.tar.gz

rustup default ${RUST_VER}

targets="$2"
for target in ${targets//,/ }
do 
  rustup target add "${target}"
done
cargo install cargo-lipo

brew list libsodium &>/dev/null || brew install libsodium
brew list zeromq &>/dev/null || brew install zeromq
brew list openssl@1.1 &>/dev/null || brew install openssl@1.1

echo "Build IOS POD started..."

TYPE="debug"

cd ${package}

if [[ $# -eq 2 ]]; then # build for single platform
  echo "... for target(s) $2 ..."
  cargo lipo --targets $2
else  # build for all platforms
  echo "... for all default targets ..."
  TYPE="release"
  cargo lipo --$TYPE
fi
echo 'Build completed successfully.'

WORK_DIR="out_pod"
rm -rf $WORK_DIR
echo "Try to create out directory: $WORK_DIR"
mkdir $WORK_DIR

if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temp dir $WORK_DIR"
  exit 1
fi

echo "Packing..."

PACKAGE="${package}.a"

cp include/*.h $WORK_DIR
cp ../LICENSE $WORK_DIR
cp target/universal/$TYPE/$PACKAGE $WORK_DIR
cd $WORK_DIR
tar -cvzf $POD_FILE_NAME *
cd -
ls -l $WORK_DIR/$POD_FILE_NAME

echo "Packing completed."

echo "Out directory: $WORK_DIR"
