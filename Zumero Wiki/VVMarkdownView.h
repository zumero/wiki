#import <UIKit/UIKit.h>

@class VvMarkdown;
@class ZumeroDB;

@protocol VVMarkdownViewDelegate <NSObject>

- (void) wikiPageClicked:(NSString *)page;
- (BOOL) canLeave:(NSURL *)url;

@end

@interface VVMarkdownView : UIView <UIWebViewDelegate>
{
	VvMarkdown *my_converter;
	UIWebView *my_webview;
	NSMutableDictionary *my_images;
	NSString *my_font_desc;
	NSInteger my_margin;
	NSString *my_color;
	NSString *my_extracss;
	BOOL my_defer;
	NSString *my_text;
	BOOL my_rendered;
}

@property (retain, nonatomic) IBOutlet id<VVMarkdownViewDelegate> delegate;
@property (retain, nonatomic) ZumeroDB *db;

- (id)initWithFrameDeferred:(CGRect)frame deferred:(BOOL)deferred;
- (void) setRawText:(NSString *)text;
- (void)launchURL:(NSURL *)u;
- (void) setFont:(UIFont *)font;
- (void) setMargins:(NSUInteger)margin;
- (void) setColor:(UIColor *)color;
- (void) addFormat:(NSString *)css;
- (UIView *) webview;
- (void) render;

@end
