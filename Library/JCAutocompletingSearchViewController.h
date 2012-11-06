#import <UIKit/UIKit.h>
#import "JCAutocompletingSearchViewControllerDelegate.h"

@interface JCAutocompletingSearchViewController : UIViewController <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate>

@property (weak, nonatomic) NSObject<JCAutocompletingSearchViewControllerDelegate>* delegate;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UITableView *resultsTableView;

+ (JCAutocompletingSearchViewController*) autocompletingSearchViewController;

- (void) resetSelection;
- (void) setSearchBarTextAndPerformSearch:(NSString*)query;
- (NSDictionary*) resultForRowAtIndex:(NSUInteger)resultIndex;

@end
