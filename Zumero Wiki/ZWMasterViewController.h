//
//  ZWMasterViewController.h
//  Zumero Wiki
//

#import <UIKit/UIKit.h>
#import <Zumero/Zumero.h>

@class ZWDetailViewController;

@interface ZWMasterViewController : UITableViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
- (void) refresh;
- (BOOL) sync:(id<ZumeroDBDelegate>)delegate;
- (void) loadPages;

@property (strong, nonatomic) ZWDetailViewController *detailViewController;

@end
