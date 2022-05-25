#!/bin/bash

echo "Building Dash Shared library..."

pushd "libindy"

rm -r IndySdk/framework
rm -r IndySdk/lib/ios
rm -r IndySdk/lib/ios-simulator

rustup target add x86_64-apple-ios
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim

export OPENSSL_DIR=$(brew --prefix openssl@1.1)
export PKG_CONFIG_ALLOW_CROSS=1
#cargo lipo --release
#cargo build --target=x86_64-apple-ios --release
#cargo build --target=aarch64-apple-ios --release
#cargo build --target=aarch64-apple-ios-sim --release

rm -rf IndySdk
mkdir -p IndySdk/framework
mkdir -p IndySdk/lib/ios
mkdir -p IndySdk/lib/ios-simulator

cp -r -p target/x86_64-apple-ios/release/libindy.a IndySdk/lib/ios-simulator/libindy_ios_x86_64.a
cp -r -p target/aarch64-apple-ios/release/libindy.a IndySdk/lib/ios/libindy_ios.a
cp -r -p target/aarch64-apple-ios-sim/release/libindy.a IndySdk/lib/ios-simulator/libindy_ios_arm.a

lipo -create IndySdk/lib/ios-simulator/libindy_ios_arm.a IndySdk/lib/ios-simulator/libindy_ios_x86_64.a -output IndySdk/lib/ios-simulator/libindy_ios.a
lipo -info IndySdk/lib/ios/libindy_ios.a
lipo -detailed_info IndySdk/lib/ios-simulator/libindy_ios.a

xcodebuild -create-xcframework \
	-library IndySdk/lib/ios/libindy_ios.a -headers ./include \
	-library IndySdk/lib/ios-simulator/libindy_ios.a -headers ./include \
	-output IndySdk/framework/Indy.xcframework

popd
echo "Done building for ios"
