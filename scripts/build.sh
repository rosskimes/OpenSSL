#!/usr/bin/env bash

# Yay shell scripting! This script builds a static version of
# OpenSSL for iOS and OSX that contains code for armv6, armv7, armv7s, arm64, x86_64.

set -e
# set -x

BASE_PWD="$PWD"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Setup paths to stuff we need

OPENSSL_VERSION="1.1.1i"
export OPENSSL_LOCAL_CONFIG_DIR="${SCRIPT_DIR}/../config"

DEVELOPER=$(xcode-select --print-path)

export IPHONEOS_DEPLOYMENT_VERSION="7.0"
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
APPLETVOS_SDK=$(xcrun --sdk appletvos --show-sdk-path)
APPLETVSIMULATOR_SDK=$(xcrun --sdk appletvsimulator --show-sdk-path)
OSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
export TVOS_MIN_SDK_VERSION="9.0"

export MACOSX_DEPLOYMENT_TARGET="10.10" # 

# Turn versions like 1.2.3 into numbers that can be compare by bash.
version()
{
   printf "%03d%03d%03d%03d" $(tr '.' ' ' <<<"$1");
}

configure() {
   local OS=$1
   local ARCH=$2
   local BUILD_DIR=$3
   local SRC_DIR=$4

   echo "Configuring for ${OS} ${ARCH}"

   local SDK=
   case "$OS" in
      iPhoneOS)
	 SDK="${IPHONEOS_SDK}"
	 ;;
      iPhoneSimulator)
	 SDK="${IPHONESIMULATOR_SDK}"
	 ;;
	 AppleTVOS)
	 SDK="${APPLETVOS_SDK}"
	 ;;
	 AppleTVSimulator)
	 SDK="${APPLETVSIMULATOR_SDK}"
	 ;;
      MacOSX)
	 SDK="${OSX_SDK}"
	 ;;
      MacOSX_Catalyst)
	 SDK="${OSX_SDK}"
	 ;;
      *)
	 echo "Unsupported OS '${OS}'!" >&1
	 exit 1
	 ;;
   esac

   local PREFIX="${BUILD_DIR}/${OPENSSL_VERSION}-${OS}-${ARCH}"

   export CROSS_TOP="${SDK%%/SDKs/*}"
   export CROSS_SDK="${SDK##*/SDKs/}"
   if [ -z "$CROSS_TOP" -o -z "$CROSS_SDK" ]; then
      echo "Failed to parse SDK path '${SDK}'!" >&1
      exit 2
   fi
   

   if [ "$OS" == "MacOSX" ]; then
      ${SRC_DIR}/Configure macos-$ARCH no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log"
   elif [ "$OS" == "MacOSX_Catalyst" ]; then
      ${SRC_DIR}/Configure mac-catalyst-$ARCH no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log"
   elif [ "$OS" == "iPhoneSimulator" ]; then
      ${SRC_DIR}/Configure ios-sim-cross-$ARCH no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log"
   elif [ "$OS" == "iPhoneOS" ]; then
      ${SRC_DIR}/Configure ios-cross-$ARCH no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log"
   elif [ "$OS" == "AppleTVSimulator" ]; then
	TARGET="darwin64-${ARCH}-cc"
        RUNTARGET="-target ${ARCH}-apple-tvos${TVOS_MIN_SDK_VERSION}-simulator"
	export SYSROOT=$(xcrun --sdk appletvsimulator --show-sdk-path)
        export BUILD_TOOLS="${DEVELOPER}"
        export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH}"
        export LC_CTYPE=C


        export CFLAGS=" -Os -fembed-bitcode -arch ${ARCH} ${RUNTARGET} "
        export LDFLAGS=" -arch ${ARCH} -isysroot ${SYSROOT}"
        export CPPFLAGS=" -I.. -isysroot ${SYSROOT}"
        export CXX="${BUILD_TOOLS}/usr/bin/gcc"

      #${SRC_DIR}/Configure tvos-sim-cross-$ARCH no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log"
      # Patch apps/speed.c to not use fork() since it's not available on tvOS
      	LANG=C sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "${SRC_DIR}/apps/speed.c"
	LANG=C sed -i -- 's/!defined(OPENSSL_NO_POSIX_IO)/defined(HAVE_FORK)/' "${SRC_DIR}/apps/ocsp.c"
	LANG=C sed -i -- 's/fork()/-1/' "${SRC_DIR}/apps/ocsp.c"
	LANG=C sed -i -- 's/fork()/-1/' "${SRC_DIR}/test/drbgtest.c"
	LANG=C sed -i -- 's/!defined(OPENSSL_NO_ASYNC)/defined(HAVE_FORK)/' "${SRC_DIR}/crypto/async/arch/async_posix.h"
      echo -e "${SRC_DIR}/Configure ${TARGET} no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log""
      ${SRC_DIR}/Configure ${TARGET} no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log"
	sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mtvos-version-min=${TVOS_MIN_SDK_VERSION} !" "Makefile"
	cp Makefile ~/Makefile.ross
	# Clean up exports
        export CC=""
        export CXX=""
        export CFLAGS=""
        export LDFLAGS=""
        export CPPFLAGS=""

   elif [ "$OS" == "AppleTVOS" ]; then
      # Patch apps/speed.c to not use fork() since it's not available on tvOS
      	LANG=C sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "${SRC_DIR}/apps/speed.c"
	LANG=C sed -i -- 's/!defined(OPENSSL_NO_POSIX_IO)/defined(HAVE_FORK)/' "${SRC_DIR}/apps/ocsp.c"
	LANG=C sed -i -- 's/fork()/-1/' "${SRC_DIR}/apps/ocsp.c"
	LANG=C sed -i -- 's/fork()/-1/' "${SRC_DIR}/test/drbgtest.c"
	LANG=C sed -i -- 's/!defined(OPENSSL_NO_ASYNC)/defined(HAVE_FORK)/' "${SRC_DIR}/crypto/async/arch/async_posix.h"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH}"
      ${SRC_DIR}/Configure iphoneos-cross no-asm no-shared --prefix="${PREFIX}" &> "${PREFIX}.config.log"
	sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mtvos-version-min=${TVOS_MIN_SDK_VERSION} !" "Makefile"
	# Clean up exports
        export CC=""
        export CXX=""
        export CFLAGS=""
        export LDFLAGS=""
        export CPPFLAGS=""

   fi
}

