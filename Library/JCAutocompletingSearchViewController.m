#import "JCAutocompletingSearchViewController.h"
#import "JCAutocompletingSearchGenericResultCell.h"

@interface JCAutocompletingSearchViewController ()

@property (nonatomic) BOOL loading;
@property (strong, nonatomic) NSArray* results;

@end

@implementation JCAutocompletingSearchViewController {
  NSObject* loadingMutex;
  NSUInteger loadingQueueCount;
  NSUInteger searchCounter;
  NSUInteger currentlyDisplaySearchID;
  BOOL delegateManagesTableViewCells;
  BOOL searchesPerformedSynchronously;
  dispatch_time_t delaySearchUntilQueryUnchangedForTimeOffset;
  BOOL shouldDisplayNetworkActivityIndicator;
  BOOL networkActivityIndicatorWasVisibleWhenLoadingBegan;
}

+ (JCAutocompletingSearchViewController*) autocompletingSearchViewController {
  UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"JCAutocompletingSearchStoryboard" bundle:nil];
  return (JCAutocompletingSearchViewController*)[storyboard instantiateViewControllerWithIdentifier:@"SearchViewController"];
}

- (id) initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    self.results = @[];
    self.loading = NO;
    loadingMutex = [NSObject new];
  }
  return self;
}

- (void) viewDidLoad {
  [super viewDidLoad];

  if ( self.delegate
       && [self.delegate respondsToSelector:@selector(searchControllerShouldPerformBlankSearchOnLoad:)]
       && [self.delegate searchControllerShouldPerformBlankSearchOnLoad:self]) {
    [self executeSearchForQuery:@"" delayedBatching:NO];
  } else {
    [self.searchBar becomeFirstResponder];
  }
}

- (void) viewDidUnload {
  [self setResultsTableView:nil];
  [self setSearchBar:nil];

  [super viewDidUnload];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  if (self.delegate && [self.delegate respondsToSelector:@selector(searchController:shouldAutorotateToInterfaceOrientation:)]) {
    return [self.delegate searchController:self shouldAutorotateToInterfaceOrientation:interfaceOrientation];
  }
  return YES;
}

- (void) setDelegate:(NSObject<JCAutocompletingSearchViewControllerDelegate>*)delegate {
  _delegate = delegate;

  delegateManagesTableViewCells = NO;
  searchesPerformedSynchronously = NO;
  delaySearchUntilQueryUnchangedForTimeOffset = 0;
  shouldDisplayNetworkActivityIndicator = YES;

  if (delegate) {
    if ([delegate respondsToSelector:@selector(searchControllerUsesCustomResultTableViewCells:)]) {
      delegateManagesTableViewCells = [delegate searchControllerUsesCustomResultTableViewCells:self];
    }
    if ([delegate respondsToSelector:@selector(searchControllerSearchesPerformedSynchronously:)]) {
      searchesPerformedSynchronously = [delegate searchControllerSearchesPerformedSynchronously:self];
    }
    if ([delegate respondsToSelector:@selector(searchControllerDelaySearchingUntilQueryUnchangedForTimeOffset:)]) {
      delaySearchUntilQueryUnchangedForTimeOffset = [delegate searchControllerDelaySearchingUntilQueryUnchangedForTimeOffset:self];
    }
    if ([delegate respondsToSelector:@selector(searchControllerShouldDisplayNetworkActivityIndicator:)]) {
      shouldDisplayNetworkActivityIndicator = [delegate searchControllerShouldDisplayNetworkActivityIndicator:self];
    }
  }
}


// -------------------------------------------------
// Code originally from: http://stackoverflow.com/a/12406117/1114761

- (void) viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Search for Cancel button in searchbar, enable it and add key-value observer.
  for (id subview in [self.searchBar subviews]) {
    if ([subview isKindOfClass:[UIButton class]]) {
      [subview setEnabled:YES];
      [subview addObserver:self forKeyPath:@"enabled" options:NSKeyValueObservingOptionNew context:nil];
    }
  }
}

- (void) viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  // Remove observer for the Cancel button in searchBar.
  for (id subview in [self.searchBar subviews]) {
    if ([subview isKindOfClass:[UIButton class]]) {
      [subview removeObserver:self forKeyPath:@"enabled"];
    }
  }
}

- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
  // Re-enable the Cancel button in searchBar.
  if ([object isKindOfClass:[UIButton class]] && [keyPath isEqualToString:@"enabled"]) {
    UIButton *button = object;
    if (!button.enabled)
      button.enabled = YES;
  }
}

// -------------------------------------------------

