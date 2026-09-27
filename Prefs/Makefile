include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SlipperyIndicatorPrefs

SlipperyIndicatorPrefs_FILES = $(wildcard *.m)
SlipperyIndicatorPrefs_FRAMEWORKS = UIKit CoreGraphics
SlipperyIndicatorPrefs_PRIVATE_FRAMEWORKS = Preferences
SlipperyIndicatorPrefs_INSTALL_PATH = /Library/PreferenceBundles
SlipperyIndicatorPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SlipperyIndicatorPrefs.bundle
	@cp -f $(THEOS_PROJECT_DIR)/Prefs/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SlipperyIndicatorPrefs.bundle/entry.plist
	@cp -f $(THEOS_PROJECT_DIR)/Prefs/Root.plist $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SlipperyIndicatorPrefs.bundle/Root.plist
	@cp -f $(THEOS_PROJECT_DIR)/Prefs/Resources/bubble.png $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SlipperyIndicatorPrefs.bundle/bubble.png
	@cp -f $(THEOS_PROJECT_DIR)/Prefs/Resources/bubble@2x.png $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SlipperyIndicatorPrefs.bundle/bubble@2x.png
	@cp -f $(THEOS_PROJECT_DIR)/Prefs/Resources/bubble@3x.png $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SlipperyIndicatorPrefs.bundle/bubble@3x.png

	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	@cp -f $(THEOS_PROJECT_DIR)/Prefs/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SlipperyIndicatorPrefs.plist

after-install::
	install.exec "killall -9 Preferences || true"
