# YaTray - сборка macOS-приложения
PROJECT = YaTray.xcodeproj
SCHEME = YaTray
CONFIG ?= Release
BUILD_DIR = build

.DEFAULT_GOAL := help

.PHONY: help build clean run

help:
	@echo "YaTray - команды сборки:"
	@echo ""
	@echo "  make build   - собрать приложение (Release)"
	@echo "  make run    - собрать и запустить приложение"
	@echo "  make clean  - удалить каталог build"
	@echo ""
	@echo "Переменные: CONFIG=Debug|Release (по умолчанию Release)"

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) build

clean:
	rm -rf $(BUILD_DIR)

run: build
	open $(BUILD_DIR)/Build/Products/$(CONFIG)/YaTray.app
