#!/bin/bash
# Создаёт DMG с окном «перетащи YaTray.app в папку Applications».
# Использование: ./create-dmg.sh [версия]
# Версия по умолчанию: годмесяцденьчас. Ожидает собранный build/Build/Products/Release/YaTray.app.

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_BUNDLE="$ROOT/build/Build/Products/Release/YaTray.app"
VERSION="${1:-$(date +%Y%m%d%H)}"
DMG_NAME="YaTray-macOS-${VERSION}.dmg"
RELEASE_DIR="$ROOT/release"
VOLUME_NAME="Install YaTray"
TMP_DMG="$RELEASE_DIR/YaTray-macOS-install-temp.dmg"
TMP_MOUNT="/Volumes/$VOLUME_NAME"

if [ ! -d "$APP_BUNDLE" ]; then
  echo "Ошибка: не найден $APP_BUNDLE. Сначала выполните: make build"
  exit 1
fi

echo "Создание DMG: $DMG_NAME (версия $VERSION)"
rm -rf "$RELEASE_DIR/YaTray.app" "$RELEASE_DIR/$VOLUME_NAME" "$TMP_DMG" "$RELEASE_DIR/YaTray-macOS-"*.dmg
mkdir -p "$RELEASE_DIR"

# Временная папка с содержимым тома
STAGING="$RELEASE_DIR/staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Создаём читаемый-записываемый DMG
DMG_SIZE=50
hdiutil create -size ${DMG_SIZE}m -volname "$VOLUME_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -ov -srcfolder "$STAGING" "$TMP_DMG"
rm -rf "$STAGING"

# Монтируем и настраиваем вид окна (иконки, позиции)
hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen -quiet

# Даём Finder время увидеть том
sleep 2

# Классический вид: иконки слева и справа, окно по размеру (иконки 128px — не опускать низко)
osascript <<EOF
tell application "Finder"
  set d to disk "$VOLUME_NAME"
  open d
  set w to container window of d
  set current view of w to icon view
  set toolbar visible of w to false
  set statusbar visible of w to false
  set bounds of w to {200, 120, 740, 480}
  set icon size of icon view options of w to 128
  set arrangement of icon view options of w to not arranged
  set position of item "YaTray.app" of d to {120, 100}
  set position of item "Applications" of d to {390, 100}
  close w
  update d
end tell
EOF

# Размонтируем и ждём, пока том точно исчезнет (иначе convert даёт "Resource temporarily unavailable")
hdiutil detach "$TMP_MOUNT" -force 2>/dev/null || true
for i in 1 2 3 4 5 6 7 8 9 10; do
  [ ! -d "$TMP_MOUNT" ] && break
  sleep 1
done
if [ -d "$TMP_MOUNT" ]; then
  echo "Ошибка: не удалось размонтировать $TMP_MOUNT. Закройте окно Finder с этим томом и повторите."
  exit 1
fi
sleep 2

# Сжимаем в read-only UDZO (повтор при занятости ресурса)
for attempt in 1 2 3; do
  if hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$RELEASE_DIR/$DMG_NAME" -ov 2>/dev/null; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "Ошибка: hdiutil convert не удался. Убедитесь, что образ размонтирован (Finder -> извлечь)."
    exit 1
  fi
  sleep 3
done
rm -f "$TMP_DMG"

echo "Готово: $RELEASE_DIR/$DMG_NAME"
