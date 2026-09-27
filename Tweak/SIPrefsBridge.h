#ifndef SIPrefsBridge_h
#define SIPrefsBridge_h

#import <Foundation/Foundation.h>

// Domaine des préférences du tweak (le fichier plist réel est géré par CFPreferences,
// pas besoin de connaître son chemin exact — il varie selon rootless/rootful).
static NSString * const SIPrefsDomain = @"com.pizzasdu83.slipperyindicator";

// Notification Darwin envoyée par les Prefs à chaque changement, pour que
// SpringBoard recharge les positions sans redémarrer.
static NSString * const SIReloadNotification = @"com.pizzasdu83.slipperyindicator/reload";

// Types d'indicateurs gérés
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

// Clé globale d'activation du tweak
static NSString * const SIKeyEnabled = @"enabled";

// Par item : "<item>_enabled", "<item>_x", "<item>_y"
// x/y sont stockés en points d'écran RÉELS (UIScreen.main.bounds), pas besoin
// de mise à l'échelle côté Tweak : l'éditeur des Prefs fait déjà la conversion.
static inline NSString *SIKeyItemEnabled(SIItemType t) { return [NSString stringWithFormat:@"%@_enabled", SIItemKey(t)]; }
static inline NSString *SIKeyItemX(SIItemType t)       { return [NSString stringWithFormat:@"%@_x", SIItemKey(t)]; }
static inline NSString *SIKeyItemY(SIItemType t)       { return [NSString stringWithFormat:@"%@_y", SIItemKey(t)]; }

// --- Compatibilité Slippery Batt --------------------------------------------------
// TODO (Matth) : remplace ces valeurs par le VRAI domaine + les VRAIES clés du plist
// de Slippery Batt, pour que le clone de batterie ci-dessous (dans Tweak.xm,
// méthode -tick) affiche exactement le même rendu (couleur unie / dégradé / mode
// éco / ≤20% / mode 3DS). Sans ça, la batterie reste en blanc simple pour l'instant.
static NSString * const SIBattDomain             = @"com.pizzasdu83.slipperybatt"; // à corriger si différent
static NSString * const SIBattKeyGradientEnabled = @"gradientEnabled";             // à corriger
static NSString * const SIBattKeySolidColor      = @"solidColor";                  // à corriger
static NSString * const SIBattKeyGradientColors  = @"gradientColors";             // à corriger

#endif
