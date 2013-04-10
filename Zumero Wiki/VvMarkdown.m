#import "VvMarkdown.h"

@interface MdNode : NSObject
{
	BOOL isBlock;
	BOOL isText;
	NSString *tagname;
	NSMutableArray *attributes;
	NSMutableArray *children;
	NSMutableString *contents;
	MdNode *curChild;
	NSString *singleTextAtt;
}
@end

@interface MdAttLookup: NSObject
{
	NSString *value;
	NSString *text;
}
@end

@interface MdAttribute : NSObject
{
	NSString *name;
	NSString *value;
	NSString *key;
	BOOL incomplete;
}

- (const char *) namesz;
- (const char *) valuesz:(NSDictionary *)defs;
+ (id) attWithValue:(NSString *)vari value:(NSString *)val;

@end

@implementation MdAttLookup

- (id) init:(NSString *)val title:(NSString *)title
{
	value = val;
	text = title;
	
	return self;
}

- (NSString *) val
{
	return value;
}

- (NSString *) title
{
	return text;
}

@end

@implementation MdNode

+ (id) node:(BOOL)block
{
	MdNode *n = [[MdNode alloc] init];
	
	n->contents = [NSMutableString string];
	n->attributes = [NSMutableArray array];
	n->children = [NSMutableArray array];
	n->isBlock = block;
	n->curChild = nil;
	n->singleTextAtt = nil;
	
	return n;
}

+ (id) textNode
{
	MdNode *n = [[MdNode alloc] init];
	
	n->contents = [NSMutableString string];
	n->attributes = [NSMutableArray array];
	n->children = [NSMutableArray array];
	n->isBlock = FALSE;
	n->isText = TRUE;
	n->curChild = nil;
	
	return n;
}


- (void) prependChar:(UTF8Char) ch
{
	if (isText)
		[contents insertString:[NSString stringWithFormat:@"%c", ch] atIndex:0];
	else
	{
		MdNode *child = [MdNode textNode];
		[child appendChar:ch];
		[children insertObject:child atIndex:0];
	}
}

- (void) prependStr:(NSString *)st
{
	if (isText)
		[contents insertString:st atIndex:0];
	else
	{
		MdNode *child = [MdNode textNode];
		[child appendString:st];
		[children insertObject:child atIndex:0];
	}
}

- (void) appendChar:(UTF8Char)ch
{
	[self appendString:[NSString stringWithFormat:@"%c", ch]];
}

- (void) appendString:(NSString *)st
{
	if (isText)
		[contents appendString:st];
	else 
	{
		if (! curChild)
		{
			curChild = [MdNode textNode];
			[children addObject:curChild];
		}
		[curChild appendString:st];
	}
}

- (void) appendChild:(MdNode *)child
{
	[children addObject:child];
	curChild = nil;
}

- (void) appendAttribute:(MdAttribute *)att
{
	[attributes addObject:att];
}

- (void) setAttr:(NSString *)name value:(NSString *)value
{
	MdAttribute *att = [MdAttribute attWithValue:name value:value];
	[self appendAttribute:att];
}

- (NSString *)innerText:(NSDictionary *)defs
{
	NSError *err;
	
	if (contents && contents.length)
	{
		NSInteger rest = 0;
		NSInteger pos;
		NSMutableString *result = [NSMutableString string];
		
		NSString *t = [VvMarkdown encode:contents];
		
		NSUInteger len = t.length;
		rest = 0;
		
		while ((pos = [VvMarkdown indexOf:@"<" str:t from:rest]) >= 0)
		{
			if (pos > rest)
				[result appendString:[t substringWithRange:NSMakeRange(rest, pos - rest)]];
			
			NSRegularExpression *autolink = [NSRegularExpression regularExpressionWithPattern:@"<(https?://[^ \t\n<>]+)>" options:0 error:&err];
			NSRegularExpression *tag = [NSRegularExpression regularExpressionWithPattern:@"(</?[^<]+?>)" options:0 error:&err];

			NSArray *matchesal = [autolink matchesInString:t options:NSMatchingAnchored range:NSMakeRange(pos, len - pos)];
			NSArray *matches = nil;
			
			if ((! matchesal) || ([matchesal count] < 1))
				matches = [tag matchesInString:t options:NSMatchingAnchored range:NSMakeRange(pos, len - pos)];
			
			if (matches && ([matches count] > 0))
			{
				NSTextCheckingResult *m = (NSTextCheckingResult *)[matches objectAtIndex:0];
				
				[result appendString:[t substringWithRange:NSMakeRange(pos, m.range.length)]];
				rest = pos + m.range.length;
			}
			else 
			{
				[result appendString:@"&lt;"];
				rest = pos + 1;
			}
		}
		
		if (rest < len)
			[result appendString:[t substringWithRange:NSMakeRange(rest, len - rest)]];

		return result;
	}
	
	NSMutableString *text = [NSMutableString string];
	
	for ( int i = 0; i < [children count]; ++i )
	{
		MdNode *node = [children objectAtIndex:i];
		
		NSString *ts = [node toString:defs];
		
		if (ts)
			[text appendString:ts];
	}
	
	return text;
}

