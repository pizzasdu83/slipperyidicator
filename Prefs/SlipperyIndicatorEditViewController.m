#import "SlipperyIndicatorEditViewController.h"
#import "SIPrefsBridge.h"

#pragma mark - Helpers préférences

static id SIReadPref(NSString *key, id fallback) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)SIPrefsDomain);
    if (!value) return fallback;
    return CFBridgingRelease(value);
}

static void SIWritePref(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)SIPrefsDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)SIPrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                          (__bridge CFStringRef)SIReloadNotification,
                                          NULL, NULL, YES);
}

@interface SlipperyIndicatorEditViewController () <UITextFieldDelegate>
@end

@implementation SlipperyIndicatorEditViewController {
    UIScrollView *_scrollView;
    UIView *_canvasView;
    UIView *_bubbleLayer;
    NSMutableDictionary<NSNumber *, UIView *> *_chips;
    UIImage *_bubbleImage;
    CFAbsoluteTime _lastSpawn;

    CGFloat _screenW;
    CGFloat _screenH;
    CGFloat _scale;

    SIItemType _selectedType;
    BOOL _hasSelection;

    UILabel *_selectedLabel;
    UISwitch *_itemSwitch;
    UISlider *_xSlider;
    UISlider *_ySlider;
    UITextField *_xField;
    UITextField *_yField;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Positions";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    _chips = [NSMutableDictionary dictionary];
    _hasSelection = NO;

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    _screenW = screenBounds.size.width;
    _screenH = screenBounds.size.height;

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    _bubbleImage = [UIImage imageNamed:@"bubble" inBundle:bundle compatibleWithTraitCollection:nil];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    [self buildCanvas];
    [self buildControlsPanel];
    [self loadChipsFromPrefs];
}

#pragma mark - Canvas (représentation de l'écran)

- (void)buildCanvas {
    CGFloat canvasWidth = MIN(300.0, self.view.bounds.size.width - 32.0);
    _scale = canvasWidth / _screenW;
    CGFloat canvasHeight = _screenH * _scale;

    _canvasView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - canvasWidth) / 2.0,
                                                             24.0, canvasWidth, canvasHeight)];
    _canvasView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _canvasView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    _canvasView.layer.cornerRadius = 22.0;
    _canvasView.layer.borderWidth = 1.0;
    _canvasView.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.3].CGColor;
    _canvasView.clipsToBounds = YES;
    [_scrollView addSubview:_canvasView];

    _bubbleLayer = [[UIView alloc] initWithFrame:_canvasView.bounds];
    _bubbleLayer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _bubbleLayer.userInteractionEnabled = NO;
    [_canvasView addSubview:_bubbleLayer];

    for (NSInteger i = 0; i < SIItemCount; i++) {
        [self addChipForType:(SIItemType)i];
    }
}

