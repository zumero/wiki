//
//  ZWAppDelegate.h
//  Zumero Wiki
//

#import <UIKit/UIKit.h>
#import <Zumero/Zumero.h>

@interface ZWAppDelegate : UIApplication <UIApplicationDelegate, ZumeroDBDelegate>

- (void) waitForSync:(NSTimeInterval)secs;


@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) UINavigationController *navigationController;

@property (strong, nonatomic) UISplitViewController *splitViewController;

@end
