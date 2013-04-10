#import "VVMarkdownView.h"
#import "VvMarkdown.h"
#import <Zumero/Zumero.h>
#import "VVTapDetectingWindow.h"


@implementation VVMarkdownView 

- (id)initWithFrame:(CGRect)frame
{
	return [self initWithFrameDeferred:frame deferred:FALSE];
}

- (id)initWithFrameDeferred:(CGRect)frame deferred:(BOOL)deferred
{
	self = [super initWithFrame:frame];
    if (self) {
		my_converter = [[VvMarkdown alloc] init];
		my_images = [[NSMutableDictionary alloc] init];
		
		self.autoresizesSubviews = TRUE;
		
		my_margin = -1;
		my_font_desc = @"font-family:helvetica;";
		my_color = @"#000";
		my_extracss = @"";
		my_defer = deferred;
    }
    return self;

}

- (UIView *) webview
{
	return my_webview;
}

- (void) setTag:(NSInteger) tag
{
	[super setTag:tag];
	
	if (my_webview)
		[my_webview setTag:tag];
}

- (void) setRawText:(NSString *)text
{
	my_rendered = FALSE;
	
	my_text = [[NSString alloc] initWithString:text];
	
	if (! my_defer)
		[self render];
}

- (void) render
{
	if (! my_rendered)
	{
		my_rendered = TRUE;
		NSString *html = [my_converter convert:my_text];
		
		if (! my_webview)
		{
			my_webview = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
			my_webview.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
			my_webview.delegate = self;
			my_webview.userInteractionEnabled = TRUE;
			[my_webview setTag:self.tag];
			[self addSubview:my_webview];
		}
	
		[self begin_load_images:html];
	}
}

- (void) loadPreview:(NSString *)html
{
	NSString *header = [NSString stringWithFormat:@"<!DOCTYPE html>\n\n<html><head><title>wiki</title>"
	"<link rel='stylesheet' type='text/css' href='wiki.css' />"
	"<style>body,p,ul,ol,li{color:%@;%@}"
	"%@%@"
	"</style>"
	"</head><body>\n",
	my_color,
	my_font_desc,
	((my_margin >= 0) ? [NSString stringWithFormat:@"html{margin:0;padding:%i}body{margin:0;padding:0}", my_margin] : @""),
	my_extracss];
	NSString *footer = @"\n</body></html>";
	
	NSMutableString *st = [NSMutableString stringWithString:header];
	[st appendString:html];
	[st appendString:footer];
	
	NSURL *base = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
	
	[my_webview loadHTMLString:st baseURL:base];
}

- (void) begin_load_images:(NSString *)html
{
	[self performSelectorInBackground:@selector(bg_load_images:) withObject:html];
}
 
 - (void) bg_load_images:(NSString *)html
 {
	 NSMutableString *result = NULL;
 
	 NSError *err;
	 NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\bblob:///(.+?)\\.jpg\\b" options:0 error:&err];
	 NSArray *matches = [re matchesInString:html options:0 range:NSMakeRange(0, html.length)];
 
	 for (NSTextCheckingResult *match in matches)
	 {
		 NSRange r = [match rangeAtIndex:1];
		 NSString *st = [html substringWithRange:[match range]];
		 NSString *recid = [html substringWithRange:r];
 
		 if (! [my_images objectForKey:st])
		 {
			 BOOL ok = [self.db isOpen] || [self.db open:&err];
			 
			 if (ok)
			 {
				 NSError *err = nil;
				 NSString *data = [self blobImage:recid error:&err];
				 
				 [my_images setObject:data forKey:st];
			 }
		 }
	 }
 
	 result = [NSMutableString stringWithString:html];
 
	 for (NSString *key in my_images)
	 {
		 [result replaceOccurrencesOfString:key withString:[my_images objectForKey:key] options:0 range:NSMakeRange(0, result.length)];
	 }
 
 fail:

	 [self performSelectorOnMainThread:@selector(done_load_images:) withObject:result waitUntilDone:FALSE];
}

- (NSString*)base64forData:(NSData*)theData {
	
    const uint8_t* input = (const uint8_t*)[theData bytes];
    NSInteger length = [theData length];
	
	static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
	
	NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
	uint8_t* output = (uint8_t*)data.mutableBytes;
	
    NSInteger i;
	for (i=0; i < length; i += 3) {
		NSInteger value = 0;
        NSInteger j;
		for (j = i; j < (i + 3); j++) {
			value <<= 8;
			
			if (j < length) {
				value |= (0xFF & input[j]);
			}
		}
		
		NSInteger theIndex = (i / 3) * 4;
		output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
		output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
		output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
		output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
	}
	
	return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

- (NSString *)blobImage:(NSString *)recid error:(NSError **)err
{
	NSArray *rows = nil;
	NSString *result = @"";
	BOOL ok = [self.db select:@"blobs" criteria:@{ @"id" : recid } columns:@[@"data"] orderby:nil rows:&rows error:err];
	
	if (ok && ([rows count] == 1))
	{
		NSData *d = nil;
		
		NSDictionary *row = [rows objectAtIndex:0];
		
		d = [row objectForKey:@"data"];
		
		NSString *base64 = [self base64forData:d];
 
		result = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64];
	}
	
	return(result);
}


- (void) done_load_images:(NSString *)html
{
	[self loadPreview:html];
}


- (void)launchURL:(NSURL *)u
{
	if ([u.scheme isEqualToString:@"wiki"])
	{
		NSString *page = u.path;
		
		if ([page characterAtIndex:0] == '/')
			page = [page substringFromIndex:1];
		
		if (self.delegate)
			[self.delegate wikiPageClicked:page];
		
		[my_webview stopLoading];
	}
	else {
		[[UIApplication sharedApplication] openURL:u];
	}
}

- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
	
	if(navigationType == UIWebViewNavigationTypeLinkClicked) {
		
		VVTapDetectingWindow *win = (VVTapDetectingWindow *)[[UIApplication sharedApplication].windows objectAtIndex:0];
		[win ignoreNextEvent];
		
		NSURL *u = request.URL;
		
		if ((! self.delegate) || [self.delegate canLeave:u])
			[self launchURL:u];
		
		return NO;
	}
	
	return YES;
}

- (void) setFont:(UIFont *)font
{
	my_font_desc = [[NSString alloc] initWithFormat:@"font-family:%@;font-size:%ipt;", font.familyName, (int)((font.pointSize * 0.75) + 0.5)];
}
- (void) setMargins:(NSUInteger)margin
{
	my_margin = margin;
}

- (void) setColor:(UIColor *)color
{
	UIColor *_color = color;
	if (CGColorGetNumberOfComponents(_color.CGColor) < 4) {
		const CGFloat *components = CGColorGetComponents(_color.CGColor);
		_color = [UIColor colorWithRed:components[0] green:components[0] blue:components[0] alpha:components[1]];
	}
	if (CGColorSpaceGetModel(CGColorGetColorSpace(_color.CGColor)) != kCGColorSpaceModelRGB) {
		my_color = @"#FFFFFF";
	}
	
	my_color = [[NSString alloc] initWithFormat:@"#%02X%02X%02X", (int)((CGColorGetComponents(_color.CGColor))[0]*255.0), (int)((CGColorGetComponents(_color.CGColor))[1]*255.0), (int)((CGColorGetComponents(_color.CGColor))[2]*255.0)];
}
- (void) addFormat:(NSString *)css
{
	my_extracss = [[NSString alloc] initWithString:css];
}


@end
