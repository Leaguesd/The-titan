#!/usr/bin/env sh
# 泰坦生物 (titan) 一键构建
#
#   sh build.sh              # 构建
#   sh build.sh clean build  # 参数透传给 Gradle
#
# 等价于 `sh gradlew build`，只是名字更好记。

set -e
cd "$(dirname "$0")"
exec sh ./gradlew "$@"
