//
//  ZWDetailViewController.m
//  Zumero Wiki
//
#import "ZWDetailViewController.h"
#import "VVMarkdownView.h"
#import "WikiPage.h"
#import "ZWMasterViewController.h"
#import "ZWAppDelegate.h"
#import "ZWImagePickerViewController.h"
#import "ZWConfig.h"
#import "ZWError.h"
#import <Zumero/Zumero.h>

@interface ZWDetailViewController ()
{
	VVMarkdownView *mv;
	UITextView *editor;
	UITextView *titleedit;
	UIBarButtonItem *historyButton;
	UITableView *history;
	UITableView *pages;
	UITableViewController *ptvc;
	NSArray *_hist;
	UIToolbar *my_edit_toolbar;
	UIPopoverController *ppc;
	ZWImagePickerViewController *_picker;
}
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation ZWDetailViewController

#pragma mark - Managing the detail item

const NSUInteger tfHeight = 44 + 8;

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
		
		self.editButtonItem.enabled = ! [_detailItem historical];
		[self historyReset:YES];
		_hist = nil;
		
		[history reloadData];
		
		if (! [_detailItem exists])
		{
			[self setEditing:TRUE animated:FALSE];
		}
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

	if (self.detailItem) {
		self.title = [self.detailItem title];

		NSString *t = [self.detailItem text];
		
		[mv setRawText:t];
		[mv render];
		
		[editor setText:t];
		[titleedit setText:self.title];
	}
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	historyButton = [[UIBarButtonItem alloc] initWithTitle:@"History" style:UIBarButtonItemStyleBordered target:self action:@selector(onClickHistory:)];
	historyButton.enabled = NO;

	self.editButtonItem.enabled = NO;

	self.navigationItem.rightBarButtonItems = @[ self.editButtonItem, historyButton ];
	
	CGRect frame = [self.view bounds];
	mv = [[VVMarkdownView alloc] initWithFrameDeferred:frame deferred:YES];
	
	mv.db = [[ZumeroDB alloc] initWithName:[ZWConfig dbname] folder:[ZWConfig dbpath] host:[ZWConfig server]];
	mv.delegate = self;

	[self.view addSubview:mv];
	
	NSUInteger titleHeight = tfHeight;

	CGRect titleframe = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, tfHeight);
	CGRect editframe = CGRectMake(frame.origin.x, frame.origin.y + tfHeight + titleHeight, frame.size.width, frame.size.height - tfHeight - titleHeight);
	
	titleedit = [[UITextView alloc] initWithFrame:titleframe];
	titleedit.hidden = TRUE;
	[titleedit setFont:[UIFont systemFontOfSize:16.0]];

	[self.view addSubview:titleedit];
	editor = [[UITextView alloc] initWithFrame:editframe];
	editor.hidden = TRUE;
	[editor setFont:[UIFont systemFontOfSize:16.0]];
	[self.view addSubview:editor];
	
	history = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
	history.dataSource = self;
	history.delegate = self;
	history.hidden = TRUE;
	[history setAllowsSelection:YES];
	[history setAllowsMultipleSelection:NO];
	[self.view addSubview:history];

	UIColor *tbColor = [UIColor colorWithRed:29/255.0 green:114/255.0 blue:134/255.0 alpha:1.0];
	
	CGRect barframe = CGRectMake(0, titleHeight, frame.size.width, titleHeight);
	my_edit_toolbar = [[UIToolbar alloc] initWithFrame:barframe];
	[self.view addSubview:my_edit_toolbar];
	[my_edit_toolbar setTintColor:tbColor];
	
	//     if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	
	NSMutableArray *buttons = [NSMutableArray arrayWithObjects:
						[self editToolbarButton:@"WikiImage" selector:@selector(onClick_image:)],
						[self editToolbarButton:@"WikiBold" selector:@selector(onClick_bold:)],
						[self editToolbarButton:@"WikiItalic" selector:@selector(onClick_italic:)],
						[self editToolbarSpacer],
						[self editToolbarButton:@"WikiH1" selector:@selector(onClick_h1:)],
						[self editToolbarButton:@"WikiH2" selector:@selector(onClick_h2:)],
						[self editToolbarSpacer],
						[self editToolbarButton:@"WikiOL" selector:@selector(onClick_ol:)],
						[self editToolbarButton:@"WikiUL" selector:@selector(onClick_ul:)],
						[self editToolbarSpacer],
						nil];
							   
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		[buttons addObject:[self editToolbarButton:@"WikiPage" selector:@selector(onClick_wiki:)]];
		[buttons addObject:[self editToolbarSpacer]];
	}
	
	[buttons addObject:[self editToolbarButton:@"WikiCode" selector:@selector(onClick_code:)]];
	
	[my_edit_toolbar setItems:buttons animated:FALSE];
	
	my_edit_toolbar.hidden = TRUE;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillShow:)
												 name:UIKeyboardWillShowNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:nil];
	
	[self configureView];
}


