#!/bin/bash

PACKAGE_NAME="H2O_Sparklingwater"
PACKAGE_VERSION="3.28.0.3-1-2.4"
BUILD_DIR=${BUILD_DIR:-./build}
DOWNLOAD_URL="https://s3.amazonaws.com/h2o-release/sparkling-water/spark-2.4/3.28.0.3-1-2.4/sparkling-water-3.28.0.3-1-2.4.zip"


if [ -d "$BUILD_DIR" ]; then
    rm -fr "$BUILD_DIR"
fi

mkdir -p $BUILD_DIR
cp -f deployment.xml $BUILD_DIR
cp -fr scripts $BUILD_DIR
cp -fr package $BUILD_DIR

cd package;curl ${DOWNLOAD_URL} --output sparkling-water-${PACKAGE_VERSION}.zip
cd ../$BUILD_DIR
tar czvf "${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz" deployment.xml scripts package
