#import <UIKit/UIKit.h>
#import "SIPrefsBridge.h"

static NSMutableDictionary *SIPrefsCache = nil;

static void SILoadPrefs(void) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)SIPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keyList) {
        CFDictionaryRef values = CFPreferencesCopyMultiple(keyList, (CFStringRef)SIPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (values) {
            [dict addEntriesFromDictionary:(__bridge NSDictionary *)values];
            CFRelease(values);
        }
        CFRelease(keyList);
    }
    SIPrefsCache = dict;
}

static id SIPref(NSString *key, id fallback) {
    id v = SIPrefsCache[key];
    return v ?: fallback;
}

#pragma mark - Masquage (best-effort) de la status bar native
// ⚠️ Partie la plus fragile de tout le tweak : les classes privées SpringBoard
// changent d'une version d'iOS à l'autre. On masque la status bar native EN BLOC
// (plus fiable que de viser chaque icône une par une) via un pattern utilisé par
// plusieurs tweaks publics : SBStatusBarController sharedInstance -> statusBar.
// Le code est défensif (respondsToSelector partout) : si la classe/l'accesseur
// n'existent pas sur ton build d'iOS 26, il ne fait juste rien (pas de crash),
// et il faudra ajuster ce point précis une fois testé sur device.

static void SISetNativeStatusBarHidden(BOOL hidden) {
    Class cls = NSClassFromString(@"SBStatusBarController");
    if (!cls || ![cls respondsToSelector:@selector(sharedInstance)]) return;

    id controller = [cls performSelector:@selector(sharedInstance)];
    if (!controller || ![controller respondsToSelector:@selector(statusBar)]) return;

    id statusBar = [controller performSelector:@selector(statusBar)];
    if ([statusBar isKindOfClass:[UIView class]]) {
        [(UIView *)statusBar setAlpha:hidden ? 0.0 : 1.0];
    }
}

#pragma mark - Fenêtre overlay + icônes custom

@interface SIIconManager : NSObject
+ (instancetype)sharedInstance;
- (void)reload;
@end

@implementation SIIconManager {
    UIWindow *_overlayWindow;
    NSMutableDictionary<NSNumber *, UIView *> *_itemViews;
    NSTimer *_clockTimer;
}

+ (instancetype)sharedInstance {
    static SIIconManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _itemViews = [NSMutableDictionary dictionary];
        [self setupWindow];
        [self reload];
        _clockTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(tick)
                                                      userInfo:nil
                                                       repeats:YES];
    }
    return self;
}

- (void)setupWindow {
    _overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _overlayWindow.windowLevel = UIWindowLevelStatusBar + 1;
    _overlayWindow.userInteractionEnabled = NO;
    _overlayWindow.backgroundColor = [UIColor clearColor];
    _overlayWindow.rootViewController = [UIViewController new];
    _overlayWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
    _overlayWindow.hidden = NO;
}

- (UILabel *)freshLabel {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    l.textColor = [UIColor whiteColor];
    return l;
}

- (UIView *)makeViewForItem:(SIItemType)type {
    switch (type) {
        case SIItemBattery: {
            UILabel *l = [self freshLabel];
            l.text = @"100%";
            [l sizeToFit];
            return l;
        }
        case SIItemTime: {
            UILabel *l = [self freshLabel];
            l.text = @"--:--";
            [l sizeToFit];
            return l;
        }
        case SIItemWifi: {
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 18, 14)];
            iv.contentMode = UIViewContentModeScaleAspectFit;
            if (@available(iOS 13.0, *)) {
                iv.image = [UIImage systemImageNamed:@"wifi"];
            }
            iv.tintColor = [UIColor whiteColor];
            return iv;
        }
        case SIItemCellular: {
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 18, 14)];
            iv.contentMode = UIViewContentModeScaleAspectFit;
            if (@available(iOS 13.0, *)) {
                iv.image = [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
            }
            iv.tintColor = [UIColor whiteColor];
            return iv;
        }
        default:
            return [UIView new];
    }
}

- (void)reload {
    SILoadPrefs();
    BOOL globalEnabled = [SIPref(SIKeyEnabled, @NO) boolValue];

    SISetNativeStatusBarHidden(globalEnabled);
    _overlayWindow.hidden = !globalEnabled;
    if (!globalEnabled) return;

    for (NSInteger i = 0; i < SIItemCount; i++) {
        SIItemType type = (SIItemType)i;
        BOOL itemEnabled = [SIPref(SIKeyItemEnabled(type), @YES) boolValue];
        UIView *view = _itemViews[@(type)];

        if (itemEnabled && !view) {
            view = [self makeViewForItem:type];
            _itemViews[@(type)] = view;
            [_overlayWindow.rootViewController.view addSubview:view];
        } else if (!itemEnabled && view) {
            [view removeFromSuperview];
            [_itemViews removeObjectForKey:@(type)];
            view = nil;
        }

        if (view) {
            CGFloat x = [SIPref(SIKeyItemX(type), @40) doubleValue];
            CGFloat y = [SIPref(SIKeyItemY(type), @20) doubleValue];
            view.center = CGPointMake(x, y);
        }
    }
    [self tick];
}

- (void)tick {
    // Heure
    UIView *timeView = _itemViews[@(SIItemTime)];
    if ([timeView isKindOfClass:[UILabel class]]) {
        static NSDateFormatter *df;
        if (!df) { df = [NSDateFormatter new]; df.dateFormat = @"HH:mm"; }
        CGPoint center = timeView.center;
        ((UILabel *)timeView).text = [df stringFromDate:[NSDate date]];
        [timeView sizeToFit];
        timeView.center = center;
    }

    // Batterie
    UIView *battView = _itemViews[@(SIItemBattery)];
    if ([battView isKindOfClass:[UILabel class]]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        float level = [UIDevice currentDevice].batteryLevel;
        NSInteger pct = (level < 0) ? 100 : (NSInteger)round(level * 100);
        CGPoint center = battView.center;
        ((UILabel *)battView).text = [NSString stringWithFormat:@"%ld%%", (long)pct];
        // TODO : une fois les vraies clés Slippery Batt renseignées dans
        // SIPrefsBridge.h, lire SIBattDomain ici et appliquer la même couleur
        // (unie ou CAGradientLayer) que Slippery Batt sur ce label/cette vue.
        [battView sizeToFit];
        battView.center = center;
    }
}

@end

#pragma mark - Point d'entrée

static void SIReloadCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SIIconManager sharedInstance] reload];
    });
}

%ctor {
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            SIReloadCallback,
            (__bridge CFStringRef)SIReloadNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        dispatch_async(dispatch_get_main_queue(), ^{
            [SIIconManager sharedInstance];
        });
    }
}
