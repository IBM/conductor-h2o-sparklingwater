#!/bin/bash -xe

if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]-[0-9]\.[0-9]$ ]]; then
    echo "Usage: ./build_package.sh sparkling_water_version"
    echo "Sparkling Water Version Example: 3.38.0.1-1-3.0 (including Spark Version)"
    exit 1;
fi

PACKAGE_VERSION=$1
package_version_split=(${PACKAGE_VERSION//-/ })
H2O_VERSION=${package_version_split[0]}
SPARK_VERSION=${package_version_split[2]}
PACKAGE_NAME="h2o-sparkling-water"
H2O_SW_ZIP_FILE="sparkling-water-${PACKAGE_VERSION}.zip"
DOWNLOAD_URL="https://h2o-release.s3.amazonaws.com/sparkling-water/spark-${SPARK_VERSION}/${PACKAGE_VERSION}/${H2O_SW_ZIP_FILE}"
BUILD_DIR=${BUILD_DIR:-./build}
if [ -d "$BUILD_DIR" ]; then
    rm -fr "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cp -f metadata/deployment.xml "$BUILD_DIR"
cp -f metadata/metadata.yml "$BUILD_DIR"
cp -fr scripts "$BUILD_DIR"
cp -fr package "$BUILD_DIR"

grep -rl SUBST_SW_VERSION "$BUILD_DIR" | xargs sed -i.bak "s/SUBST_SW_VERSION/$PACKAGE_VERSION/g"
grep -rl SUBST_H2O_VERSION "$BUILD_DIR" | xargs sed -i.bak "s/SUBST_H2O_VERSION/$H2O_VERSION/g"
# .bak provided for sed command to work on both Darwin & GNU Sed
find . -name "*.bak" -type f -delete

if [ ! -f "$H2O_SW_ZIP_FILE" ]; then
    curl "${DOWNLOAD_URL}" --output "$H2O_SW_ZIP_FILE"
fi

unzip -p "$H2O_SW_ZIP_FILE" 'sparkling-water*/bin/sparkling-env.sh' > "$BUILD_DIR/package/sparkling-env.sh"
cp "$H2O_SW_ZIP_FILE" "$BUILD_DIR/package/$H2O_SW_ZIP_FILE"
cd "$BUILD_DIR"

tar czvf "${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz" deployment.xml scripts package
rm -fr deployment.xml scripts package