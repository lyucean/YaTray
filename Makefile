# YaTray - сборка macOS-приложения
PROJECT = YaTray.xcodeproj
SCHEME = YaTray
CONFIG ?= Release
BUILD_DIR = build

.PHONY: build clean run

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) build

clean:
	rm -rf $(BUILD_DIR)

run: build
	open $(BUILD_DIR)/Build/Products/$(CONFIG)/YaTray.app
