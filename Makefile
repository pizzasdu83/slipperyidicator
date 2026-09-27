export TARGET = iphone:clang:16.5:15.0
export ARCHS = arm64
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += Tweak Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
