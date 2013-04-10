//
//  ZWError.m
//  Zumero Wiki
//

#import "ZWError.h"

@implementation ZWError

+ (void) reportError:(NSString *)title description:(NSString *)description error:(NSError *)err
{
	NSString *msg = description;
	
	if (err)
	{
		msg = [NSString stringWithFormat:@"%@:\n\n%@", description, [err description]];
	}
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
													message:msg
												   delegate:nil
										  cancelButtonTitle:@"OK"
										  otherButtonTitles:nil];
	[alert show];
}

@end
