#import <UIKit/UIKit.h>
#import "JCAutocompletingSearchViewControllerDelegate.h"

@interface JCAutocompletingSearchViewController : UIViewController <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) NSObject<JCAutocompletingSearchViewControllerDelegate>* delegate;

+ (JCAutocompletingSearchViewController*) autocompletingSearchViewController;

@end
