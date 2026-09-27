#import "SlipperyIndicatorListController.h"
#import "SlipperyIndicatorEditViewController.h"

@implementation SlipperyIndicatorListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)openEditor {
    SlipperyIndicatorEditViewController *vc = [SlipperyIndicatorEditViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
