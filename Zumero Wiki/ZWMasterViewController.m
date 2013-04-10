//
//  ZWMasterViewController.m
//  Zumero Wiki
//

#import "ZWMasterViewController.h"

#import "ZWDetailViewController.h"
#import "WikiPage.h"
#import "ZWConfig.h"
#import "ZWAppDelegate.h"
#import "ZWError.h"
#import <Zumero/Zumero.h>

@interface ZWMasterViewController () {
    NSMutableArray *_objects;
	ZumeroDB *_db;
}
@end

@implementation ZWMasterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		self.title = NSLocalizedString(@"Page List", @"Page List");
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		    self.clearsSelectionOnViewWillAppear = NO;
		    self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
		}
		
		_db = [[ZumeroDB alloc] initWithName:[ZWConfig dbname] folder:[ZWConfig dbpath] host:[ZWConfig server]];
    }
    return self;
}
							
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	self.navigationItem.leftBarButtonItem = self.editButtonItem;

	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
	self.navigationItem.rightBarButtonItem = addButton;
	
	[self loadPages];
	
//	[self addPage:o];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void) loadPages
{
	NSError *err = nil;
	
	if ([_db isOpen] || [_db open:&err])
	{
		if (_objects)
			[_objects removeAllObjects];
		
		NSArray *rows = nil;
		NSError *err = nil;
		BOOL selected = [_db selectSql:@"select pageid, title, text from pages" values:nil rows:&rows error:&err];
		
		if (selected)
		{
			for ( NSDictionary *row in rows )
			{
				WikiPage *page = [[WikiPage alloc] init];
				page.title = [row objectForKey:@"title"];
				page.text = [row objectForKey:@"text"];
				page.recid = [row objectForKey:@"pageid"];
				page.exists = TRUE;
				[self addPage:page];
			}
		}
		
		[_db close];
		
		[self refresh];
	}
}

- (void) refresh
{
	NSIndexPath *ip = [self.tableView indexPathForSelectedRow];
	[self.tableView reloadData];
	
	if (ip)
	{
		[self.tableView selectRowAtIndexPath:ip animated:NO scrollPosition:UITableViewScrollPositionNone];
	}
}

- (void)addPage:(WikiPage *)page
{
    if (!_objects) {
        _objects = [[NSMutableArray alloc] init];
    }
    [_objects insertObject:page atIndex:0];
}


