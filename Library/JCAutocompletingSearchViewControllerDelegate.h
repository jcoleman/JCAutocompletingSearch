#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class JCAutocompletingSearchViewController;

typedef void (^JCAutocompletingSearchResultsHandler)(NSArray*);

@protocol JCAutocompletingSearchViewControllerDelegate <NSObject>

@required
- (void) searchController:(JCAutocompletingSearchViewController*)searchController
        performSearchForQuery:(NSString*)query
           withResultsHandler:(JCAutocompletingSearchResultsHandler)resultsHandler;
- (void) searchControllerCanceled:(JCAutocompletingSearchViewController*)searchController;
- (void) searchController:(JCAutocompletingSearchViewController*)searchController
                tableView:(UITableView*)tableView
           selectedResult:(id)result;

@optional
- (BOOL) searchControllerShouldPerformBlankSearchOnLoad:(JCAutocompletingSearchViewController*)searchController;
- (BOOL) searchControllerSearchesPerformedSynchronously:(JCAutocompletingSearchViewController*)searchController;
- (BOOL) searchControllerUsesCustomResultTableViewCells:(JCAutocompletingSearchViewController*)searchController;
- (UITableViewCell*) searchController:(JCAutocompletingSearchViewController*)searchController
                            tableView:(UITableView*)tableView
                cellForRowAtIndexPath:(NSIndexPath*)indexPath;
- (CGFloat) searchController:(JCAutocompletingSearchViewController*)searchController
                   tableView:(UITableView*)tableView
     heightForRowAtIndexPath:(NSIndexPath*)indexPath;
- (BOOL) searchController:(JCAutocompletingSearchViewController*)searchController shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

@end
