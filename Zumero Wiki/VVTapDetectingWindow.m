// used to intercept taps on our Markdown-rendering web view, to catch
// links to other wiki pages
//
// based on code from http://mithin.in/2009/08/26/detecting-taps-and-events-on-uiwebview-the-right-way
//

#import "VVTapDetectingWindow.h"

@implementation VVTapDetectingWindow
@synthesize controllerThatObserves;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
		viewsToObserve = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) addObservedView:(UIView *)view
{
	if (! [viewsToObserve containsObject:view])
		[viewsToObserve addObject:view];
}

- (void)ignoreNextEvent
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)forwardTap:(id)view {
    [controllerThatObserves userDidTapView:view];
}

- (void)sendEvent:(UIEvent *)event
{
    [super sendEvent:event];

    if ([viewsToObserve count] == 0 || controllerThatObserves == nil)
        return;
    NSSet *touches = [event allTouches];
    if (touches.count != 1)
        return;
    UITouch *touch = touches.anyObject;
    if (touch.phase != UITouchPhaseEnded)
        return;
	
	UIView *view = nil;
	
	for ( UIView *v in viewsToObserve )
	{
		if ([touch.view isDescendantOfView:v])
		{
			view = v;
			break;
		}
	}
	
	if (! view)
        return;
	
    CGPoint tapPoint = [touch locationInView:view];
	
    NSArray *pointArray = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%f", tapPoint.x],
						   [NSString stringWithFormat:@"%f", tapPoint.y], nil];
    if (touch.tapCount == 1) {
        [self performSelector:@selector(forwardTap:) withObject:view afterDelay:0.5];
    }
    else if (touch.tapCount > 1) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(forwardTap:) object:pointArray];
    }
}

@end
