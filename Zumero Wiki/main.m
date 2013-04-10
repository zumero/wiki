//
//  main.m
//  Zumero Wiki
//

#import <UIKit/UIKit.h>

#import "ZWAppDelegate.h"

int main(int argc, char *argv[])
{
	@autoreleasepool {
		NSString *cname = NSStringFromClass([ZWAppDelegate class]);
	    return UIApplicationMain(argc, argv, cname, cname);
	}
}
