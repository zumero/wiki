//
//  ZWImagePickerViewController.h
//  Zumero Wiki
//

#import <UIKit/UIKit.h>

@protocol ImagePickerDelegate;

@interface ZWImagePickerViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

- (void) present:(id)button;

@property (nonatomic, assign) id <ImagePickerDelegate> delegate;
@property (nonatomic, retain) UIImagePickerController *imagePickerController;

@end

@protocol ImagePickerDelegate
- (void)imagePicked:(UIImage *)picture;
@end

