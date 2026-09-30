include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SlipperyIndicatorPrefs
SlipperyIndicatorPrefs_FILES = $(wildcard *.m)
SlipperyIndicatorPrefs_FRAMEWORKS = UIKit CoreGraphics
SlipperyIndicatorPrefs_PRIVATE_FRAMEWORKS = Preferences
SlipperyIndicatorPrefs_INSTALL_PATH = /Library/PreferenceBundles
SlipperyIndicatorPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	@cp -f Root.plist $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SlipperyIndicatorPrefs.bundle/Root.plist
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	@cp -f entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SlipperyIndicatorPrefs.plist

after-install::
	install.exec "killall -9 Preferences || true"
