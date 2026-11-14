#!/bin/bash
# 2027日历 APK 构建脚本（无 Gradle 直接构建）
# 依赖：JDK 17、Android SDK（build-tools;34.0.0 + platforms;android-34）
# 可通过环境变量覆盖：ANDROID_SDK_ROOT / JAVA_HOME
set -e
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/home/user/android-sdk}}"
BT="$SDK/build-tools/34.0.0"
AJAR="$SDK/platforms/android-34/android.jar"
export JAVA_HOME="${JAVA_HOME:-/home/user/jdk17}"
export PATH="$JAVA_HOME/bin:$PATH"

SRC="$(cd "$(dirname "$0")" && pwd)/2027日历-源码"
OUT="$(cd "$(dirname "$0")" && pwd)"
B="$OUT/build/apk"
rm -rf "$B"; mkdir -p "$B/classes" "$B/dex" "$B/gen"

echo "[1/7] 编译资源"
"$BT/aapt2" compile --dir "$SRC/res" -o "$B/res.zip"

echo "[2/7] 链接资源"
"$BT/aapt2" link \
  -o "$B/app.unsigned.apk" \
  -I "$AJAR" \
  --manifest "$SRC/AndroidManifest.xml" \
  -R "$B/res.zip" \
  -A "$SRC/assets" \
  --java "$B/gen" \
  --min-sdk-version 21 --target-sdk-version 34 \
  --version-code 1 --version-name 1.0 \
  --auto-add-overlay

echo "[3/7] 编译 Java"
find "$SRC/java" -name "*.java" > "$B/srcs.txt"
javac -source 8 -target 8 -encoding UTF-8 -bootclasspath "$AJAR" \
  -classpath "$AJAR" -d "$B/classes" -Xlint:-options @"$B/srcs.txt"

echo "[4/7] dex 转换"
"$BT/d8" --lib "$AJAR" --min-api 21 --output "$B/dex" $(find "$B/classes" -name "*.class")

echo "[5/7] 打包 dex"
cd "$B/dex" && zip -q -j "$B/app.unsigned.apk" classes.dex && cd "$OUT"

echo "[6/7] 对齐"
"$BT/zipalign" -f -p 4 "$B/app.unsigned.apk" "$B/app.aligned.apk"

echo "[7/7] 签名"
KS="$OUT/build/cal2027.keystore"
if [ ! -f "$KS" ]; then
  keytool -genkeypair -v -keystore "$KS" -alias cal2027 \
    -storepass cal2027 -keypass cal2027 -keyalg RSA -keysize 2048 -validity 10950 \
    -dname "CN=2027 Calendar, OU=App, O=Doubao, L=Putian, ST=Fujian, C=CN" > /dev/null 2>&1
fi
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:cal2027 --key-pass pass:cal2027 \
  --min-sdk-version 21 --out "$OUT/2027日历.apk" "$B/app.aligned.apk"

"$BT/apksigner" verify --print-certs "$OUT/2027日历.apk" | head -4
echo "构建完成: $OUT/2027日历.apk"
ls -lh "$OUT/2027日历.apk"