- (NSString *)toString:(NSDictionary *)defs
{
	if ((! contents.length) && (! [children count]) && ! tagname)
		return nil;
	
	NSMutableString *attstr = [NSMutableString string];
	
	for ( int i = 0; i < [attributes count]; ++i )
	{
		MdAttribute *att = (MdAttribute *)[attributes objectAtIndex:i];
		[attstr appendFormat:@" %s=\"%s\"", [att namesz], [att valuesz:defs]];
	}
	
	const char *atts = [attstr UTF8String];
	
	if (isBlock)
	{
		const char *tag = tagname ? [tagname UTF8String] : "p";
		
		return [NSString stringWithFormat:@"<%s%s>%@</%s>", tag, atts, [self innerText:defs], tag];
	}
	else if (singleTextAtt)
	{
		const char *tag = [tagname UTF8String];
		
		return [NSString stringWithFormat:@"<%s%s %@=\"%@\" />", tag, atts, singleTextAtt, [self innerText:defs]];
	}
	else
	{
		const char *tag = tagname ? [tagname UTF8String] : NULL;
		
		if (tag)
		{
			NSString *inner = [self innerText:defs];
			BOOL empty = (! inner) || (inner.length == 0);
			BOOL doSingle = FALSE;
			
			if (empty)
				doSingle = (strcasecmp(tag, "br") == 0) || (strcasecmp(tag, "hr") == 0);
			
			if (doSingle)
				return [NSString stringWithFormat:@"<%s%s />", tag, atts];
			else
				return [NSString stringWithFormat:@"<%s%s>%@</%s>", tag, atts, inner, tag];
		}
		else
			return [self innerText:defs];
	}
}


- (void) setSingle:(NSString *)singleAtt
{
	singleTextAtt = singleAtt;
}

- (void) setTag:(NSString *)tag
{
	tagname = tag;
}

- (NSString *) getTag
{
	return tagname;
}

- (void) setIsText:(BOOL)istext
{
	isText = istext;
}

- (void) trim:(char)ch
{
	if (contents && contents.length)
	{
		while (contents.length && ([contents characterAtIndex:(contents.length - 1)] == ch))
			[contents deleteCharactersInRange:NSMakeRange(contents.length - 1, 1)];
	
		while (contents.length && isspace([contents characterAtIndex:(contents.length - 1)]))
			[contents deleteCharactersInRange:NSMakeRange(contents.length - 1, 1)];
	}
	else if (children && ([children count] == 1))
	{
		MdNode *child = [children objectAtIndex:0];
		[child trim:ch];
	}
}

@end

@implementation MdAttribute

+ (id) attWithValue:(NSString *)vari value:(NSString *)val
{
	MdAttribute *a = [[MdAttribute alloc] init];
	
	a->name = [NSString stringWithString:vari];
	a->value = [NSString stringWithString:val];
	a->incomplete = FALSE;
	a->key = nil;
	
	return a;
}

+ (id) attWithKey:(NSString *)vari keytag:(NSString *)keytag
{
	MdAttribute *a = [[MdAttribute alloc] init];
	
	a->name = [NSString stringWithString:vari];
	a->value = @"";
	a->key = [NSString stringWithString:keytag];
	a->incomplete = TRUE;

	return a;
}

- (const char *) namesz
{
	return [name UTF8String];
}

+ (NSString *) vvImage:(NSString *)result
{
	NSError *err;
	
	NSRegularExpression *blobre = [NSRegularExpression regularExpressionWithPattern:@"^/repos/(.+?)/wiki/image/([a-z0-9]+)/" options:0 error:&err];

	NSArray *matches = [blobre matchesInString:result options:0 range:NSMakeRange(0, result.length)];
	
	if (matches && ([matches count] > 0))
	{
		NSTextCheckingResult *match = (NSTextCheckingResult *)[matches objectAtIndex:0];
		
		NSString *repoName = [result substringWithRange:[match rangeAtIndex:1]];
		NSString *hid = [result substringWithRange:[match rangeAtIndex:2]];
		
		result = [NSString stringWithFormat:@"VVIMAGE:%@:%@", repoName, hid];
	}

	return( result );
}

- (NSString *) unbracket:(NSString *)raw
{
	NSInteger len = raw.length;

	if ((len >= 2) && ([raw characterAtIndex:0] == '<') && ([raw characterAtIndex:(len - 1)] == '>'))
	{
		return [raw substringWithRange:NSMakeRange(1, len - 2)];
	}
	
	return raw;
}

- (const char *) valuesz:(NSDictionary *)defs
{
	NSString *result = value;
	
	if (incomplete)
	{
		MdAttLookup *lo = [defs objectForKey:key];
		
		if (lo)
		{
			result = [lo val];
			value = result;
			incomplete = FALSE;
		}
		else
			result = [NSString stringWithFormat:@"{{{LINKFIX:%@}}}", key];
	}
	else 
	{
		result = [MdAttribute vvImage:result];
	}
	
	result = [self unbracket:result];
	
	return [[VvMarkdown encode:result] UTF8String];
}

