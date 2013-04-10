//
//  ZWImagePickerViewController.m
//  Zumero Wiki
//

#import "ZWImagePickerViewController.h"

@interface ZWImagePickerViewController ()
{
	UIPopoverController *_pc;
}


@end

@implementation ZWImagePickerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
		
		if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
			picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
		else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum])
			picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
		
		self.imagePickerController = picker;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) present:(id)button
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		if (! _pc)
		{
			_pc = [[UIPopoverController alloc] initWithContentViewController:self.imagePickerController];
			[_pc setPopoverContentSize:CGSizeMake(500, 500)];
		}
		
		[_pc presentPopoverFromBarButtonItem:button permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	} else {
		[self presentViewController:self.imagePickerController animated:YES completion:nil];
	}
	
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
	
	if (_pc)
		[_pc dismissPopoverAnimated:YES];
	else
		[self dismissViewControllerAnimated:YES completion:nil];
    
    // give the taken picture to our delegate
    if (self.delegate)
        [self.delegate imagePicked:image];
}

@end