- (BOOL) shouldAutorotate
{
	return YES;
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	CGRect frame = [self.view bounds];
	NSUInteger titleHeight = tfHeight;
	CGRect titleframe = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, tfHeight);
	CGRect editframe = CGRectMake(frame.origin.x, frame.origin.y + tfHeight + titleHeight, frame.size.width, frame.size.height - tfHeight - titleHeight);
	CGRect barframe = CGRectMake(0, titleHeight, frame.size.width, titleHeight);

	[titleedit setFrame:titleframe];
	[editor setFrame:editframe];
	[my_edit_toolbar setFrame:barframe];
}

- (void) resizeEditor:(BOOL)withKeyboard notification:(NSNotification *)notification
{
    [UIView beginAnimations:nil context:nil];

	CGRect frame = [self.view bounds];
	CGRect editframe = CGRectMake(frame.origin.x, frame.origin.y + tfHeight + tfHeight, frame.size.width, frame.size.height - tfHeight - tfHeight);
	if (withKeyboard)
	{
		CGRect endRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
		CGRect keyboardFrame = [self.view convertRect:endRect toView:nil];

		editframe.size.height -= keyboardFrame.size.height;
	}

	editor.frame = editframe;
	
	[editor scrollRangeToVisible:editor.selectedRange];
	
    [UIView commitAnimations];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
	[self resizeEditor:YES notification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	[self resizeEditor:NO notification:notification];
}


- (void) historyReset:(BOOL)enabled
{
	historyButton.enabled = enabled;
	historyButton.title = @"History";
	self.navigationItem.rightBarButtonItems = @[ self.editButtonItem, historyButton ];
	
	history.hidden = TRUE;
}

- (void) onClickHistory:(id)sender
{
	if ([historyButton.title isEqualToString:@"History"])
	{
		historyButton.title = @"Close";
		history.hidden = NO;
		[self.view bringSubviewToFront:history];
		self.navigationItem.rightBarButtonItems = @[ historyButton ];
	}
	else
		[self historyReset:TRUE];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing:editing animated:animated];

	mv.hidden = editing;
	editor.hidden = ! editing;
	titleedit.hidden = ! editing;
	my_edit_toolbar.hidden = ! editing;
	
	historyButton.enabled = ! editing;
	
	if (! editing)
	{
		if ([editor isFirstResponder])
			[editor resignFirstResponder];
		if ([titleedit isFirstResponder])
			[titleedit resignFirstResponder];
		
		NSString *oldText = [_detailItem text];
		NSString *newText = [editor text];
		
		NSString *oldTitle = [_detailItem title];
		NSString *newTitle = [[titleedit text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		NSString *oldRecid = [_detailItem recid];
		
		BOOL isOld = (oldRecid) && [oldText isEqualToString:newText] && [oldTitle isEqualToString:newTitle];
		
		if (! isOld)
		{
			[_detailItem setText:newText];
			[_detailItem setTitle:newTitle];
			
			self.title = newTitle;
			[mv setRawText:newText];
			[mv render];
			
			[self.masterViewController refresh];
			
			NSString *recid = [(WikiPage *)_detailItem recid];
			
			ZumeroDB *db = [[ZumeroDB alloc] initWithName:[ZWConfig dbname] folder:[ZWConfig dbpath] host:[ZWConfig server]];

			NSError *err = nil;
				
			if ([db beginTX:&err])
			{
				BOOL ok = FALSE;
				
				NSDictionary *vals = @{ @"text" : newText, @"title" : newTitle};
				NSMutableDictionary *inserted = [NSMutableDictionary dictionaryWithDictionary:@{ @"pageid" : [NSNull null] }];
					
				if (recid)
					ok = [db update:@"pages" criteria:@{ @"pageid" : recid }
										values:vals
										 error:&err];
				else
				{
					ok = [db insertRecord:@"pages" values:vals inserted:inserted error:&err];
					
					if (ok)
					{
						recid = [inserted objectForKey:@"pageid"];
						[(WikiPage *)_detailItem setRecid:recid];
						[(WikiPage *)_detailItem setExists:TRUE];
					}
				}
					
				if (ok)
					ok = [db commitTX:&err];
					
				if (! ok)
					[db abortTX:&err];
				
				if (ok)
				{
					ZWAppDelegate *d = (ZWAppDelegate *)[[UIApplication sharedApplication] delegate];
				
					[d waitForSync:1];
				}
			}
				
			[db close];
		}
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		self.title = NSLocalizedString(@"Page", @"Page");
    }
    return self;
}
							
#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Page List", @"Page List");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark Data Source

- (void) retrieveHistory
{
	if (_hist)
		return;
	NSString *recid = [_detailItem recid];
	if (! recid)
		return;
	
	NSError *err = nil;
	
	ZumeroDB *db = _db;
	
	if (! db)
		return;
	
	if (! ([db isOpen] || [db open:&err]))
		return;
	
	NSArray *hist = nil;
	
	if ([db recordHistory:@"pages" criteria:@{ @"pageid":recid } history:&hist error:&err])
	{
		_hist = hist;
	}
	
	[db close];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (tableView == history)
	{
		[self retrieveHistory];
		static NSString *CellIdentifier = @"HistCell";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		}
		
		NSDictionary *row = [_hist objectAtIndex:indexPath.row];
		
		//NSString *uname = [row objectForKey:@"user"];
		NSDate *ds = [row objectForKey:@"timestamp"];
		
		cell.textLabel.text = [ds description];
		return cell;
	}
	else if (tableView == pages)
	{
		static NSString *CellIdentifier = @"Page Cell";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
			if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			}
		}
		
		WikiPage *object = _objects[indexPath.row];
		cell.textLabel.text = [object title];
		return cell;
	}
	
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (tableView == history)
	{
		[self retrieveHistory];
	
		return (_hist ? [_hist count] : 0);
	}
	else if (tableView == pages)
	{
		return _objects ? [_objects count] : 0;
	}
	
	return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (tableView == history)
	{
		[self retrieveHistory];
		
		NSDictionary *row = [_hist objectAtIndex:indexPath.row];
		
		NSNumber *z_rv = [row objectForKey:@"z_rv"];
		
		NSError *err = nil;
		
		BOOL ok = [_db isOpen] || [_db open:&err];
		
		if (! ok)
			return;
		
		NSString *sql = @"select title, text, pageid from z$old$pages where z_rv = ?";
		NSArray *rows = nil;
		ok = [_db selectSql:sql values:@[ z_rv ] rows:&rows error:&err];
		
		if (ok && ([rows count] > 0))
		{
			NSDictionary *row = [rows objectAtIndex:0];
			
			WikiPage *wp = [[WikiPage alloc] init];
			wp.title = [NSString stringWithFormat:@"%@ (v%i)", [row objectForKey:@"title"], (int)(indexPath.row + 1)];
			wp.text = [row objectForKey:@"text"];
			wp.recid = [row objectForKey:@"pageid"];
			wp.exists = YES;
			wp.historical = YES;
			
			self.detailItem = wp;
		}
		else
		{
			WikiPage *di = self.detailItem;
			ok = [_db selectSql:@"select * from pages where pageid = ?" values:@[ di.recid ] rows:&rows error:&err] &&
			([rows count] > 0);
			if (ok)
			{
				NSDictionary *row = [rows objectAtIndex:0];
				
				WikiPage *wp = [[WikiPage alloc] init];
				wp.title = [row objectForKey:@"title"];
				wp.text = [row objectForKey:@"text"];
				wp.recid = [row objectForKey:@"pageid"];
				wp.exists = YES;
				
				self.detailItem = wp;
			}
		}
		
		if (! ok)
		{
			[ZWError reportError:@"Page Not Found" description:@"Unable to find a page matching that ID and version" error:nil];
		}
	}
	else if (tableView == pages)
	{
		if (ppc)
			[ppc dismissPopoverAnimated:TRUE];
		
		WikiPage *page = [_objects objectAtIndex:indexPath.row];
	
		[editor insertText:[NSString stringWithFormat:@"[[%@]]", page.title]];
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (tableView == pages)
		return @"Insert Link to Wiki Page";
	
	return nil;
}