- (void)addChipForType:(SIItemType)type {
    UILabel *chip = [[UILabel alloc] initWithFrame:CGRectZero];
    chip.text = SIItemLabel(type);
    chip.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    chip.textColor = [UIColor whiteColor];
    chip.textAlignment = NSTextAlignmentCenter;
    chip.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    chip.layer.cornerRadius = 10.0;
    chip.layer.masksToBounds = YES;
    chip.userInteractionEnabled = YES;
    chip.tag = type;
    [chip sizeToFit];
    chip.frame = CGRectInset(chip.frame, -8.0, -4.0);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [chip addGestureRecognizer:pan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [chip addGestureRecognizer:tap];

    [_canvasView addSubview:chip];
    _chips[@(type)] = chip;
}

- (void)loadChipsFromPrefs {
    for (NSInteger i = 0; i < SIItemCount; i++) {
        SIItemType type = (SIItemType)i;
        UIView *chip = _chips[@(type)];
        CGFloat x = [SIReadPref(SIKeyItemX(type), @40) doubleValue];
        CGFloat y = [SIReadPref(SIKeyItemY(type), @20) doubleValue];
        chip.center = CGPointMake(x * _scale, y * _scale);
        [self applyEnabledStyleToChipForType:type];
    }
    [self selectType:SIItemBattery];
}

- (void)applyEnabledStyleToChipForType:(SIItemType)type {
    BOOL enabled = [SIReadPref(SIKeyItemEnabled(type), @YES) boolValue];
    _chips[@(type)].alpha = enabled ? 1.0 : 0.35;
}

#pragma mark - Panneau de contrôle (sliders + champs px)

- (void)buildControlsPanel {
    CGFloat top = 24.0 + (_screenH * _scale) + 20.0;
    CGFloat margin = 20.0;
    CGFloat width = self.view.bounds.size.width - margin * 2;

    _selectedLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, top, width - 60, 24)];
    _selectedLabel.font = [UIFont boldSystemFontOfSize:16];
    [_scrollView addSubview:_selectedLabel];

    _itemSwitch = [[UISwitch alloc] init];
    _itemSwitch.frame = CGRectMake(self.view.bounds.size.width - margin - 51, top - 4, 51, 31);
    [_itemSwitch addTarget:self action:@selector(itemSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_itemSwitch];

    top += 40;

    UILabel *xLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, top, 20, 30)];
    xLabel.text = @"X";
    xLabel.font = [UIFont boldSystemFontOfSize:14];
    [_scrollView addSubview:xLabel];

    _xSlider = [[UISlider alloc] initWithFrame:CGRectMake(margin + 26, top, width - 26 - 74, 30)];
    _xSlider.minimumValue = 0;
    _xSlider.maximumValue = _screenW;
    [_xSlider addTarget:self action:@selector(xSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_xSlider];

    _xField = [self makePxFieldAtX:margin + width - 64 top:top];
    [_scrollView addSubview:_xField];

    top += 44;

    UILabel *yLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, top, 20, 30)];
    yLabel.text = @"Y";
    yLabel.font = [UIFont boldSystemFontOfSize:14];
    [_scrollView addSubview:yLabel];

    _ySlider = [[UISlider alloc] initWithFrame:CGRectMake(margin + 26, top, width - 26 - 74, 30)];
    _ySlider.minimumValue = 0;
    _ySlider.maximumValue = _screenH;
    [_ySlider addTarget:self action:@selector(ySliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_ySlider];

    _yField = [self makePxFieldAtX:margin + width - 64 top:top];
    [_scrollView addSubview:_yField];

    top += 50;
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(margin, top, width, 40)];
    hint.numberOfLines = 0;
    hint.font = [UIFont systemFontOfSize:12];
    hint.textColor = [UIColor secondaryLabelColor];
    hint.text = @"Glisse un élément dans l'aperçu ci-dessus, ou choisis-le puis ajuste sa position au pixel près avec les curseurs.";
    [_scrollView addSubview:hint];

    CGFloat contentHeight = top + 40 + 24.0;
    _scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, contentHeight);
}

- (UITextField *)makePxFieldAtX:(CGFloat)x top:(CGFloat)top {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(x, top, 60, 30)];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.textAlignment = NSTextAlignmentCenter;
    field.delegate = self;
    return field;
}

#pragma mark - Sélection

- (void)selectType:(SIItemType)type {
    _selectedType = type;
    _hasSelection = YES;
    _selectedLabel.text = SIItemLabel(type);
    _itemSwitch.on = [SIReadPref(SIKeyItemEnabled(type), @YES) boolValue];

    UIView *chip = _chips[@(type)];
    CGFloat realX = chip.center.x / _scale;
    CGFloat realY = chip.center.y / _scale;
    _xSlider.value = realX;
    _ySlider.value = realY;
    _xField.text = [NSString stringWithFormat:@"%.0f", realX];
    _yField.text = [NSString stringWithFormat:@"%.0f", realY];

    for (UIView *c in _chips.allValues) c.layer.borderWidth = 0;
    chip.layer.borderWidth = 2.0;
    chip.layer.borderColor = [UIColor systemPurpleColor].CGColor;
}

- (void)handleTap:(UITapGestureRecognizer *)gr {
    [self selectType:(SIItemType)gr.view.tag];
}

#pragma mark - Glisser-déposer + traînée de bulles

- (void)handlePan:(UIPanGestureRecognizer *)gr {
    UIView *chip = gr.view;
    SIItemType type = (SIItemType)chip.tag;

    CGPoint translation = [gr translationInView:_canvasView];
    CGPoint newCenter = CGPointMake(chip.center.x + translation.x, chip.center.y + translation.y);

    CGFloat halfW = chip.bounds.size.width / 2.0;
    CGFloat halfH = chip.bounds.size.height / 2.0;
    newCenter.x = MAX(halfW, MIN(newCenter.x, _canvasView.bounds.size.width - halfW));
    newCenter.y = MAX(halfH, MIN(newCenter.y, _canvasView.bounds.size.height - halfH));
    chip.center = newCenter;
    [gr setTranslation:CGPointZero inView:_canvasView];

    if (_selectedType != type || !_hasSelection) {
        [self selectType:type];
    } else {
        CGFloat realX = newCenter.x / _scale;
        CGFloat realY = newCenter.y / _scale;
        _xSlider.value = realX;
        _ySlider.value = realY;
        _xField.text = [NSString stringWithFormat:@"%.0f", realX];
        _yField.text = [NSString stringWithFormat:@"%.0f", realY];
    }

    [self spawnBubbleAt:newCenter];

    if (gr.state == UIGestureRecognizerStateEnded || gr.state == UIGestureRecognizerStateCancelled) {
        [self persistPositionForType:type center:newCenter];
    }
}

