#import <Foundation/Foundation.h>

@class MdNode;

@interface VvMarkdown : NSObject

{
	NSUInteger rawLength;
	NSUInteger curPos;
	NSString *rawtext;
	MdNode *curnode;
	
	NSMutableDictionary *attDefs;
	
}

- (NSString *)convert:(NSString *)raw;
- (NSString *)convertsz:(const char *)raw;
- (UTF8Char)peek;
- (UTF8Char)get;
+ (NSInteger) indexOf:(NSString *)target str:(NSString *)str from:(NSInteger)from;
+ (NSString *)encode:(NSString *)text;

@end