build()
{
   local ARCH=$1
   local OS=$2
   local BUILD_DIR=$3
   local TYPE=$4 # iphoneos/iphonesimulator/macosx/macosx_catalyst

   local SRC_DIR="${BUILD_DIR}/openssl-${OPENSSL_VERSION}-${TYPE}"
   local PREFIX="${BUILD_DIR}/${OPENSSL_VERSION}-${OS}-${ARCH}"

   mkdir -p "${SRC_DIR}"
   tar xzf "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz" -C "${SRC_DIR}" --strip-components=1

   echo "Building for ${OS} ${ARCH}"

   # Change dir
   cd "${SRC_DIR}"

   # fix headers for Swift

   sed -ie "s/BIGNUM \*I,/BIGNUM \*i,/g" ${SRC_DIR}/crypto/rsa/rsa_local.h   

   # -bundle and -bitcode_bundle (Xcode setting ENABLE_BITCODE=YES) cannot be used together 
   # sed -ie "s/'-bundle'/''/g" ${SRC_DIR}/Configurations/shared-info.pl

   configure "${OS}" $ARCH ${BUILD_DIR} ${SRC_DIR}

   LOG_PATH="${PREFIX}.build.log"
   echo "Building ${LOG_PATH}"
   make &> ${LOG_PATH}
   make install &> ${LOG_PATH}
   cd ${BASE_PWD}

   # Add arch to library
   if [ -f "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a" ]; then
      xcrun lipo "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a" "${PREFIX}/lib/libcrypto.a" -create -output "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a"
      xcrun lipo "${SCRIPT_DIR}/../${TYPE}/lib/libssl.a" "${PREFIX}/lib/libssl.a" -create -output "${SCRIPT_DIR}/../${TYPE}/lib/libssl.a"
   else
      cp "${PREFIX}/lib/libcrypto.a" "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a"
      cp "${PREFIX}/lib/libssl.a" "${SCRIPT_DIR}/../${TYPE}/lib/libssl.a"
   fi

   rm -rf "${SRC_DIR}"
}

