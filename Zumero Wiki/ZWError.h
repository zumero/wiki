//
//  ZWError.h
//  Zumero Wiki
//

#import <Foundation/Foundation.h>

@interface ZWError : NSObject

+ (void) reportError:(NSString *)title description:(NSString *)description error:(NSError *)err;

@end
