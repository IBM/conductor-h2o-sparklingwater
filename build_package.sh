#!/bin/bash

PACKAGE_NAME="H2O_Sparklingwater"
PACKAGE_VERSION="3.32.0.4-1-2.3"
BUILD_DIR=${BUILD_DIR:-./build}

if [ -d "$BUILD_DIR" ]; then
    rm -fr "$BUILD_DIR"
fi

mkdir -p $BUILD_DIR
cp -f deployment.xml $BUILD_DIR
cp -fr scripts $BUILD_DIR
cp -fr package $BUILD_DIR

cd $BUILD_DIR
tar czvf "${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz" deployment.xml scripts package
