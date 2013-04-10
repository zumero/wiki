//
//  ZWConfig.h
//  Zumero Wiki
//

#import <Foundation/Foundation.h>

@interface ZWConfig : NSObject

+ (NSString *)dbpath;
+ (NSString *)dbname;
+ (NSString *)server;
+ (NSString *)username;
+ (NSString *)password;
+ (NSDictionary *)scheme;

@end
