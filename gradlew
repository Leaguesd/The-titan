#!/bin/sh
#
# 泰坦生物 (thetitans) 自愈版 Gradle 启动器
#
# 用法与原版 gradlew 完全一致：
#     ./gradlew build
#     sh gradlew build
#
# 两个保证：
#  1. 不依赖 gradle/wrapper/gradle-wrapper.jar（丢了也能跑）。
#  2. 只使用 Gradle 8.x —— ForgeGradle 6 不支持 Gradle 9，系统里装了 9.x 也不会被误用。
#
set -e

APP_HOME=$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)
cd "$APP_HOME"

GRADLE_VER=8.8

# ---------------- Java ----------------
if [ -z "$JAVA_HOME" ]; then
    if command -v java >/dev/null 2>&1; then
        _java=$(command -v java)
        _real=$(readlink -f "$_java" 2>/dev/null || echo "$_java")
        _home=$(dirname "$(dirname "$_real")")
        if [ -x "$_home/bin/java" ]; then
            JAVA_HOME="$_home"
            export JAVA_HOME
        fi
    fi
fi

if [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    :
elif command -v java >/dev/null 2>&1; then
    :
else
    echo "[ERROR] Java not found. Termux: pkg install openjdk-17" >&2
    exit 1
fi

# ---------------- helpers ----------------
# 仅接受 Gradle 8.x
is_gradle8() {
    [ -x "$1" ] || return 1
    _v=$("$1" --version 2>/dev/null | sed -n 's/^Gradle \([0-9][0-9.]*\).*/\1/p' | head -n 1)
    case "$_v" in
        8.*) GRADLE_FOUND_VER="$_v"; return 0 ;;
        *)   return 1 ;;
    esac
}

GRADLE=""
GRADLE_FOUND_VER=""

# 1) 环境变量显式指定
if [ -n "${GRADLE_BIN:-}" ] && is_gradle8 "$GRADLE_BIN"; then
    GRADLE="$GRADLE_BIN"
fi

# 2) 之前 wrapper 下载好的 Gradle 8.x（~/.gradle/wrapper/dists）
if [ -z "$GRADLE" ]; then
    for _dist in "$HOME"/.gradle/wrapper/dists/gradle-8*-bin/*/gradle-8*/bin/gradle; do
        if is_gradle8 "$_dist"; then
            GRADLE="$_dist"
            break
        fi
    done
fi

# 3) 本脚本之前下载的
if [ -z "$GRADLE" ] && is_gradle8 "$HOME/.gradle/local-gradle/gradle-$GRADLE_VER/bin/gradle"; then
    GRADLE="$HOME/.gradle/local-gradle/gradle-$GRADLE_VER/bin/gradle"
fi

# 4) 系统 gradle —— 只有 8.x 才用，9.x 会被跳过
if [ -z "$GRADLE" ] && command -v gradle >/dev/null 2>&1; then
    _sys=$(command -v gradle)
    if is_gradle8 "$_sys"; then
        GRADLE="$_sys"
    else
        _sysver=$("$_sys" --version 2>/dev/null | sed -n 's/^Gradle \([0-9][0-9.]*\).*/\1/p' | head -n 1)
        echo "[gradlew] 忽略系统的 Gradle ${_sysver:-?}（ForgeGradle 6 只支持 Gradle 8.x）" >&2
    fi
fi

# 5) 下载 Gradle 8.8
if [ -z "$GRADLE" ]; then
    _root="$HOME/.gradle/local-gradle"
    GRADLE="$_root/gradle-$GRADLE_VER/bin/gradle"
    if [ ! -x "$GRADLE" ]; then
        echo "[gradlew] 下载 Gradle $GRADLE_VER 到 $_root ..."
        mkdir -p "$_root"
        _zip="${TMPDIR:-/tmp}/gradle-$GRADLE_VER-bin.zip"
        _url="https://services.gradle.org/distributions/gradle-$GRADLE_VER-bin.zip"
        if command -v curl >/dev/null 2>&1; then
            curl -L --fail --retry 3 -o "$_zip" "$_url"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$_zip" "$_url"
        else
            echo "[ERROR] need curl or wget to download Gradle" >&2
            exit 1
        fi
        if command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$_zip" -d "$_root"
        else
            echo "[ERROR] need unzip (pkg install unzip)" >&2
            exit 1
        fi
        rm -f "$_zip"
    fi
    GRADLE_FOUND_VER="$GRADLE_VER"
fi

echo "[gradlew] Gradle: ${GRADLE_FOUND_VER:-8.x}  ($GRADLE)"
exec "$GRADLE" "$@"
