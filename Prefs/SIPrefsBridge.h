#ifndef SIPrefsBridge_h
#define SIPrefsBridge_h

#import <Foundation/Foundation.h>

// Doit rester identique à Tweak/SIPrefsBridge.h — les deux copies existent
// simplement parce que Tweak et Prefs sont deux subprojects Theos séparés.
static NSString * const SIPrefsDomain = @"com.pizzasdu83.slipperyindicator";
static NSString * const SIReloadNotification = @"com.pizzasdu83.slipperyindicator/reload";

typedef NS_ENUM(NSInteger, SIItemType) {
    SIItemBattery = 0,
    SIItemTime,
    SIItemWifi,
    SIItemCellular,
    SIItemCount
};

static inline NSString *SIItemKey(SIItemType type) {
    switch (type) {
        case SIItemBattery:  return @"battery";
        case SIItemTime:     return @"time";
        case SIItemWifi:     return @"wifi";
        case SIItemCellular: return @"cellular";
        default: return @"";
    }
}

static inline NSString *SIItemLabel(SIItemType type) {
    switch (type) {
        case SIItemBattery:  return @"🔋 Batterie";
        case SIItemTime:     return @"⏰ Heure";
        case SIItemWifi:     return @"📶 WiFi";
        case SIItemCellular: return @"📱 4G/5G";
        default: return @"";
    }
}

static NSString * const SIKeyEnabled = @"enabled";

static inline NSString *SIKeyItemEnabled(SIItemType t) { return [NSString stringWithFormat:@"%@_enabled", SIItemKey(t)]; }
static inline NSString *SIKeyItemX(SIItemType t)       { return [NSString stringWithFormat:@"%@_x", SIItemKey(t)]; }
static inline NSString *SIKeyItemY(SIItemType t)       { return [NSString stringWithFormat:@"%@_y", SIItemKey(t)]; }

#endif