#pragma mark toolbar

- (id)editToolbarButton:(NSString *)imageName selector:(SEL)selector
{
	UIBarButtonItem *bb = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:imageName] style:UIBarButtonItemStyleBordered target:self action:selector];
	
	UIColor *tbColor = [UIColor colorWithRed:29/255.0 green:114/255.0 blue:134/255.0 alpha:1.0];
	
	[bb setTintColor:tbColor];
	
	return bb;
}

- (id)editToolbarSpacer
{
	UIBarButtonItem *bb = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	bb.width = 20;
	return bb;
}

- (NSString *)nextUnusedRefNo
{
	return @"1";
}

- (BOOL)addBlobImage:(NSData *)d recid:(NSString **)recid error:(NSError **)err
{
	ZumeroDB *db = [[ZumeroDB alloc] initWithName:[ZWConfig dbname] folder:[ZWConfig dbpath] host:[ZWConfig server]];
	
	NSMutableDictionary *inserted = [NSMutableDictionary dictionary];
	[inserted setValue:[NSNull null] forKey:@"id"];
	
	BOOL ok = [db open:err] &&
	[db beginTX:err] &&
	[db insertRecord:@"blobs" values:@{ @"data": d, @"type": @"image/jpeg"} inserted:inserted error:err] &&
	[db commitTX:err];
	
	if (ok)
		*recid = [inserted valueForKey:@"id"];
	
	return ok;
}

