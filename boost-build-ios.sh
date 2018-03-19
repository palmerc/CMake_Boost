#!/bin/bash

XCODE_SDK="$1"
TARGET_ARCHITECTURE="$2"
SOURCE_DIR="$3"
INSTALL_DIR="$4"
BOOST_CXXFLAGS_FILE="$5"
BOOST_MODULES_FILE="$6"

VERBOSE_LOGGING=false
FORCE_REBUILD=false
NCPU=8

CXXFLAGS=$( < "${BOOST_CXXFLAGS_FILE}" )
if [[ "${CXXFLAGS}" == *"-g"* ]]; then
    DEBUG_ENABLED=true
fi

IFS=" " read -r -a BOOST_MODULES <<< "$( < "${BOOST_MODULES_FILE}" )"
WITH_LIBRARIES=$( IFS=","; echo "${BOOST_MODULES[*]}" )
BOOST_LIBRARIES=()
for BOOST_MODULE in "${BOOST_MODULES[@]}"; do
    BOOST_LIBRARIES+=( "libboost_${BOOST_MODULE}.a" )
done

XCODE_SDK_SHORT=
if [ "${XCODE_SDK}" == "iphoneos" ]; then
    XCODE_SDK_SHORT="iphone"
elif [ "${XCODE_SDK}" == "iphonesimulator" ]; then
    XCODE_SDK_SHORT="iphonesim"
fi

TARGET_ARCHITECTURE_FAMILY=
if [[ "${TARGET_ARCHITECTURE}" == arm* ]]; then
    TARGET_ARCHITECTURE_FAMILY="arm"
elif [ "${TARGET_ARCHITECTURE}" == "i386" ] || [ "${TARGET_ARCHITECTURE}" == "x86_64" ]; then
    TARGET_ARCHITECTURE_FAMILY="x86"
fi

echo "BOOST ${TARGET_ARCHITECTURE} - locating build tools"
XCODE_SDK_VERSION=$( xcrun --sdk "${XCODE_SDK}" --show-sdk-version )
XCODE_CLANG=$( xcrun --sdk "${XCODE_SDK}" --find clang++ )

echo "BOOST ${TARGET_ARCHITECTURE} - setting results directory"
pushd "${INSTALL_DIR}" || exit
INSTALL_DIR=$( pwd )
popd || exit

echo "BOOST ${TARGET_ARCHITECTURE} - setting source directory"
pushd "${SOURCE_DIR}" || exit
SOURCE_DIR=$( pwd )

TARGET_OS="iphone"
PLATFORM_NAME="darwin"
TOOLSET_PREFIX="${PLATFORM_NAME}"
TOOLSET_SUFFIX="${XCODE_SDK_VERSION}~${XCODE_SDK_SHORT}"
TOOLSET="${TOOLSET_PREFIX}-${TOOLSET_SUFFIX}"

if [ "${TARGET_ARCHITECTURE}" == "arm64" ]; then
    echo "BOOST ${TARGET_ARCHITECTURE} - patching"
    export LC_ALL=C
    sed -ie 's/armv7 armv7s/armv7 armv7s arm64/g' 'tools/build/src/tools/builtin.jam'
fi

echo "BOOST ${TARGET_ARCHITECTURE} - using toolset ${TOOLSET}"

USER_CONFIG_JAM=()
USER_CONFIG_JAM+=( "using ${TOOLSET_PREFIX} : ${TOOLSET_SUFFIX}" )
USER_CONFIG_JAM+=( ": ${XCODE_CLANG}" )
USER_CONFIG_JAM+=( ";" )

USER_CONFIG_STRING=$( IFS=$'\n'; echo "${USER_CONFIG_JAM[*]}" )
echo "BOOST ${TARGET_ARCHITECTURE} - Creating ${SOURCE_DIR}/tools/build/src/user-config.jam"
echo "${USER_CONFIG_STRING}" > "${SOURCE_DIR}/tools/build/src/user-config.jam"

BOOTSTRAP_OPTIONS=()
BOOTSTRAP_OPTIONS+=( "--with-libraries=${WITH_LIBRARIES}" )
BOOTSTRAP_OPTIONS+=( "--prefix=${INSTALL_DIR}" )

BOOTSTRAP_COMMAND="${SOURCE_DIR}/bootstrap.sh ${BOOTSTRAP_OPTIONS[*]}"
echo "BOOST ${TARGET_ARCHITECTURE} - ${BOOTSTRAP_COMMAND}"
eval "${BOOTSTRAP_COMMAND}"

B2_OPTIONS=()
if [ "${VERBOSE_LOGGING}" ]; then
    B2_OPTIONS+=( "-d+2" )
fi
if [ "${FORCE_REBUILD}" ]; then
    B2_OPTIONS+=( "-a" )
fi
B2_OPTIONS+=( "-j${NCPU}" )
B2_OPTIONS+=( "--reconfigure" )
B2_OPTIONS+=( "architecture=${TARGET_ARCHITECTURE_FAMILY}" )
if [ "${TARGET_ARCHITECTURE_FAMILY}" == "arm" ]; then
    B2_OPTIONS+=( "instruction-set=${TARGET_ARCHITECTURE}" )
fi
B2_ADDRESS_MODEL_OPTION="32"
if [ "${TARGET_ARCHITECTURE}" == "arm64" ] || [ "${TARGET_ARCHITECTURE}" == "x86_64" ]; then
    B2_ADDRESS_MODEL_OPTION="64"
fi
B2_OPTIONS+=( "address-model=${B2_ADDRESS_MODEL_OPTION}" )
B2_OPTIONS+=( "toolset=${TOOLSET}" )
B2_OPTIONS+=( "target-os=${TARGET_OS}" )
if [[ "${#CXXFLAGS[@]}" -gt 0 ]]; then
    B2_OPTIONS+=( "cxxflags=\"${CXXFLAGS[*]}\"" )
fi

if [[ "${TARGET_ARCHITECTURE}" == arm* ]]; then
    B2_OPTIONS+=( "define=_LITTLE_ENDIAN" )
fi

B2_OPTIONS+=( "link=static" )
B2_OPTIONS+=( "threading=single" )
B2_VARIANT_OPTION="release"
if [ "${DEBUG_ENABLED}" ]; then
    B2_VARIANT_OPTION="debug"
fi
B2_OPTIONS+=( "variant=${B2_VARIANT_OPTION}" )
B2_OPTIONS+=( "install" )

B2_COMMAND="${SOURCE_DIR}/b2 ${B2_OPTIONS[*]}"
echo "BOOST ${TARGET_ARCHITECTURE} - ${B2_COMMAND}"
eval "${B2_COMMAND}"

echo "BOOST ${TARGET_ARCHITECTURE} - validating"
SUCCESS=1
for BOOST_LIBRARY in "${BOOST_LIBRARIES[@]}"; do
    BOOST_LIBRARY_PATH=$( find "${INSTALL_DIR}" -name "${BOOST_LIBRARY}" -print | head -n 1 )
    lipo "${BOOST_LIBRARY_PATH}" -verify_arch "${TARGET_ARCHITECTURE}"
    SUCCESS=$?
    if [[ ${SUCCESS} -ne 0 ]]; then
        break
    fi
done

RESULT="success"
if [ "${SUCCESS}" -ne 0 ]; then
    RESULT="failure"
fi
echo "BOOST ${TARGET_ARCHITECTURE} - ${RESULT}"

popd || exit

exit "${SUCCESS}"
