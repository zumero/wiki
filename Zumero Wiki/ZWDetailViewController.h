//
//  ZWDetailViewController.h
//  Zumero Wiki
//

#import <UIKit/UIKit.h>
#import "ZWImagePickerViewController.h"
#import "VVMarkdownView.h"

@class ZWMasterViewController;
@class ZWAppDelegate;

@interface ZWDetailViewController : UIViewController <UISplitViewControllerDelegate, UITableViewDataSource, ImagePickerDelegate, UITableViewDelegate, VVMarkdownViewDelegate>

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;

@property (strong, nonatomic) id detailItem;
@property (strong, nonatomic) id db;
@property (strong, nonatomic) id objects;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@property (strong, nonatomic) ZWMasterViewController *masterViewController;

@end