build_ios() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}

   build "i386" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"
   build "x86_64" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"
   build "arm64" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"
   build "arm64e" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"

   rm -rf "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}

   build "armv7" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"
   build "armv7s" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"
   build "arm64" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"
   build "arm64e" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"

   # Copy headers
   ditto "${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneOS-arm64e/include/openssl" "${SCRIPT_DIR}/../iphoneos/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../iphoneos/include/openssl/shim.h"

   # Copy headers
   ditto "${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-arm64e/include/openssl" "${SCRIPT_DIR}/../iphonesimulator/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../iphonesimulator/include/openssl/shim.h"

   # fix inttypes.h
   find "${SCRIPT_DIR}/../iphoneos/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;
   find "${SCRIPT_DIR}/../iphonesimulator/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;

   # fix RC4_INT redefinition
   # find "${SCRIPT_DIR}/../iphoneos/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/\#define RC4_INT unsigned char/\#if \!defined(RC4_INT)\n#define RC4_INT unsigned char\n\#endif\n/g" {} \;
   # find "${SCRIPT_DIR}/../iphonesimulator/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/\#define RC4_INT unsigned char/\#if \!defined(RC4_INT)\n#define RC4_INT unsigned char\n\#endif\n/g" {} \;

   local OPENSSLCONF_PATH="${SCRIPT_DIR}/../iphonesimulator/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__i386__)" > ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-i386/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__x86_64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-x86_64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7A__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7S__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64e__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-arm64e/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   OPENSSLCONF_PATH="${SCRIPT_DIR}/../iphoneos/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__i386__)" > ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__x86_64__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7A__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneOS-armv7/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7S__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneOS-armv7s/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64e__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneOS-arm64e/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneOS-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   rm -rf ${TMP_BUILD_DIR}
}

build_tvos() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{appletvsimulator/include,appletvsimulator/lib}
   mkdir -p "${SCRIPT_DIR}"/../{appletvsimulator/include,appletvsimulator/lib}

   build "x86_64" "AppleTVSimulator" ${TMP_BUILD_DIR} "appletvsimulator"
   build "arm64" "AppleTVSimulator" ${TMP_BUILD_DIR} "appletvsimulator"
   #build "arm64e" "AppleTVSimulator" ${TMP_BUILD_DIR} "appletvsimulator"

   rm -rf "${SCRIPT_DIR}"/../{appletvos/include,appletvos/lib}
   mkdir -p "${SCRIPT_DIR}"/../{appletvos/include,appletvos/lib}

   build "arm64" "AppleTVOS" ${TMP_BUILD_DIR} "appletvos"
   # Copy headers
   ditto "${TMP_BUILD_DIR}/${OPENSSL_VERSION}-AppleTVOS-arm64/include/openssl" "${SCRIPT_DIR}/../appletvos/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../appletvos/include/openssl/shim.h"

   # Copy headers
   ditto "${TMP_BUILD_DIR}/${OPENSSL_VERSION}-AppleTVSimulator-arm64/include/openssl" "${SCRIPT_DIR}/../appletvsimulator/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../appletvsimulator/include/openssl/shim.h"

   # fix inttypes.h
   find "${SCRIPT_DIR}/../appletvos/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;
   find "${SCRIPT_DIR}/../appletvsimulator/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;

   # fix RC4_INT redefinition
   # find "${SCRIPT_DIR}/../appletvos/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/\#define RC4_INT unsigned char/\#if \!defined(RC4_INT)\n#define RC4_INT unsigned char\n\#endif\n/g" {} \;
   # find "${SCRIPT_DIR}/../appletvsimulator/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/\#define RC4_INT unsigned char/\#if \!defined(RC4_INT)\n#define RC4_INT unsigned char\n\#endif\n/g" {} \;

   local OPENSSLCONF_PATH="${SCRIPT_DIR}/../appletvsimulator/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__x86_64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-AppleTVSimulator-x86_64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7A__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7S__)" >> ${OPENSSLCONF_PATH}
