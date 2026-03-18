#!/bin/bash
# Полный релиз: сборка, DMG-установщик, тег, GitHub Release.
# Версия = годмесяцденьчас (YYYYMMDDHH). Загружает GITHUB_TOKEN из .env.

set -e
REPO="lyucean/YaTray"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Подгрузить .env
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Ошибка: GITHUB_TOKEN не задан. Добавьте в .env или export GITHUB_TOKEN=..."
  exit 1
fi

# Версия = годмесяцденьчас
VERSION=$(date +%Y%m%d%H)
TAG="v${VERSION}"
DMG_NAME="YaTray-macOS-${VERSION}.dmg"
RELEASE_DIR="$ROOT/release"
ARCHIVE="$RELEASE_DIR/$DMG_NAME"
APP_BUNDLE="build/Build/Products/Release/YaTray.app"

echo "Версия: $VERSION (тег $TAG)"

# 1. Сборка
echo "Сборка Release..."
xcodebuild -project YaTray.xcodeproj -scheme YaTray -configuration Release -derivedDataPath build clean build -quiet

# 2. Создание DMG (перетащи в Applications)
echo "Создание DMG $DMG_NAME..."
./scripts/create-dmg.sh "$VERSION"

# 3. Тег и пуш (если тег уже есть - только загружаем в существующий релиз)
TAG_EXISTS=0
if git rev-parse "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Тег $TAG уже существует, пуш пропускаем."
  TAG_EXISTS=1
else
  echo "Создание тега $TAG..."
  git tag -a "$TAG" -m "Release $VERSION"
  git push origin "$TAG"
fi

# 4. Релиз на GitHub: создать или получить по тегу, прикрепить DMG
RELEASE_ID=""
if [ "$TAG_EXISTS" = "1" ]; then
  echo "Получение релиза по тегу..."
  RELEASE_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${REPO}/releases/tags/${TAG}")
  HTTP_CODE=$(echo "$RELEASE_RESP" | tail -1)
  BODY=$(echo "$RELEASE_RESP" | sed '$d')
  RELEASE_ID=$(echo "$BODY" | grep -o '"id": [0-9]*' | head -1 | grep -o '[0-9]*' || true)
  if [ -z "$RELEASE_ID" ] || [ "$HTTP_CODE" = "404" ]; then
    echo "Релиза для тега ещё нет, создаём..."
    RELEASE_RESP=$(curl -s -w "\n%{http_code}" -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/${REPO}/releases" \
      -d "{
        \"tag_name\": \"${TAG}\",
        \"name\": \"Release ${VERSION}\",
        \"body\": \"Скачайте **${DMG_NAME}** (в Assets). Откройте образ и перетащите YaTray.app в папку «Программы». Не скачивайте Source code - там исходники.\"
      }")
    HTTP_CODE=$(echo "$RELEASE_RESP" | tail -1)
    BODY=$(echo "$RELEASE_RESP" | sed '$d')
    RELEASE_ID=$(echo "$BODY" | grep -o '"id": [0-9]*' | head -1 | grep -o '[0-9]*' || true)
    if [ -z "$RELEASE_ID" ]; then
      echo "Ошибка создания релиза (HTTP $HTTP_CODE): $BODY"
      exit 1
    fi
  fi
else
  echo "Создание релиза на GitHub..."
  RELEASE_RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/${REPO}/releases" \
    -d "{
      \"tag_name\": \"${TAG}\",
      \"name\": \"Release ${VERSION}\",
      \"body\": \"Скачайте **${DMG_NAME}** (в Assets). Откройте образ и перетащите YaTray.app в папку «Программы». Не скачивайте Source code - там исходники.\"
    }")
  HTTP_CODE=$(echo "$RELEASE_RESP" | tail -1)
  BODY=$(echo "$RELEASE_RESP" | sed '$d')
  RELEASE_ID=$(echo "$BODY" | grep -o '"id": [0-9]*' | head -1 | grep -o '[0-9]*' || true)
  if [ -z "$RELEASE_ID" ]; then
    echo "Ошибка создания релиза (HTTP $HTTP_CODE): $BODY"
    exit 1
  fi
fi

UPLOAD_URL="https://uploads.github.com/repos/${REPO}/releases/${RELEASE_ID}/assets?name=${DMG_NAME}"
echo "Загрузка $DMG_NAME..."
UPLOAD_RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@${ARCHIVE}" \
  "$UPLOAD_URL")
HTTP_CODE=$(echo "$UPLOAD_RESP" | tail -1)
BODY=$(echo "$UPLOAD_RESP" | sed '$d')
if [ "$HTTP_CODE" = "201" ]; then
  echo "Ассет загружен."
elif [ "$HTTP_CODE" = "422" ] && echo "$BODY" | grep -q '"code":"already_exists"'; then
  echo "Ассет $DMG_NAME уже есть в релизе, пропускаем загрузку."
else
  echo "Ошибка загрузки (HTTP $HTTP_CODE): $BODY"
  exit 1
fi

echo "Готово. Релиз: https://github.com/${REPO}/releases/tag/${TAG}"
