#import "JCAppDelegate.h"
#import "JCAutocompletingSearchViewController.h"

@implementation JCAppDelegate

- (BOOL) application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

  JCAutocompletingSearchViewController* searchController = [JCAutocompletingSearchViewController autocompletingSearchViewController];
  searchController.delegate = self;
  UINavigationController* navigationController = [[UINavigationController alloc] initWithRootViewController:searchController];
  navigationController.navigationBarHidden = YES;
  self.window.rootViewController = navigationController;

  [self.window makeKeyAndVisible];

  return YES;
}

+ (NSArray*) possibleItems {
  static NSArray* sharedList = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // Random names courtesy of http://www.kleimo.com/random/name.cfm
    sharedList = [@[
      @"Debbie Cawthon", @"Philip Mahan", @"Susie Sloan", @"Melinda Wurth", @"Flora Bible",
      @"Marlene Collier", @"John Trammell", @"Kristina Chun", @"Linda Caldera", @"Veronica Jaime",
      @"Rosie Melo", @"Joyce Vella", @"Douglas Leger", @"Brandon Koon", @"Rachel Peeples",
      @"Vicki Castor", @"Benjamin Lynch", @"Velma Vann", @"Della Sherrer", @"Aaron Lyle",
      @"Arthur Jonas", @"Irma Atwood", @"Randy Cheatham", @"Billy Voyles", @"Michele Crouch",
      @"Kenneth Shankle", @"Fred Anglin", @"Dennis Fries", @"Lillie Albertson", @"Iris Bertram"
    ] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
      return [(NSString*)obj1 compare:(NSString*)obj2];
    }];
  });
  return sharedList;
}

#pragma mark - JCAutocompletingSearchViewControllerDelegate Implementation

- (void) searchController:(JCAutocompletingSearchViewController*)searchController
    performSearchForQuery:(NSString*)query
       withResultsHandler:(JCAutocompletingSearchResultsHandler)resultsHandler {
  // Simulate the asynchronicity and delay of a web request...
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSArray* possibleItems = [JCAppDelegate possibleItems];

    NSMutableArray* predicates = [NSMutableArray new];
    for (__strong NSString* queryPart in [query componentsSeparatedByString:@" "]) {
      if (queryPart && (queryPart = [queryPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]).length > 0) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"SELF like[cd] %@", [NSString stringWithFormat:@"%@*", queryPart]]];
      }
    }
    NSPredicate* predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];

    NSArray* matchedItems = [possibleItems filteredArrayUsingPredicate:predicate];
    NSMutableArray* results = [NSMutableArray new];
    for (NSString* item in matchedItems) {
      [results addObject:@{@"label": item}];
    }

    double delayInSeconds = 0.4;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
      resultsHandler(results);
    });
  });
}

- (void) searchControllerCanceled:(JCAutocompletingSearchViewController*)searchController {
  UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Cancel Button Tapped"
                                                  message:@""
                                                 delegate:nil
                                        cancelButtonTitle:@"OK"
                                        otherButtonTitles:nil];
  [alert show];
}

- (void) searchController:(JCAutocompletingSearchViewController*)searchController
                tableView:(UITableView*)tableView
           selectedResult:(id)result {
  NSString* resultLabel = [(NSDictionary*)result objectForKey:@"label"];
  UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Result Selected"
                                                  message:[NSString stringWithFormat:@"Tapped result: %@", resultLabel]
                                                 delegate:nil
                                        cancelButtonTitle:@"OK"
                                        otherButtonTitles:nil];
  [alert show];
}

// Optional.
- (BOOL) searchControllerShouldPerformBlankSearchOnLoad:(JCAutocompletingSearchViewController*)searchController {
  return YES;
}

// Optional.
- (BOOL) searchController:(JCAutocompletingSearchViewController*)searchController shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

// Optional.
- (dispatch_time_t) searchControllerDelaySearchingUntilQueryUnchangedForTimeOffset:(JCAutocompletingSearchViewController*)searchController {
  return 0.2 * NSEC_PER_SEC;
}

// Optional.
- (BOOL) searchControllerShouldDisplayNetworkActivityIndicator:(JCAutocompletingSearchViewController*)searchController {
  return YES; // Defaults to YES.
}

// Optional.
- (void) searchController:(JCAutocompletingSearchViewController*)searchController didChangeActivityInProgressToEnabled:(BOOL)activityInProgress {
  NSLog(@"Activity indicator changed to: %@", (activityInProgress ? @"YES" : @"NO"));
}

@end
