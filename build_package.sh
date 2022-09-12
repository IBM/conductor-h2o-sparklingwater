#!/bin/bash -xe

PACKAGE_NAME="h2o-sparkling-water"
SPARK_VERSION="3.0"
PACKAGE_VERSION="3.36.1.4-1-${SPARK_VERSION}"
H2O_SW_ZIP_FILE="sparkling-water-${PACKAGE_VERSION}.zip"
DOWNLOAD_URL="https://h2o-release.s3.amazonaws.com/sparkling-water/spark-${SPARK_VERSION}/${PACKAGE_VERSION}/${H2O_SW_ZIP_FILE}"
BUILD_DIR=${BUILD_DIR:-./build}
if [ -d "$BUILD_DIR" ]; then
    rm -fr "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cp -f deployment.xml "$BUILD_DIR"
cp -fr scripts "$BUILD_DIR"
cp -fr package "$BUILD_DIR"

if [ ! -f "$H2O_SW_ZIP_FILE" ]; then
    curl ${DOWNLOAD_URL} --output "$H2O_SW_ZIP_FILE"
fi
cp $H2O_SW_ZIP_FILE "$BUILD_DIR/package/$H2O_SW_ZIP_FILE"
cd "$BUILD_DIR"
tar czvf "${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz" deployment.xml scripts package