- (void) imagePicked:(UIImage *)picture
{
	NSData *d = UIImageJPEGRepresentation(picture, 0.9);
	
	NSString *ref = [self nextUnusedRefNo];
	NSString *recid = nil;
	NSError *err = nil;
	
	BOOL ok = [self addBlobImage:d recid:&recid error:&err];
	
	if (! ok)
	{
		// TODO: report error
		return;
	}
	
	NSString *url = [NSString stringWithFormat:@"blob:///%@.jpg", recid];
	NSString *title = @"describe image";
	
	NSRange r = editor.selectedRange;
	
	NSString *ln = [NSString stringWithFormat:@"![%@][%@]", title, ref];
	NSString *endref = [NSString stringWithFormat:@"[%@]: %@", ref, url];
	
	if (r.length > 0)
		[editor insertText:ln];
	else
		editor.text = [NSString stringWithFormat:@"%@%@", editor.text, ln];
	
	editor.text = [NSString stringWithFormat:@"%@\n\n%@", editor.text, endref];
	
	//	[editor a
	//	[editor appen]
	r.location += [ln length];
	editor.selectedRange = r;
	// code block

}


-(IBAction)onClick_image:(id)sender
{
	if (! _picker)
	{
		_picker = [[ZWImagePickerViewController alloc] initWithNibName:nil bundle:nil];
		_picker.delegate = self;
		
	}
	
	[_picker present:sender];
}

