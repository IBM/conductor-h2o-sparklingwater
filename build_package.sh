#!/bin/bash

PACKAGE_NAME="H2O_Sparklingwater"
PACKAGE_VERSION="3.32.1.7-1-2.4"
BUILD_DIR=${BUILD_DIR:-./build}
DOWNLOAD_URL="https://h2o-release.s3.amazonaws.com/sparkling-water/spark-2.4/3.32.1.7-1-2.4/sparkling-water-3.32.1.7-1-2.4.zip"


if [ -d "$BUILD_DIR" ]; then
    rm -fr "$BUILD_DIR"
fi

mkdir -p $BUILD_DIR
cp -f deployment.xml $BUILD_DIR
cp -fr scripts $BUILD_DIR
cp -fr package $BUILD_DIR

curl ${DOWNLOAD_URL} --output $BUILD_DIR/package/sparkling-water-${PACKAGE_VERSION}.zip
cd $BUILD_DIR
tar czvf "${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz" deployment.xml scripts package