@end


@implementation VvMarkdown

static BOOL reReady = FALSE;

NSRegularExpression *olre;
NSRegularExpression *ulre;
NSRegularExpression *linkdef;
NSRegularExpression *quotedlinkdef;
NSRegularExpression *witlink;
NSRegularExpression *cslink;
NSRegularExpression *bqlead;
NSRegularExpression *autolink;
NSRegularExpression *brline;
NSRegularExpression *hr;
NSRegularExpression *liststart;
NSRegularExpression *olLeaderRe;
NSRegularExpression *codeline;
NSRegularExpression *paraline;
NSRegularExpression *paralead;
NSRegularExpression *blankline;
NSRegularExpression *h1;
NSRegularExpression *h2;
NSRegularExpression *crlf;
NSRegularExpression *linktitle;

- (id) init
{
	self = [super init];
	
	rawtext = nil;
	attDefs = [[NSMutableDictionary alloc] init];
	NSError *reErr;
	
	if (! reReady)
	{
		olLeaderRe = [NSRegularExpression regularExpressionWithPattern:@"^\\s{0,3}\\d+\\.\\s+" options:0 error:&reErr];
	
		olre = [NSRegularExpression regularExpressionWithPattern:@"^\\s*\\d+\\.\\s+" options:0 error:&reErr] ;
		ulre = [NSRegularExpression regularExpressionWithPattern:@"^\\s*[\\+\\-\\*]\\s+" options:0 error:&reErr] ;
		linkdef = [NSRegularExpression
					regularExpressionWithPattern:@"^[ \t]*\\[([0-9a-z]+)\\]:[ \t]*(\\S+)[ \t]*(\".+\")?"
					options:(NSRegularExpressionCaseInsensitive + NSRegularExpressionAnchorsMatchLines)
					error:&reErr] ;
		quotedlinkdef = [NSRegularExpression
						  regularExpressionWithPattern:@"^[ \t]*\\[([0-9a-z]+)\\]:[ \t]*((?:tag|branch)://\"[^\"]+\")[ \t]*(\".+\")?"
						  options:(NSRegularExpressionCaseInsensitive + NSRegularExpressionAnchorsMatchLines)
						  error:&reErr] ;
		bqlead = [NSRegularExpression regularExpressionWithPattern:@">(\\s+.*|$)" options:0 error:&reErr] ;
		autolink = [NSRegularExpression regularExpressionWithPattern:@"<(https?://[^ \t\n<>]+)>" options:0 error:&reErr] ;
		brline = [NSRegularExpression regularExpressionWithPattern:@".*  $" options:0 error:&reErr] ;
		hr = [NSRegularExpression regularExpressionWithPattern:@"^\\s*(-\\s*-\\s*-(?:[ \t\\-]*)|_\\s*_\\s*_(?:[ \t_]*)|\\*\\s*\\*\\s*\\*(?:[ \t\\*]*))$" options:0 error:&reErr] ;
		liststart = [NSRegularExpression regularExpressionWithPattern:@"^\\s*([\\-\\*\\+])\\s+" options:0 error:&reErr] ;
		codeline = [NSRegularExpression regularExpressionWithPattern:@"^    (.*)" options:0 error:&reErr] ;
		paralead = [NSRegularExpression regularExpressionWithPattern:@".*\\S" options:0 error:&reErr] ;
		paraline = [NSRegularExpression regularExpressionWithPattern:@".*[^ \t\\-=]" options:0 error:&reErr] ;
		blankline = [NSRegularExpression regularExpressionWithPattern:@"^\\s*$" options:0 error:&reErr] ;
		h1 = [NSRegularExpression regularExpressionWithPattern:@"^=+\\s*$" options:0 error:&reErr] ;
		h2 = [NSRegularExpression regularExpressionWithPattern:@"^-+\\s*$" options:0 error:&reErr] ;
		crlf = [NSRegularExpression regularExpressionWithPattern:@"\r\n" options:0 error:&reErr] ;
		linktitle = [NSRegularExpression regularExpressionWithPattern:@"^\\s*(.+?)\\s+\"(.+)\"\\s*$" options:0 error:&reErr] ;
		
		reReady = TRUE;
	}

	return self;
}

+ (NSInteger) indexOf:(NSString *)target str:(NSString *)str from:(NSInteger)from
{
	NSRange area = NSMakeRange(from, str.length - from);
	
	NSRange result = [str rangeOfString:target options:0 range:area];
	
	if (result.length <= 0)
		return -1;
	
	return result.location;
}

