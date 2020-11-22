#!/usr/bin/env bash

set -e
# set -x

BASE_PWD="$PWD"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
FWNAME="OpenSSL"
OUTPUT_DIR=$( mktemp -d )
COMMON_SETUP="-project ${SCRIPT_DIR}/../${FWNAME}.xcodeproj -configuration Release -quiet SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES"

# macOS
DERIVED_DATA_PATH=$( mktemp -d )
xcrun xcodebuild build \
	$COMMON_SETUP \
    -scheme "${FWNAME} (macOS)" \
	-derivedDataPath "${DERIVED_DATA_PATH}" \
	-destination 'generic/platform=macOS'

mkdir -p "${OUTPUT_DIR}/macos"
rm -rf "${OUTPUT_DIR}/macos/${FWNAME}.framework"
ditto "${DERIVED_DATA_PATH}/Build/Products/Release/${FWNAME}.framework" "${OUTPUT_DIR}/macos/${FWNAME}.framework"
rm -rf "${DERIVED_DATA_PATH}"

# iOS
DERIVED_DATA_PATH=$( mktemp -d )
xcrun xcodebuild build \
	$COMMON_SETUP \
    -scheme "${FWNAME} (iOS)" \
	-derivedDataPath "${DERIVED_DATA_PATH}" \
	-destination 'generic/platform=iOS'

rm -rf "${OUTPUT_DIR}/iphoneos"
mkdir -p "${OUTPUT_DIR}/iphoneos"
ditto "${DERIVED_DATA_PATH}/Build/Products/Release-iphoneos/${FWNAME}.framework" "${OUTPUT_DIR}/iphoneos/${FWNAME}.framework"
rm -rf "${DERIVED_DATA_PATH}"

# iOS Simulator
DERIVED_DATA_PATH=$( mktemp -d )
xcrun xcodebuild build \
	$COMMON_SETUP \
    -scheme "${FWNAME} (iOS Simulator)" \
	-derivedDataPath "${DERIVED_DATA_PATH}" \
	-destination 'generic/platform=iOS Simulator'

rm -rf "${OUTPUT_DIR}/iphonesimulator"
mkdir -p "${OUTPUT_DIR}/iphonesimulator"
ditto "${DERIVED_DATA_PATH}/Build/Products/Release-iphonesimulator/${FWNAME}.framework" "${OUTPUT_DIR}/iphonesimulator/${FWNAME}.framework"
rm -rf "${DERIVED_DATA_PATH}"

rm -rf "${BASE_PWD}/Frameworks/iphoneos"
mkdir -p "${BASE_PWD}/Frameworks/iphoneos"
ditto "${OUTPUT_DIR}/iphoneos/${FWNAME}.framework" "${BASE_PWD}/Frameworks/iphoneos/${FWNAME}.framework"

rm -rf "${BASE_PWD}/Frameworks/iphonesimulator"
mkdir -p "${BASE_PWD}/Frameworks/iphonesimulator"
ditto "${OUTPUT_DIR}/iphonesimulator/${FWNAME}.framework" "${BASE_PWD}/Frameworks/iphonesimulator/${FWNAME}.framework"

rm -rf "${BASE_PWD}/Frameworks/macos"
mkdir -p "${BASE_PWD}/Frameworks/macos"
ditto "${OUTPUT_DIR}/macos/${FWNAME}.framework" "${BASE_PWD}/Frameworks/macos/${FWNAME}.framework"

# XCFramework
rm -rf "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

xcrun xcodebuild -quiet -create-xcframework \
	-framework "${OUTPUT_DIR}/iphoneos/${FWNAME}.framework" \
	-framework "${OUTPUT_DIR}/iphonesimulator/${FWNAME}.framework" \
	-framework "${OUTPUT_DIR}/macos/${FWNAME}.framework" \
	-output "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

rm -rf ${OUTPUT_DIR}