//  Create a new page.
//
//  If this is our first run, and/or we haven't yet synched to a defined database,
//  we'll create the db file and define tables as needed.
//
- (void)insertNewObject:(id)sender
{
	WikiPage *page = [[WikiPage alloc] init];
	page.title = @"New Page Title Here";
	page.text = @"Page Text Here";
	page.exists = FALSE;
	
	NSNumber *btrue = [NSNumber numberWithBool:TRUE];
	BOOL ok = YES;

	NSError *err = nil;

	if (! [_db exists])
		ok = [_db createDB:&err];
		
	if (ok && ! [_db tableExists:@"z_acl"])
	{
		ok = [_db beginTX:&err] &&
		[_db createACLTable:&err] &&
		[_db addACL:[ZWConfig scheme]
				who:[ZumeroACL who_any_auth]
			  table:@""
				 op:[ZumeroACL op_all]
			 result:[ZumeroACL result_allow]
			  error:&err] &&
		[_db commitTX:&err];
	}

	ok = ok &&
	([_db isOpen] || [_db open:&err]);
	
	// we need a 'pages' database that attempts to
	// do a text merge on any conflicting page edits
	//
	if (ok && ! [_db tableExists:@"pages"])
	{
		NSDictionary *fields = @{
		@"pageid" : @{@"type":@"unique"},
		@"title" : @{@"type":@"text", @"not_null":btrue},
		@"text" : @{@"type":@"text", @"not_null":btrue}
		};
		
		ok = [_db beginTX:&err] &&
		[_db defineTable:@"pages" fields:fields error:&err] &&
		[_db addRowRule:@"pages" situation:[ZumeroRule situation_mod_after_mod] action:[ZumeroRule action_column_merge] error:&err] &&
		[_db addColumnRule:@"pages" column:@"title" action:[ZumeroRule action_accept] error:&err] &&
		[_db addColumnRule:@"pages" column:@"text" action:[ZumeroRule action_attempt_text_merge] error:&err] &&
		[_db commitTX:&err];
	}

	// At the moment, the 'blobs' table is only used
	// to store embedded wiki images
	//
	if (ok && ! [_db tableExists:@"blobs"])
	{
		NSDictionary *blobfields = @{
		  @"id" : @{ @"type":@"unique", @"primary_key": btrue },
		  @"data": @{@"type":@"blob", @"not_null":btrue},
		  @"type": @{@"type":@"text"}
							   };
		
		ok = [_db beginTX:&err] &&
		[_db defineTable:@"blobs" fields:blobfields error:&err] &&
		[_db commitTX:&err];
	}
		
	// if we failed along the way with an open transaction, close it.
	// if not, we'll ignore the resulting error.
	//
	if (! ok)
		[_db abortTX:&err];
	
	[self addPage:page];
	[self refresh];

	// select our new page for ediing
	//
	NSIndexPath *ip = [NSIndexPath indexPathForRow:0 inSection:0];
	[self.tableView selectRowAtIndexPath:ip animated:FALSE scrollPosition:UITableViewScrollPositionNone];
	[self tableView:self.tableView didSelectRowAtIndexPath:ip];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return _objects ? _objects.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (BOOL)deleteRec:(WikiPage *)page error:(NSError **)err
{
	if (! page)
		return NO;
	NSString *recid = page.recid;
	if (! recid)
		return NO;
	
	BOOL ok = _db && ([_db isOpen] || [_db open:err]);
	
	if (ok)
	{
		ok = [_db beginTX:err] &&
		[_db delete:@"pages" criteria:@{ @"pageid" : recid } error:err] &&
		[_db commitTX:err];
		
		if (! ok)
			[_db abortTX:err];
	}
	
	return ok;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		WikiPage *o = [_objects objectAtIndex:indexPath.row];
		
		NSError *err = nil;
		
		if ([self deleteRec:o error:&err])
		{
			[_objects removeObjectAtIndex:indexPath.row];
			[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
			
			ZWAppDelegate *d = (ZWAppDelegate *)[[UIApplication sharedApplication] delegate];
				
			[d waitForSync:1];
		}
		else
			[ZWError reportError:@"Unable to Delete Page" description:@"The page does not exist, or could not be deleted." error:err];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
}


#pragma mark sync

//  Kick off a sync
//
//  The actual sync operation will run in the background, with the final results
//  going to the delegate's syncSuccess/syncFail method.
//
//  We only fail here if the initial sync call failed - no database open, etc.
//
//  If needed, create an empty database against which to sync.
//
- (BOOL) sync:(id<ZumeroDBDelegate>)delegate
{
	BOOL ok = FALSE;
    
    if (_db && ! [_db exists])
    {
        NSError *err = nil;
        if (! [_db createDB:&err])
        {
            [ZWError reportError:@"Unable to Create Database" description:@"Could not create local copy of the database" error:err];
            return NO;
        }
    }
	if (_db && [_db exists])
	{
		NSError *err = nil;
		_db.delegate = delegate;
		
		NSDictionary *scheme = [ZWConfig scheme];
		NSString *username = [ZWConfig username];
		NSString *password = [ZWConfig password];
		
		ok = [_db isOpen] || [_db open:&err];

		if (ok)
		{
			ok = [_db sync:scheme user:username password:password error:&err];
		}
	}
	
	return ok;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    WikiPage *object = _objects[indexPath.row];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	    if (!self.detailViewController) {
	        self.detailViewController = [[ZWDetailViewController alloc] initWithNibName:@"ZWDetailViewController_iPhone" bundle:nil];
			self.detailViewController.masterViewController = self;
			[self.detailViewController setView:[self.detailViewController view]];
	    }
        [self.navigationController pushViewController:self.detailViewController animated:YES];
    }
	
    self.detailViewController.db = _db;
	self.detailViewController.objects = _objects;
    self.detailViewController.detailItem = object;
}

@end