+ (NSString *)encode:(NSString *)text
{
	NSUInteger len = text.length;
	NSInteger pos;
	NSInteger rest = 0;
	NSMutableString *result = [NSMutableString stringWithCapacity:len];
	
	NSError *err;
	NSRegularExpression *entre = [NSRegularExpression regularExpressionWithPattern:@"&#?[a-zA-Z_0-9]+;" options:0 error:&err];
	
	while ((pos = [VvMarkdown indexOf:@"&" str:text from:rest]) >= 0)
	{
		if (pos > rest)
			[result appendString:[text substringWithRange:NSMakeRange(rest, pos - rest)]];
		
		NSArray *matches = [entre matchesInString:text options:NSMatchingAnchored range:NSMakeRange(pos, len - pos)];
		
		if (matches && ([matches count] > 0))
		{
			NSTextCheckingResult *m = (NSTextCheckingResult *)[matches objectAtIndex:0];
			
			[result appendString:[text substringWithRange:NSMakeRange(pos, m.range.length)]];
			rest = pos + m.range.length;
		}
		else 
		{
			[result appendString:@"&amp;"];
			rest = pos + 1;
		}
	}
	
	if (rest < len)
		[result appendString:[text substringWithRange:NSMakeRange(rest, len - rest)]];
	
	return result;
}



- (NSString *)convert:(NSString *)raw
{
	return [self translate:raw];
}

- (NSString *)convertsz:(const char *)raw
{
	NSString *st = [NSString stringWithUTF8String:raw];
	
	return [self convert:st];
}


- (NSString *)translate:(NSString *)raw
{
	NSMutableString *result = [NSMutableString stringWithCapacity:raw.length];

	NSMutableString *rt = [NSMutableString stringWithString:raw];
	
	[attDefs removeAllObjects];
	
	[crlf replaceMatchesInString:rt options:0 range:NSMakeRange(0, raw.length) withTemplate:@"\n"];
	[rt replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, rt.length)];
	
	[self preprocess:rt];
	
	rawtext = rt;
	curPos = 0;
	rawLength = rawtext.length;
	
	while (! [self atEof])
	{
		NSString *block = [self translateBlock];
		
		if (block)
		{
			if (result.length)
				[result appendString:@"\n\n"];
			[result appendString:block];
		}
	}
	
	for (NSString *key in attDefs) 
	{
		MdAttLookup *lo = (MdAttLookup *)[attDefs objectForKey:key];
		
		NSString *rep = [NSString stringWithFormat:@"{{{LINKFIX:%@}}}", key];
		
		NSString *val = [MdAttribute vvImage:[lo val]];
						 
		[result replaceOccurrencesOfString:rep withString:val options:0 range:NSMakeRange(0, result.length)];
	}
	
	return result;
}

- (UTF8Char)peek
{
	if (curPos < rawLength)
		return [rawtext characterAtIndex:curPos];
	
	return EOF;
}

- (UTF8Char)get
{
	if (curPos < rawLength)
	{
		unichar ch = [rawtext characterAtIndex:curPos];
		++curPos;
		return ch;
	}
	
	return EOF;
}


- (BOOL) match:(NSString *)st
{
	if ((curPos + st.length) > rawLength)
		return FALSE;
	
	NSString *s = [rawtext substringWithRange:NSMakeRange(curPos, st.length)];
	
	return [s isEqualToString:st];
}

- (void) putback
{
	if (curPos > 0)
		--curPos;
}

- (NSString *) skipLen:(NSUInteger)len
{
	NSUInteger start = curPos;
	
	curPos += len;
	if (curPos > rawLength)
		curPos = rawLength;
	
	NSRange r = NSMakeRange(start, curPos - start);
	
	return [rawtext substringWithRange:r];
}

- (void) skipLine
{
	while (! ([self atEof] || [self atEol]))
		++curPos;
	
	if ([self atEol])
		++curPos;
}

- (BOOL) atEof
{
	return (curPos >= rawLength);
}

- (BOOL) atEol
{
	return( [self peek] == '\n' );
}

- (MdNode *) boldOrEm:(UTF8Char) ch
{
	MdNode *node = [MdNode node:FALSE];
	NSMutableString *endRun;
	NSMutableString *extras = [NSMutableString string];
	
	[self get];
	
	if ([self peek] == ch)
	{
		endRun = [NSMutableString stringWithFormat:@"%c%c", ch, ch];
		[node setTag:@"strong"];
		[self get];
		
		while ([self peek] == ch)
		{
			[self get];
			[endRun appendFormat:@"%c", ch];
			[extras appendFormat:@"%c", ch];
		}
	}
	else 
	{
		endRun = [NSMutableString stringWithFormat:@"%c", ch];
		[node setTag:@"em"];
	}
	
	NSString *l = [self peekLine];
	NSRange pos = [l rangeOfString:endRun];
	
	if (pos.length > 0)
	{
		[node appendString:extras];
		NSUInteger savedLength = rawLength;
		rawLength = curPos + pos.location;
		[self translateChunk:node endrun:nil justone:FALSE];
		rawLength = savedLength;
		[node appendString:extras];
		
		[self skipLen:endRun.length];
	}
	else
	{
		[node setTag:nil];
		[node prependStr:endRun];
	}
	
	return node;
}

- (MdNode *) inlineCode
{
	MdNode *node = [MdNode node:FALSE];
	
	[self get];
	
	[node setTag:@"code"];
	NSMutableString *inner = [NSMutableString string];
	
	while (! ([self atEof] || [self atEol]))
	{
		UTF8Char ch = [self get];
		
		if (ch == '`')
			break;
		
		[inner appendFormat:@"%c", ch];
	}
	
	[node appendString:[VvMarkdown encode:inner]];
	
	return node;
}

