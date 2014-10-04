export TARGET = iphone:clang:latest
export ARCHS = armv7

include theos/makefiles/common.mk

SOURCE_DIR = sources

TOOL_NAME = daemon
daemon_FILES = $(foreach ext, c cpp m mm x xm xi xmi, $(wildcard $(SOURCE_DIR)/*.$(ext)))
daemon_PRIVATE_FRAMEWORKS = CoreFoundation GraphicsServices
daemon_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/tool.mk
