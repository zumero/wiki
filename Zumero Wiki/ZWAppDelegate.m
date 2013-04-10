//
//  ZWAppDelegate.m
//  Zumero Wiki application setup and background sync
//

#import "ZWAppDelegate.h"

#import "ZWMasterViewController.h"
#import "ZWError.h"
#import "ZWDetailViewController.h"
#import "VVTapDetectingWindow.h"

#import <AssetsLibrary/AssetsLibrary.h>

@interface ZWAppDelegate() {
	NSTimer *idleTimer;
	NSTimeInterval maxIdleTime;
	BOOL wantToSync;
	NSDate *nextSync;
	ZWMasterViewController *mvc;
}
@end

@implementation ZWAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[VVTapDetectingWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	ZWMasterViewController *masterViewController = nil;
	
	[self setStatusBarHidden:NO];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	    masterViewController = [[ZWMasterViewController alloc] initWithNibName:@"ZWMasterViewController_iPhone" bundle:nil];
	    self.navigationController = [[UINavigationController alloc] initWithRootViewController:masterViewController];
	    self.window.rootViewController = self.navigationController;
	} else {
	    masterViewController = [[ZWMasterViewController alloc] initWithNibName:@"ZWMasterViewController_iPad" bundle:nil];
	    UINavigationController *masterNavigationController = [[UINavigationController alloc] initWithRootViewController:masterViewController];
	    
	    ZWDetailViewController *detailViewController = [[ZWDetailViewController alloc] initWithNibName:@"ZWDetailViewController_iPad" bundle:nil];
	    UINavigationController *detailNavigationController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
		
		masterViewController.detailViewController = detailViewController;
		detailViewController.masterViewController = masterViewController;
		
	    self.splitViewController = [[UISplitViewController alloc] init];
	    self.splitViewController.delegate = detailViewController;
	    self.splitViewController.viewControllers = @[masterNavigationController, detailNavigationController];
	    
	    self.window.rootViewController = self.splitViewController;
	}
	
	// force a Photo permissions prompt, if needed, so we can
	// later select images for wiki insertion
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	
	ALAssetsLibraryGroupsEnumerationResultsBlock assetGroupEnumerator =
	^(ALAssetsGroup *assetGroup, BOOL *stop) {
		if (assetGroup != nil) {
		}
	};
	
	ALAssetsLibraryAccessFailureBlock assetFailureBlock = ^(NSError *error) {
		
	};
	
	NSUInteger groupTypes = ALAssetsGroupAll;
	
	[library enumerateGroupsWithTypes:groupTypes usingBlock:assetGroupEnumerator failureBlock:assetFailureBlock];
	
	mvc = masterViewController;
	maxIdleTime = 5;

    [self.window makeKeyAndVisible];
	[mvc sync:self];
    return YES;
}

#pragma mark sync

// kill off out sync timer when going inactive
- (void)killTimers
{
	self.networkActivityIndicatorVisible = NO;
	
	if (idleTimer) {
        [idleTimer invalidate];
		idleTimer = nil;
    }
}

// restart sync timers when waking up
- (void)startTimers
{
	self.networkActivityIndicatorVisible = NO;

	if (! idleTimer) {
        [self resetIdleTimer:30];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	[self killTimers];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[self killTimers];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	[self startTimers];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[self startTimers];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[self killTimers];
}

// we're simulating an idle timer -- waiting for a few seconds with no touch activity
//
- (void)sendEvent:(UIEvent *)event {
    [super sendEvent:event];
	
    // Only want to reset the timer on a Began touch or an Ended touch, to reduce the number of timer resets.
    NSSet *allTouches = [event allTouches];
    if ([allTouches count] > 0) {
        // allTouches count only ever seems to be 1, so anyObject works here.
        UITouchPhase phase = ((UITouch *)[allTouches anyObject]).phase;
        if (phase == UITouchPhaseBegan || phase == UITouchPhaseEnded)
            [self resetIdleTimer:maxIdleTime];
    }
}

- (void)resetIdleTimer:(NSTimeInterval)secs
{
    if (idleTimer) {
        [idleTimer invalidate];
		idleTimer = nil;
    }
	
    idleTimer = [NSTimer scheduledTimerWithTimeInterval:secs target:self selector:@selector(idleTimerExceeded) userInfo:nil repeats:NO];
}

// we've found an idle moment. Is it time to sync?
//
- (void)idleTimerExceeded {
	// Has anyone asked us to sync?
	//
	if (wantToSync)
	{
		NSTimeInterval since = [nextSync timeIntervalSinceNow];
	
		// is it time yet?
		if (since <= 0)
		{
			wantToSync = FALSE;
		
			BOOL ok = FALSE;
		
			// kick off a zumero background sync
			// this class will be the ZumeroDBDelegate, so our syncFail/syncSuccess routines
			// will be called as necessary 
			if (mvc)
				ok = [mvc sync:self];   
		
			if (ok)
				self.networkActivityIndicatorVisible = YES;
			else
				// the sync call failed; try again later
				[self waitForSync:(10 * 60)];
		}
		else
		{
			// nope, check again next idle time
			[self resetIdleTimer:since];
		}
		
		return;
	}
	
	[self resetIdleTimer:maxIdleTime];
}

// note that we want to sync, and how soon.
// If we're already waiting, the nearest time wins.
//
- (void) waitForSync:(NSTimeInterval)secs
{
	if (! wantToSync)
	{
		nextSync = [NSDate dateWithTimeIntervalSinceNow:secs];
		wantToSync = TRUE;
	}
	else
	{
		NSDate *syncTime = [NSDate dateWithTimeIntervalSinceNow:secs];

		NSComparisonResult comp = [syncTime compare:nextSync];
		
		if (comp == NSOrderedAscending) // sooner?
			nextSync = syncTime;
	}
	
	[self resetIdleTimer:maxIdleTime];
}

// Our sync call started, but failed for some reason.
// Uncomment the ZWError to receive in-app popups about this.
//
- (void) syncFail:(NSString *)dbname err:(NSError *)err
{
//	[ZWError reportError:@"sync failed" description:@"Zumero sync failed" error:err];
	self.networkActivityIndicatorVisible = NO;
	[self waitForSync:(10 * 60)];
}

// The sync succeeded.  Schedule another one for later, reload our page list.
//
- (void) syncSuccess:(NSString *)dbname
{
	[self waitForSync:(5 * 60)];
	self.networkActivityIndicatorVisible = NO;
	[mvc loadPages];
}

@end