- (MdNode *)heading
{
	MdNode *node = [MdNode node:TRUE];

	int hn = 0;
	
	while ([self peek] == '#')
	{
		++hn;
		[self get];
	}
	
	while (isspace([self peek]) && ! [self atEol])
		[self get];
	
	[node setTag:[NSString stringWithFormat:@"h%i", hn]];
	
	[self translateLine:node justone:TRUE];

	[node trim:'#'];
	
	return node;
}


- (MdNode *)wikiLink
{
	NSMutableString *page = [NSMutableString string];
	
	while (! ([self atEof] || [self atEol]))
	{
		UTF8Char ch = [self get];
		
		if (ch == ']')
		{
			if ([self peek] == ']')
				[self get];
			break;
		}
		else 
			[page appendFormat:@"%c", ch];
	}
	
	MdNode *node = [MdNode node:TRUE];
	[node setTag:@"a"];
	[node appendString:page];
	
	MdAttribute *att = [MdAttribute attWithValue:@"href" value:[NSString stringWithFormat:@"wiki://./%@", page]];
	[node appendAttribute:att];
	
	return(node);
}


- (MdNode *)witlink
{
	NSMutableString *witid = [NSMutableString string];
	
	while (! ([self atEof] || [self atEol]))
	{
		UTF8Char ch = [self peek];
		
		if (! isalnum(ch))
			break;
		else 
		{
			[self get];
			[witid appendFormat:@"%c", ch];
		}
	}
	
	MdNode *node = [MdNode node:FALSE];
	[node setTag:@"a"];
	[node appendString:witid];
	
	MdAttribute *att = [MdAttribute attWithValue:@"href" value:[NSString stringWithFormat:@"wit://./%@", witid]];
	[node appendAttribute:att];
	
	return(node);
}


- (MdNode *)cslink
{
	NSMutableString *csid = [NSMutableString string];
	
	while (! ([self atEof] || [self atEol]))
	{
		UTF8Char ch = [self peek];
		
		if (! ishexnumber(ch))
			break;
		else 
		{
			[self get];
			[csid appendFormat:@"%c", ch];
		}
	}
	
	NSInteger sublen = MIN(csid.length, 8);
	NSString *shortcsid = [csid substringToIndex:sublen];
	
	MdNode *node = [MdNode node:FALSE];
	[node setTag:@"a"];
	[node appendChar:'@'];
	[node appendString:shortcsid];
	
	MdAttribute *att = [MdAttribute attWithValue:@"href" value:[NSString stringWithFormat:@"commit://./%@", csid]];
	[node appendAttribute:att];
	
	return(node);
}


- (NSInteger)peekMatch:(NSRegularExpression *)re
{
	NSString *line = [self peekLine];
	
	NSArray *matches = [re matchesInString:line options:NSMatchingAnchored range:NSMakeRange(0, line.length)];
	
	if ( matches && ([matches count] > 0) )
	{
		NSTextCheckingResult *res = (NSTextCheckingResult *)[matches objectAtIndex:0];
		
		return( res.range.length );
	}
	else {
		return 0;
	}
}

- (NSInteger)peekstr:(NSString *)st
{
	NSString *line = [self peekLine];
	
	NSRange r = [line rangeOfString:st];
	
	return( (r.length == st.length) && (r.location == 0) );
}

- (void) collectListItems:(MdNode *)parent leader:(NSRegularExpression *) leader
{
	NSInteger myIndent = [self peekIndent];
	MdNode *prevli = nil;
	
	while ([self peekUL] || [self peekOL])
	{
		NSInteger pos = [self peekIndent];
		NSRegularExpression *re;

		if ([self peekUL])
		{	
			re = ulre;
		}
		else 
		{
			re = olre;
		}
		
		if (pos > myIndent)
		{
			MdNode *kid = [MdNode node:FALSE];
			
			if ([self peekUL])
				[kid setTag:@"ul"];
			else 
				[kid setTag:@"ol"];
			
			[prevli appendChild:kid];
			[self collectListItems:kid leader:re];
			
			continue;
		}
		else if (pos < myIndent)
			return;
		
		[self skipLen:[self peekMatch:re]];
		
		UTF8Char ch = [self peek];
		
		while (isspace(ch) && ! [self atEol])
		{
			[self get];
			ch = [self peek];
		}
		
		MdNode *li = [MdNode node:TRUE];
		[li setTag:@"li"];

		[self translateLine:li justone:FALSE];
		
		[parent appendChild:li];
		
		prevli = li;
	}
}