- (void)spawnBubbleAt:(CGPoint)point {
    if (!_bubbleImage) return;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - _lastSpawn < 0.016) return;
    _lastSpawn = now;

    CGFloat size = 5.0 + (arc4random_uniform(90) / 10.0); // 5..14 px
    CGFloat jitterX = ((arc4random_uniform(140) / 10.0) - 7.0);
    CGFloat jitterY = ((arc4random_uniform(140) / 10.0) - 7.0);
    CGFloat rotation = (((arc4random_uniform(400) / 10.0) - 20.0)) * M_PI / 180.0;

    UIImageView *bubble = [[UIImageView alloc] initWithImage:_bubbleImage];
    bubble.frame = CGRectMake(0, 0, size, size);
    bubble.center = CGPointMake(point.x + jitterX, point.y + jitterY);
    bubble.alpha = 0.0;
    bubble.transform = CGAffineTransformMakeScale(0.3, 0.3);
    [_bubbleLayer addSubview:bubble];

    [UIView animateWithDuration:0.12 animations:^{
        bubble.alpha = 0.95;
        bubble.transform = CGAffineTransformMakeRotation(rotation);
    }];

    double life = 0.12 + ((arc4random_uniform(100) / 1000.0)); // 0.12..0.22s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, life * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.22 animations:^{
            bubble.alpha = 0.0;
            bubble.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(rotation), 0.25, 0.25);
        } completion:^(BOOL finished) {
            [bubble removeFromSuperview];
        }];
    });
}

#pragma mark - Sliders / champs / switch

- (void)xSliderChanged:(UISlider *)sender {
    if (!_hasSelection) return;
    _xField.text = [NSString stringWithFormat:@"%.0f", sender.value];
    [self moveSelectedChipToRealX:sender.value y:_ySlider.value fromInteraction:YES];
}

- (void)ySliderChanged:(UISlider *)sender {
    if (!_hasSelection) return;
    _yField.text = [NSString stringWithFormat:@"%.0f", sender.value];
    [self moveSelectedChipToRealX:_xSlider.value y:sender.value fromInteraction:YES];
}

- (void)moveSelectedChipToRealX:(CGFloat)x y:(CGFloat)y fromInteraction:(BOOL)interactive {
    UIView *chip = _chips[@(_selectedType)];
    CGPoint center = CGPointMake(x * _scale, y * _scale);
    chip.center = center;
    if (interactive) [self spawnBubbleAt:center];
    [self persistPositionForType:_selectedType center:center];
}

- (void)itemSwitchChanged:(UISwitch *)sender {
    if (!_hasSelection) return;
    SIWritePref(SIKeyItemEnabled(_selectedType), @(sender.on));
    [self applyEnabledStyleToChipForType:_selectedType];
}

- (void)persistPositionForType:(SIItemType)type center:(CGPoint)center {
    CGFloat realX = center.x / _scale;
    CGFloat realY = center.y / _scale;
    SIWritePref(SIKeyItemX(type), @(realX));
    SIWritePref(SIKeyItemY(type), @(realY));
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (!_hasSelection) return;
    CGFloat maxX = _screenW, maxY = _screenH;
    if (textField == _xField) {
        CGFloat v = MAX(0, MIN(_xField.text.doubleValue, maxX));
        _xSlider.value = v;
        _xField.text = [NSString stringWithFormat:@"%.0f", v];
        [self moveSelectedChipToRealX:v y:_ySlider.value fromInteraction:NO];
    } else if (textField == _yField) {
        CGFloat v = MAX(0, MIN(_yField.text.doubleValue, maxY));
        _ySlider.value = v;
        _yField.text = [NSString stringWithFormat:@"%.0f", v];
        [self moveSelectedChipToRealX:_xSlider.value y:v fromInteraction:NO];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
