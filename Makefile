# YaTray - сборка и релиз macOS-приложения
PROJECT = YaTray.xcodeproj
SCHEME = YaTray
CONFIG ?= Release
BUILD_DIR = build

.DEFAULT_GOAL := help

.PHONY: help build clean run zip dmg install release

help:
	@echo "YaTray - доступные команды:"
	@echo ""
	@echo "  make          - показать эту справку"
	@echo "  make help     - показать эту справку"
	@echo "  make build    - только сборка (Release)"
	@echo "  make run      - собрать и запустить приложение"
	@echo "  make install  - собрать и установить в /Applications"
	@echo "  make zip      - упаковать текущую сборку в zip (release/)"
	@echo "  make dmg      - собрать и создать DMG-установщик (release/)"
	@echo "  make release  - полный релиз: сборка, DMG, тег, GitHub Release"
	@echo ""
	@echo "Переменные: CONFIG=Debug|Release (по умолчанию Release)"
	@echo "Релиз: GITHUB_TOKEN в .env (см. scripts/do-release.sh)"

# Полный релиз: сборка, DMG, тег годмесяцденьчас, пуш тега, GitHub Release
release:
	@./scripts/do-release.sh

# Собрать и создать DMG с окном «перетащи в Applications»
dmg: build
	@./scripts/create-dmg.sh

# Только сборка Release
build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) build

# Только упаковать текущую сборку в zip (версия = годмесяцденьчас)
zip:
	@VERSION=$$(date +%Y%m%d%H); \
	rm -rf release/YaTray.app release/YaTray-macOS-*.zip; \
	mkdir -p release && cp -R $(BUILD_DIR)/Build/Products/$(CONFIG)/YaTray.app release/; \
	cd release && zip -rq "YaTray-macOS-$$VERSION.zip" YaTray.app; \
	echo "Создан release/YaTray-macOS-$$VERSION.zip"

# Собрать и поставить YaTray.app в /Applications
install: build
	@echo "Установка в /Applications/YaTray.app ..."
	@rm -rf /Applications/YaTray.app
	@cp -R $(BUILD_DIR)/Build/Products/$(CONFIG)/YaTray.app /Applications/
	@echo "Готово. YaTray установлен в /Applications."

clean:
	rm -rf $(BUILD_DIR)

run: build
	open $(BUILD_DIR)/Build/Products/$(CONFIG)/YaTray.app