- (void) setLoading:(BOOL)loading {
  @synchronized(loadingMutex) {
    if (!searchesPerformedSynchronously) {
      UIApplication* application = [UIApplication sharedApplication];
      if (!_loading && loading) {
        networkActivityIndicatorWasVisibleWhenLoadingBegan = application.networkActivityIndicatorVisible;
        if (shouldDisplayNetworkActivityIndicator) {
          application.networkActivityIndicatorVisible = YES;
        }
        if ([self.delegate respondsToSelector:@selector(searchController:didChangeActivityInProgressToEnabled:)]) {
          [self.delegate searchController:self didChangeActivityInProgressToEnabled:YES];
        }
      } else if (_loading && !loading) {
        if (shouldDisplayNetworkActivityIndicator) {
          application.networkActivityIndicatorVisible = NO;
        }
        if ([self.delegate respondsToSelector:@selector(searchController:didChangeActivityInProgressToEnabled:)]) {
          [self.delegate searchController:self didChangeActivityInProgressToEnabled:NO];
        }
      }
      _loading = loading;
    } else {
      _loading = NO;
    }
  }
}

- (void) resetSelection {
  NSIndexPath* selectedRow = [self.resultsTableView indexPathForSelectedRow];
  if (selectedRow) {
    [self.resultsTableView deselectRowAtIndexPath:selectedRow animated:NO];
  }
}

- (void) setSearchBarTextAndPerformSearch:(NSString*)query {
  self.searchBar.text = query;
  [self searchBar:self.searchBar textDidChange:query];
}

- (NSDictionary*) resultForRowAtIndex:(NSUInteger)resultIndex {
  return [self.results objectAtIndex:resultIndex];
}

#pragma mark - UISearchBarDelegate Implementation

- (void) searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)searchText {
  [self executeSearchForQuery:searchText delayedBatching:(delaySearchUntilQueryUnchangedForTimeOffset != 0)];
}

- (void) searchBarSearchButtonClicked:(UISearchBar*)searchBar {
  [self executeSearchForQuery:searchBar.text delayedBatching:NO];
}

- (void) executeSearchForQuery:(NSString*)query delayedBatching:(BOOL)delayedBatching {
  ++loadingQueueCount;
  ++searchCounter;

  NSUInteger searchID = searchCounter;
  if (delayedBatching) {
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delaySearchUntilQueryUnchangedForTimeOffset);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
      if (searchID == searchCounter) {
        // The query hasn't changed during the delay.
        [self executeSearchForQuery:query searchID:searchID];
      } else {
        // The query changed during the delay.
        [self decrementQueueCounter];
      }
    });
  } else {
    [self executeSearchForQuery:query searchID:searchID];
  }
}

- (void) executeSearchForQuery:(NSString*)query searchID:(NSUInteger)searchID {
  __block BOOL searchResultsReturned = NO;
  [self setLoading:YES];

  [self.delegate searchController:self performSearchForQuery:query withResultsHandler:^(NSArray* searchResults) {
    NSAssert(!searchResultsReturned, @"JCAutocompletingSearchController: delegate called results handler more than once for the same search execution.");
    searchResultsReturned = YES;

    if (searchID >= currentlyDisplaySearchID) {
      currentlyDisplaySearchID = searchID;
      if (searchResults) {
        self.results = searchResults;
        [self.resultsTableView reloadData];
      }
    } else {
      NSLog(@"JCAutocompletingSearchController: received out-of-order search results; ignoring. (currently displayed: %i, searchID: %i", currentlyDisplaySearchID, searchID);
    }
    [self decrementQueueCounter];
  }];
}

- (void) decrementQueueCounter {
  --loadingQueueCount;
  if (loadingQueueCount == 0) {
    [self setLoading:NO];
  }
}

- (void) searchBarCancelButtonClicked:(UISearchBar*)searchBar {
  [self.delegate searchControllerCanceled:self];
}


#pragma mark - UITableViewDelegate Implementation

- (CGFloat) tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
  if (delegateManagesTableViewCells) {
    return [self.delegate searchController:self tableView:self.resultsTableView heightForRowAtIndexPath:indexPath];
  } else {
    return self.resultsTableView.rowHeight;
  }
}

- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  NSUInteger row = indexPath.row;
  if (self.loading) {
    if (row == 0) {
      [tableView deselectRowAtIndexPath:indexPath animated:NO];
      return;
    } else {
      --row;
    }
  }

  [self.delegate searchController:self
                        tableView:self.resultsTableView
                   selectedResult:[self resultForRowAtIndex:row]];
}


#pragma mark - UITableViewDataSource Implementation

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return self.results.count;
  } else {
    return 0;
  }
}

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  NSUInteger row = indexPath.row;
  if (row < self.results.count) {
    if (delegateManagesTableViewCells) {
      return [self.delegate searchController:self tableView:self.resultsTableView cellForRowAtIndexPath:indexPath];
    } else {
      NSDictionary* result = (NSDictionary*)[self.results objectAtIndex:row];
      JCAutocompletingSearchGenericResultCell* cell = (JCAutocompletingSearchGenericResultCell*)[self.resultsTableView dequeueReusableCellWithIdentifier:@"ResultCell"];
      cell.resultLabel.text = [result objectForKey:@"label"];
      return cell;
    }
  } else {
    NSLog(@"JCAutocompletingSearch: results table view attempted to load row %u but only %u result(s) exist.", row, self.results.count);
    return Nil;
  }
}


#pragma mark - UIScrollViewDelegate Implementation

- (void) scrollViewWillBeginDragging:(UIScrollView*)scrollView {
  [self.searchBar resignFirstResponder];
}

@end
