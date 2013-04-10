//
//  WikiPage.h
//
#import <Foundation/Foundation.h>

@interface WikiPage : NSObject

@property (strong, nonatomic) NSString *title;
@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSString *recid;
@property BOOL exists;
@property BOOL historical;

@end