-(IBAction)onClick_bold:(id)sender
{
	[self wrapTextIn:@"__"];
}

-(IBAction)onClick_italic:(id)sender
{
	[self wrapTextIn:@"*"];
}

-(IBAction)onClick_code:(id)sender
{
	NSRange r = editor.selectedRange;
	
	if ((r.length == 0) && ([self lineAt:r.location].length == 0))
	{
		[editor insertText:@"    "];
		r.location += 4;
		editor.selectedRange = r;
		// code block
	}
	else
	{
		[self wrapTextIn:@"`"];
	}
}

- (IBAction)onClick_h1:(id)sender
{
	[self prependToLine:@"# "];
}

- (IBAction)onClick_h2:(id)sender
{
	[self prependToLine:@"## "];
}

- (IBAction)onClick_ol:(id)sender
{
	[self prependToLine:@"1. "];
}

- (IBAction)onClick_ul:(id)sender
{
	[self prependToLine:@"- "];
}

- (IBAction)onClick_wiki:(id)sender
{
	if (ppc)
		[ppc dismissPopoverAnimated:FALSE];
	
	if (! pages)
	{
		pages = [[UITableView alloc] init];
		pages.dataSource = self;
		pages.delegate = self;
		[pages setAllowsSelection:YES];
		[pages setAllowsMultipleSelection:NO];
		
		ptvc = [[UITableViewController alloc] init];
		ptvc.tableView = pages;
	}
	
	if (! ppc)
	{
		ppc = [[UIPopoverController alloc] initWithContentViewController:ptvc];
		[ppc setPopoverContentSize:CGSizeMake(500, 500)];
	}
	
	[pages reloadData];
	[ppc presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)wrapTextIn:(NSString *)wrapper
{
	NSRange r = editor.selectedRange;
	
	if (r.length == 0)
	{
		[editor insertText:wrapper];
		[editor insertText:wrapper];
		r.location += wrapper.length;
		editor.selectedRange = r;
	}
	else
	{
		NSUInteger start = r.location;
		NSUInteger end = start + r.length;
		NSUInteger newLen = r.length + (wrapper.length * 2);
		
		r.location = end;
		r.length = 0;
		editor.selectedRange = r;
		[editor insertText:wrapper];
		r.location = start;
		editor.selectedRange = r;
		[editor insertText:wrapper];
		
		r.length = newLen;
		editor.selectedRange = r;
	}
}

-(NSUInteger)lineStart:(NSUInteger) pos
{
	NSString *text = editor.text;
	
	NSUInteger start = pos;
	
	while (start > 0)
	{
		if ([text characterAtIndex:(start - 1)] == '\n')
			break;
		--start;
	}
	
	return start;
}

-(NSString *)lineAt:(NSUInteger)pos
{
	NSString *text = editor.text;
	NSUInteger start = [self lineStart:pos];
	
	NSUInteger end = start;
	
	while (end < text.length)
	{
		if ([text characterAtIndex:end] == '\n')
			break;
		++end;
	}
	
	NSString *line = [text substringWithRange:NSMakeRange(start, end - start)];
	
	return line;
}

- (void)prependToLine:(NSString *)text
{
	NSUInteger len = text.length;
	
	NSRange r = editor.selectedRange;
	
	if ([self lineAt:r.location].length == 0)
	{
		[editor insertText:text];
		r.location += len;
		r.length = 0;
		editor.selectedRange = r;
	}
	else
	{
		NSUInteger newPos = r.location + len;
		r.location = [self lineStart:r.location];
		r.length = 0;
		editor.selectedRange = r;
		
		[editor insertText:text];
		r.location = newPos;
		editor.selectedRange = r;
	}
}

#pragma mark VVMarkdownViewDelegate

- (void) wikiPageClicked:(NSString *)title
{
	for (WikiPage *page in _objects)
		if ([page.title isEqualToString:title])
			self.detailItem = page;
}

- (BOOL) canLeave:(NSURL *)url
{
	return YES;
}


@end