- (MdNode *)weblink
{
	MdNode *node = [MdNode node:FALSE];
	[node setTag:@"a"];
	BOOL isImage = FALSE;
	
	if ([self peekstr:@"!["])
	{
		[self skipLen:2];
		[node appendChild:[self image]];
		
		while (isspace([self peek]))
			[self get];
		
		if ([self peek] == ']')
			[self get];
		
		isImage = TRUE;
	}
	else 
	{
		while (! [self atEof])
		{
			UTF8Char ch = [self get];
		
			if (ch == ']')
				break;
			
			if (ch == '\\')
			{
				if ([self peek] == '\\')
				{	
					[self get];
					[node appendChar:ch];
				}
			}
			else
				[node appendChar:ch];
		}
	}
	
	NSMutableString *spaces = [NSMutableString string];
	
	while (isspace([self peek]))
	{
		[spaces appendFormat:@"%c", [self get]];
	}
	
	UTF8Char ch = [self peek];
	NSMutableString *link = [NSMutableString string];

	BOOL isFilter = [self peekstr:@"(filter://"] || [self peekstr:@"(branch://"] || [self peekstr:@"(tag://"];
	
	if (ch == '(')
	{
		if ((! isImage) && (! isFilter))
			[self appendXURL:node];
		
		[self get];
		
		while (! ([self atEof] || [self atEol]))
		{
			UTF8Char ch = [self get];
			
			if (ch == ')')
				break;
			
			[link appendFormat:@"%c", ch];
		}

		NSString *title = nil;
		NSString *justlink = link;
		
		NSArray *matches = [linktitle matchesInString:link options:0 range:NSMakeRange(0, link.length)];
		
		if (matches && ([matches count] > 0))
		{
			NSTextCheckingResult *match = (NSTextCheckingResult *)[matches objectAtIndex:0];
			
			justlink = [link substringWithRange:[match rangeAtIndex:1]];
			title = [link substringWithRange:[match rangeAtIndex:2]];
		}
		
		justlink = [justlink stringByReplacingOccurrencesOfString:@"\"" withString:@""];
		
		MdAttribute *att = [MdAttribute attWithValue:@"href" value:justlink];
		[node appendAttribute:att];
		
		if (title)
		{
			att = [MdAttribute attWithValue:@"title" value:title];
			[node appendAttribute:att];
		}
	}
	else if (ch == '[')
	{
		[self get];

		while (! ([self atEof] || [self atEol]))
		{
			UTF8Char ch = [self get];
			
			if (ch == ']')
				break;
			
			[link appendFormat:@"%c", ch];
		}
		
		MdAttLookup *lo = [attDefs objectForKey:link];
		
		if (lo)
		{
			NSString *href = [lo val];
			NSString *title = [lo title];
			
			NSRange r = [href rangeOfString:@"filter://"];
			BOOL isFilter = (r.length == 9) && (r.location == 0);
			
			if (! isFilter)
			{
				r = [href rangeOfString:@"tag://"];
				isFilter = (r.length == 6) && (r.location == 0);
			}
			if (! isFilter)
			{
				r = [href rangeOfString:@"branch://"];
				isFilter = (r.length == 9) && (r.location == 0);
			}

			if ((! isImage) && (! isFilter))
				[self appendXURL:node];

			MdAttribute *att = [MdAttribute attWithValue:@"href" value:href];
			[node appendAttribute:att];
			
			if (title)
			{
				att = [MdAttribute attWithValue:@"title" value:title];
				[node appendAttribute:att];
			}
		}
		else
		{
			MdAttribute *att = [MdAttribute attWithKey:@"href" keytag:link];
			[node appendAttribute:att];
		}
	}
	else 
	{
		[node setTag:nil];
		[node prependChar:'['];
		[node appendString:[NSString stringWithFormat:@"%c%@", ']', spaces]];
	}
	
	return node;
}


- (MdNode *)image
{
	MdNode *node = [MdNode node:FALSE];
	[node setTag:@"img"];
	[node setSingle:@"alt"];
	
	while (! [self atEof])
	{
		UTF8Char ch = [self get];
		
		if (ch == ']')
			break;
		
		[node appendChar:ch];
	}
	
	NSMutableString *spaces = [NSMutableString string];
	
	while (isspace([self peek]))
	{
		[spaces appendFormat:@"%c", [self get]];
	}
	
	UTF8Char ch = [self peek];
	NSMutableString *link = [NSMutableString string];
	
	if (ch == '(')
	{
		[self get];
		
		while (! ([self atEof] || [self atEol]))
		{
			UTF8Char ch = [self get];
			
			if (ch == ')')
				break;
			
			[link appendFormat:@"%c", ch];
		}
		
		MdAttribute *att = [MdAttribute attWithValue:@"src" value:link];
		[node appendAttribute:att];
	}
	else if (ch == '[')
	{
		[self get];
		
		while (! ([self atEof] || [self atEol]))
		{
			UTF8Char ch = [self get];
			
			if (ch == ']')
				break;
			
			[link appendFormat:@"%c", ch];
		}
		
		MdAttribute *att = [MdAttribute attWithKey:@"src" keytag:link];
		[node appendAttribute:att];
	}
	else 
	{
		[node setTag:nil];
		[node prependChar:'['];
		[node prependChar:'!'];
		[node appendString:[NSString stringWithFormat:@"%c%@", ']', spaces]];
	}
	
	return node;
}


