#!/bin/sh
#
# Metashell - Interactive C++ template metaprogramming shell
# Copyright (C) 2013, Abel Sinkovics (abel@sinkovics.hu)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

if [ ! -d cmake ]
then
  echo "Please run this script from the root directory of the Metashell source code"
  exit 1
fi

# Arguments
if [ -z "${BUILD_THREADS}" ]
then
  BUILD_THREADS=1
fi

if [ -z "${TEST_THREADS}" ]
then
  TEST_THREADS="${BUILD_THREADS}"
fi

if [ -z "${BUILD_TYPE}" ]
then
  BUILD_TYPE="Release"
fi

if [ -z "${TESTS}" ]
then
  TESTS_ARG=""
else
  TESTS_ARG="-DTESTS=${TESTS}"
fi

if [ -z "${ENABLE_UNITY_BUILD}" ]
then
  UNITY_BUILD_ARGS=""
else
  UNITY_BUILD_ARGS="-DCMAKE_UNITY_BUILD=ON"
fi

PLATFORM="$(tools/detect_platform.sh)"
PLATFORM_ID="$(tools/detect_platform.sh --id)"

# Config
if [ "${PLATFORM}" = "openbsd" ]
then
  export CC=egcc
  export CXX=eg++
fi

# Show argument & config summary
echo "Number of threads used for building: ${BUILD_THREADS}"
echo "Number of threads used for testing: ${TEST_THREADS}"
echo "Platform: ${PLATFORM} (${PLATFORM_ID})"

# Build Templight
if [ "${NO_TEMPLIGHT}" = "" ]
then
  if [ "${PLATFORM}" = "opensuse" ] || [ "${PLATFORM}" = "fedora" ]
  then
    # The default Templight include path seems to be empty on Tumbleweed
    C_INCLUDE_DIRS="-DC_INCLUDE_DIRS=$(tools/clang_default_path --gcc g++ -f shell)"
  elif [ "${PLATFORM}" = "osx" ]
  then
    # osx has the standard headers within XCode's installation directory
    C_INCLUDE_DIRS="-DC_INCLUDE_DIRS=$(tools/clang_default_path --gcc clang++ -f shell)"
  else
    C_INCLUDE_DIRS=""
  fi

  mkdir -p "bin/${PLATFORM_ID}/templight"; cd "bin/${PLATFORM_ID}/templight"
    cmake \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DLLVM_ENABLE_TERMINFO=OFF \
      -DLLVM_ENABLE_PROJECTS=clang \
      "${C_INCLUDE_DIRS}" \
      ../../../3rd/templight/llvm
    make templight -j${BUILD_THREADS}
  cd ../../..
else
  echo "Skipping Templight build, because \$NO_TEMPLIGHT = \"${NO_TEMPLIGHT}\""
fi

mkdir -p "bin/${PLATFORM_ID}/metashell"; cd "bin/${PLATFORM_ID}/metashell"
  if [ -z "${METASHELL_NO_DOC_GENERATION}" ]
  then
    cmake ../../.. ${TESTS_ARG} ${UNITY_BUILD_ARGS}
  else
    cmake ../../.. ${TESTS_ARG} ${UNITY_BUILD_ARGS} -DMETASHELL_NO_DOC_GENERATION=1
  fi
  make -j${BUILD_THREADS}
  ctest -j${TEST_THREADS} || (cat Testing/Temporary/LastTest.log && false)
cd ../../..

if [ "${NO_INSTALLER}" = "" ]
then
  cd "bin/${PLATFORM_ID}/metashell"
    cpack
    make system_test_zip
  cd ../../..

  SYSTEM_TEST_BOOST_ZIP="bin/${PLATFORM_ID}/metashell/system_test_boost.zip"
  rm -f ${SYSTEM_TEST_BOOST_ZIP}
  cd 3rd/boost
    for LIB in config mpl preprocessor type_traits
    do
      cd ${LIB}
        zip -qr ../../../${SYSTEM_TEST_BOOST_ZIP} include
      cd ..
    done
  cd ../..
else
  echo "Skipping installer generation, because \$NO_INSTALLER = \"${NO_INSTALLER}\""
fi
