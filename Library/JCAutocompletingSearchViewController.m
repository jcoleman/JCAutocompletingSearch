#import "JCAutocompletingSearchViewController.h"
#import "JCAutocompletingSearchGenericResultCell.h"

@interface JCAutocompletingSearchViewController ()

@property (nonatomic) BOOL loading;
@property (strong, nonatomic) NSArray* results;

@property (weak, nonatomic) IBOutlet UITableView *resultsTableView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@end

@implementation JCAutocompletingSearchViewController {
  NSObject* loadingMutex;
  NSUInteger loadingQueueCount;
  NSUInteger searchCounter;
  NSUInteger currentlyDisplaySearchID;
  BOOL delegateManagesTableViewCells;
  BOOL searchesPerformedSynchronously;
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
	// Do any additional setup after loading the view.

  if ( self.delegate
       && [self.delegate respondsToSelector:@selector(searchControllerShouldPerformBlankSearchOnLoad:)]
       && [self.delegate searchControllerShouldPerformBlankSearchOnLoad:self]) {
    [self searchBar:self.searchBar textDidChange:@""];
  }
}

- (void) viewDidUnload {
  [self setResultsTableView:nil];
  [self setSearchBar:nil];
  [super viewDidUnload];
  // Release any retained subviews of the main view.
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  if (self.delegate && [self.delegate respondsToSelector:@selector(searchController:shouldAutorotateToInterfaceOrientation:)]) {
    return [self.delegate searchController:self shouldAutorotateToInterfaceOrientation:interfaceOrientation];
  }
  return YES;
}

- (void) setDelegate:(NSObject<JCAutocompletingSearchViewControllerDelegate>*)delegate {
  _delegate = delegate;
  if (delegate && [delegate respondsToSelector:@selector(searchControllerUsesCustomResultTableViewCells:)]) {
    delegateManagesTableViewCells = [delegate searchControllerUsesCustomResultTableViewCells:self];
  } else {
    delegateManagesTableViewCells = NO;
  }

  if (delegate && [delegate respondsToSelector:@selector(searchControllerSearchesPerformedSynchronously:)]) {
    searchesPerformedSynchronously = [delegate searchControllerSearchesPerformedSynchronously:self];
  } else {
    searchesPerformedSynchronously = NO;
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
      NSArray* changedIndexPaths = @[[NSIndexPath indexPathForRow:0 inSection:0]];
      BOOL wasPreviouslyLoading = _loading;
      _loading = loading;
      if (wasPreviouslyLoading && !loading) {
        // Remove loading cell.
        [self.resultsTableView beginUpdates];
        [self.resultsTableView deleteRowsAtIndexPaths:changedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.resultsTableView endUpdates];
      } else if (!wasPreviouslyLoading && loading) {
        // Add loading cell.
        [self.resultsTableView beginUpdates];
        [self.resultsTableView insertRowsAtIndexPaths:changedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.resultsTableView endUpdates];
      }
    } else {
      _loading = NO;
    }
  }
}

#pragma mark - UISearchBarDelegate Implementation

- (void) searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)searchText {
  ++loadingQueueCount;
  ++searchCounter;
  NSUInteger searchID = searchCounter;
  [self setLoading:YES];

  [self.delegate searchController:self performSearchForQuery:searchText withResultsHandler:^(NSArray* searchResults) {
    if (searchID >= currentlyDisplaySearchID) {
      currentlyDisplaySearchID = searchID;
      if (searchResults) {
        self.results = searchResults;
        [self.resultsTableView reloadData];
      }
    } else {
      NSLog(@"JCAutocompletingSearchController: received out-of-order search results; ignoring. (currently displayed: %i, searchID: %i", currentlyDisplaySearchID, searchID);
    }
    --loadingQueueCount;
    if (loadingQueueCount == 0) {
      [self setLoading:NO];
    }
  }];
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
                 selectedResult:[self.results objectAtIndex:row]];
}


#pragma mark - UITableViewDataSource Implementation

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return self.results.count + (self.loading ? 1 : 0);
  } else {
    return 0;
  }
}

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  NSUInteger row = indexPath.row;
  if (self.loading) {
    if (row == 0) {
      return [self.resultsTableView dequeueReusableCellWithIdentifier:@"LoadingCell"];
    } else {
      --row;
    }
  }

  if (delegateManagesTableViewCells) {
    return [self.delegate searchController:self tableView:self.resultsTableView cellForRowAtIndexPath:indexPath];
  } else {
    if (row < self.results.count) {
      NSDictionary* result = (NSDictionary*)[self.results objectAtIndex:row];
      JCAutocompletingSearchGenericResultCell* cell = (JCAutocompletingSearchGenericResultCell*)[self.resultsTableView dequeueReusableCellWithIdentifier:@"ResultCell"];
      cell.resultLabel.text = [result objectForKey:@"label"];
      return cell;
    } else {
      return Nil;
    }
  }
}

@end