- (NSString *) peekLine
{
	NSMutableString *result = [NSMutableString string];
	
	int p = curPos;
	
	while (p < rawLength)
	{
		UTF8Char ch = [rawtext characterAtIndex:p];
		
		if (ch == '\n')
			break;
		
		[result appendFormat:@"%c", ch];
		
		++p;
	}
	
	return result;
}

- (BOOL) matchRe:(NSString *)repattern text:(NSString *)text
{
	NSError *err = nil;
	NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:repattern options:0 error:&err];
	
	NSArray *matches = [re matchesInString:text options:NSMatchingAnchored range:NSMakeRange(0, text.length)];
	
	return( matches && ([matches count] > 0) );
}

- (BOOL) isNewBlock:(NSString *)line
{
	return [self matchRe:@"^\\s*$" text:line] ||
	[self matchRe:@"-+\\s*$" text:line] ||
	[self matchRe:@"=+\\s*$" text:line] ||
	[self matchRe:@"#+\\s+" text:line] ||
	[self matchRe:@"\\s*[\\-\\*\\+]\\s" text:line] ||
    [self matchRe:@"\\s*\\d+\\.\\s" text:line];
}

- (void) translateLine:(MdNode *)outernode justone:(BOOL)justone
{
	[self translateChunk:outernode endrun:nil justone:justone];
}

- (void) preprocess:(NSMutableString *)text
{
	NSArray *matches = [linkdef matchesInString:text options:0 range:NSMakeRange(0, text.length)];
	
	if (! matches)
		return;
	
	for ( NSInteger i = [matches count] - 1; i >= 0; --i )
	{
		NSTextCheckingResult *match = (NSTextCheckingResult *)[matches objectAtIndex:i];
		
		NSRange checkRange = NSMakeRange([match range].location, text.length - [match range].location);

		NSArray *qmatches = [quotedlinkdef matchesInString:text options:0 range:checkRange];
		
		BOOL removeQuotes = FALSE;
		
		if (qmatches && ([qmatches count] >= 1))
		{
			match = (NSTextCheckingResult *)[qmatches objectAtIndex:0];
			removeQuotes = TRUE;
		}
		
		NSString *key = [text substringWithRange:[match rangeAtIndex:1]];
		NSString *value = [text substringWithRange:[match rangeAtIndex:2]];
		NSString *title = nil;
		
		if (removeQuotes)
		{
			value = [value stringByReplacingOccurrencesOfString:@"\"" withString:@""];
		}
		
		if (match.numberOfRanges > 3)
		{
			NSRange range = [match rangeAtIndex:3];
			
			if (range.length > 0)
				title = [text substringWithRange:NSMakeRange(range.location + 1, range.length - 2)];
		}
		
		value = [MdAttribute vvImage:value];
		
		MdAttLookup *lo = [[MdAttLookup alloc] init:value title:title];
		
		[attDefs setObject:lo forKey:key];
		
		[text deleteCharactersInRange:[match rangeAtIndex:0]];
	}
}

- (void) appendXURL:(MdNode *)node
{
	MdNode *xu = [MdNode node:FALSE];
	[xu setTag:@"span"];
	[xu setAttr:@"class" value:@"vvxurl"];
	[xu appendString:@"&rArr;"];
	
	[node appendChild:xu];
}

- (void) translateChunk:(MdNode *)outernode endrun:(NSString *)endrun justone:(BOOL)justone
{
	NSInteger lines = 0;
	
	MdNode *node = outernode;
	BOOL inbq = FALSE;
	BOOL lastWasBR = FALSE;
	
	do
	{
		if (endrun && [self match:endrun])
			return;
		
		UTF8Char ch = [self peek];
		
		if (lastWasBR)
		{
			MdNode *br = [MdNode node:FALSE];
			[br setTag:@"br"];
			
			[node appendChild:br];
		}
		else if (lines > 0)
			[node appendChar:' '];
		
		lastWasBR = [self peekMatch:brline];
		
		if ([self peekMatch:bqlead])
		{
			BOOL new = FALSE;
			if (! inbq)
			{
				[outernode setTag:@"blockquote"];
				node = [MdNode node:TRUE];
				[node setTag:@"p"];
				[outernode appendChild:node];
				inbq = TRUE;
				new = TRUE;
			}
			
			[self get];
			
			while ([self peek] == ' ')
				[self get];
			
			ch = [self peek];

			if ([self atEol] && ! new)
			{
				node = [MdNode node:TRUE];
				[node setTag:@"p"];
				[outernode appendChild:node];
				lines = -1;
			}
		}
		
		++lines;
	
		while (! ([self atEof] || [self atEol]))
		{
			if (endrun && [self match:endrun])
				return;
			
			if (ch == '\\')
			{
				[self get];
				
				if ([self atEof] || [self atEol])
					[node appendChar:'\\'];
				else
					[node appendChar:[self get]];
				
				ch = [self peek];
				
				continue;
			}
			
			if ((ch == '_') || (ch == '*'))
			{
				[node appendChild:[self boldOrEm:ch]];
			}
			else if (ch == '`')
			{
				[node appendChild:[self inlineCode]];
			}
			else if ([self peekMatch:autolink])
			{
				NSString *wrapped = [self skipLen:[self peekMatch:autolink]];
				NSRange r = NSMakeRange(1, wrapped.length - 2);
				NSString *href = [wrapped substringWithRange:r];
				
				MdNode *a = [MdNode node:FALSE];
				[a setTag:@"a"];
				[a setAttr:@"href" value:href];
				[a appendString:href];
				[self appendXURL:a];
				
				[node appendChild:a];
			}
			else
			{
				ch = [self get];
				
				if ((ch == '[') && ([self peek] == '['))
				{
					[self get];
					[node appendChild:[self wikiLink]];
				}
				else if (ch == '[')
					[node appendChild:[self weblink]];
				else if ((ch == '^') && ([self peekMatch:witlink]))
					[node appendChild:[self witlink]];
				else if ((ch == '@') && ([self peekMatch:cslink]))
					[node appendChild:[self cslink]];
				else if ((ch == '!') && ([self peek] == '['))
				{
					[self get];
					[node appendChild:[self image]];
				}
				else
					[node appendChar:ch];
			}
		
			ch = [self peek];
		}

		if (ch == '\n')
			[self get];
	} while (! (justone || [self isNewBlock:[self peekLine]]));
}