#   echo "#elif defined(__APPLE__) && defined (__arm64e__)" >> ${OPENSSLCONF_PATH}
#   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-AppleTVSimulator-arm64e/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-AppleTVSimulator-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   OPENSSLCONF_PATH="${SCRIPT_DIR}/../appletvos/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__arm64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-AppleTVOS-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   rm -rf ${TMP_BUILD_DIR}
}

build_macos() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{macosx/include,macosx/lib}
   mkdir -p "${SCRIPT_DIR}"/../{macosx/include,macosx/lib}

   build "x86_64" "MacOSX" ${TMP_BUILD_DIR} "macosx"
   build "arm64" "MacOSX" ${TMP_BUILD_DIR} "macosx"
   build "arm64e" "MacOSX" ${TMP_BUILD_DIR} "macosx"

   # Copy headers
   ditto ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX-x86_64/include/openssl "${SCRIPT_DIR}/../macosx/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../macosx/include/openssl/shim.h"

   # fix inttypes.h
   find "${SCRIPT_DIR}/../macosx/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;

   # fix RC4_INT redefinition
   # find "${SCRIPT_DIR}/../macosx/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/\#define RC4_INT unsigned char/\#if \!defined(RC4_INT)\n#define RC4_INT unsigned char\n\#endif\n/g" {} \;

   local OPENSSLCONF_PATH="${SCRIPT_DIR}/../macosx/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__i386__)" > ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__x86_64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX-x86_64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7A__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7S__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64e__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX-arm64e/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   rm -rf ${TMP_BUILD_DIR}
}

build_catalyst() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{macosx_catalyst/include,macosx_catalyst/lib}
   mkdir -p "${SCRIPT_DIR}"/../{macosx_catalyst/include,macosx_catalyst/lib}

   build "x86_64" "MacOSX_Catalyst" ${TMP_BUILD_DIR} "macosx_catalyst"
   build "arm64" "MacOSX_Catalyst" ${TMP_BUILD_DIR} "macosx_catalyst"
   # build "arm64e" "MacOSX_Catalyst" ${TMP_BUILD_DIR} "macosx_catalyst"

   # Copy headers
   ditto ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX_Catalyst-x86_64/include/openssl "${SCRIPT_DIR}/../macosx_catalyst/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../macosx_catalyst/include/openssl/shim.h"

   # fix inttypes.h
   find "${SCRIPT_DIR}/../macosx_catalyst/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;

   # fix RC4_INT redefinition
   # find "${SCRIPT_DIR}/../macosx/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/\#define RC4_INT unsigned char/\#if \!defined(RC4_INT)\n#define RC4_INT unsigned char\n\#endif\n/g" {} \;

   local OPENSSLCONF_PATH="${SCRIPT_DIR}/../macosx_catalyst/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__i386__)" > ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__x86_64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX_Catalyst-x86_64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7A__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm__) && defined (__ARM_ARCH_7S__)" >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64e__)" >> ${OPENSSLCONF_PATH}
   # cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX_Catalyst-arm64e/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-MacOSX_Catalyst-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   rm -rf ${TMP_BUILD_DIR}
}

# Start

if [ ! -f "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz" ]; then
   curl -fL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" -o "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz"
   curl -fL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.sha256" -o "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz.sha256"
   DIGEST=$( cat ${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz.sha256 )

   if [[ "$(shasum -a 256 "openssl-${OPENSSL_VERSION}.tar.gz" | awk '{print $1}')" != "${DIGEST}" ]]
   then
      echo "openssl-${OPENSSL_VERSION}.tar.gz: checksum mismatch"
      exit 1
   fi
   rm -f "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz.sha256"
fi

build_tvos
build_ios
build_macos
build_catalyst
