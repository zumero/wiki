// used to intercept taps on our Markdown-rendering web view, to catch
// links to other wiki pages
//
// based on code from http://mithin.in/2009/08/26/detecting-taps-and-events-on-uiwebview-the-right-way
//

#import <UIKit/UIKit.h>

@protocol TapDetectingWindowDelegate
- (void)userDidTapView:(id)tapPoint;
@end

@interface VVTapDetectingWindow : UIWindow {
	NSMutableArray *viewsToObserve;
    __weak id <TapDetectingWindowDelegate> controllerThatObserves;
}

@property (nonatomic, weak) id <TapDetectingWindowDelegate> controllerThatObserves;

- (void) addObservedView:(UIView *)view;
- (void)ignoreNextEvent;
@end