- (NSInteger)peekIndent
{
	const char *st = [[self peekLine] UTF8String];
	NSInteger indent = 0;
	
	while (isspace(*st))
	{
		++st;
		++indent;
	}
	
	return(ceil(indent / 4.0));
}

- (BOOL)peekUL
{
	return [self matchRe:@"^\\s*[\\-\\+\\*]\\s" text:[self peekLine]];
}

- (BOOL)peekOL
{
	return [self matchRe:@"^\\s*\\d+\\.\\s" text:[self peekLine]];
}


- (NSString *)translateBlock
{
	UTF8Char ch = [self peek];
	NSError *err;
	
	if (ch == '#')
	{
		return [[self heading] toString:attDefs];
	}
	else if ([self peekMatch:hr])
	{
		[self skipLine];
		return @"<hr />";
	}
	else if ([self peekMatch:liststart])
	{
		NSString *line = [self peekLine];
		
		NSArray *matches = [liststart matchesInString:line options:0 range:NSMakeRange(0, line.length)];
		NSTextCheckingResult *m = (NSTextCheckingResult *)[matches objectAtIndex:0];

		NSString *listcharstr = [line substringWithRange:[m rangeAtIndex:1]];

		NSString *restring = [NSString stringWithFormat:@"^\\s{0,3}\\%@\\s+", listcharstr];
		NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:restring options:0 error:&err];

		matches = [re matchesInString:line options:0 range:NSMakeRange(0, line.length)];
		
		if (matches && ([matches count] > 0))
		{
			MdNode *node = [MdNode node:TRUE];
			[node setTag:@"ul"];
		
			[self collectListItems:node leader:re];
		
			return [node toString:attDefs];
		}
	}
	else
	{
		NSString *line = [self peekLine];
		
		NSArray *matches = [olLeaderRe matchesInString:line options:0 range:NSMakeRange(0, line.length)];
		
		if (matches && ([matches count] > 0))
		{
			MdNode *node = [MdNode node:TRUE];
			[node setTag:@"ol"];
			
			[self collectListItems:node leader:olLeaderRe];
			
			return [node toString:attDefs];
		}		
	}
	
	if ([self peekMatch:codeline])
	{
		MdNode *pre = [MdNode node:TRUE];
		[pre setTag:@"pre"];
		
		MdNode *code = [MdNode node:TRUE];
		[code setTag:@"code"];
		
		NSInteger lines = 0;
		
		while ([self peekMatch:codeline])
		{
			++lines;
			
			NSString *line = [[self peekLine] substringFromIndex:4];
			[self skipLen:(line.length + 4)];
			
			if ([self atEol])
				[self get];
			
			if (lines > 1)
				[code appendString:@"\n"];
			
			[code appendString:[VvMarkdown encode:line]];
		}
		
		[pre appendChild:code];
		
		return [pre toString:attDefs];
	}

	MdNode *node = [MdNode node:TRUE];
	NSInteger lines = 0;
	
	if ([self peekMatch:paralead])
	{
		do
		{
			if (lines > 0)
			{
				[node appendChar:' '];
			}
			
			[self translateLine:node justone:FALSE];
			++lines;
		} while ([self peekMatch:paraline]);
	}
	else if ([self peekMatch:blankline])
	{
		[self skipLine];
	}
	else if ([self atEol])
		[self get];
	
	NSString *tag = [node getTag];
	
	if ((! tag) || (tag.length == 0))
		tag = @"p";
	
	BOOL isp = [tag isEqualToString:@"p"];
	
	if (isp && ([node innerText:[NSDictionary dictionary]].length > 0))
	{
		if ([self peekMatch:h1])
		{
			[self skipLine];
			[node setTag:@"h1"];
		}
		else if ([self peekMatch:h2])
		{
			[self skipLine];
			[node setTag:@"h2"];
		}
	}
		
	return [node toString:attDefs];
}

@end
