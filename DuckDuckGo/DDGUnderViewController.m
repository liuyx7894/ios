//
//  DDGUnderViewController.m
//  DuckDuckGo
//
//  Created by Ishaan Gulrajani on 8/14/12.
//
//

#import "DDGUnderViewController.h"
#import "DDGSettingsViewController.h"
#import "DDGWebViewController.h"
#import "DDGHistoryProvider.h"
#import "DDGBookmarksViewController.h"
#import "DDGStoriesViewController.h"
#import "DDGDuckViewController.h"
#import "DDGUnderViewControllerCell.h"
#import "DDGHistoryItemCell.h"
#import "DDGStory.h"
#import "DDGStoryFeed.h"
#import "DDGHistoryItem.h"
#import "DDGPlusButton.h"
#import "DDGHistoryViewController.h"

#import "DDGMenuItemCell.h"
#import "DDGMenuSectionHeaderView.h"


NSString * const DDGViewControllerTypeTitleKey = @"title";
NSString * const DDGViewControllerTypeTypeKey = @"type";
NSString * const DDGViewControllerTypeControllerKey = @"viewController";
NSString * const DDGSavedViewLastSelectedTabIndex = @"saved tab index";

@interface DDGUnderViewController () <DDGTableViewAdditionalSectionsDelegate>
@property (nonatomic, strong) NSIndexPath *menuIndexPath;
@property (nonatomic, strong) NSArray *viewControllerTypes;
@property (nonatomic, readwrite, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) DDGHistoryViewController *historyViewController;
@end

@implementation DDGUnderViewController

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)moc {
    self = [super initWithNibName:nil bundle:nil];
    if(self) {
        self.managedObjectContext = moc;        
        [self setupViewControllerTypes];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setClipsToBounds:YES];
    
    DDGHistoryViewController *historyViewController = [[DDGHistoryViewController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext  mode:DDGHistoryViewControllerModeUnder];
    historyViewController.additionalSectionsDelegate = self;
    
    historyViewController.view.frame = self.view.bounds;
    historyViewController.tableView.scrollsToTop = NO;
    [historyViewController.tableView registerNib:[UINib nibWithNibName:@"DDGMenuItemCell" bundle:nil]
                          forCellReuseIdentifier:@"DDGMenuItemCell"];
    
    historyViewController.overhangWidth = 74;
    
    [self.view addSubview:historyViewController.view];
    [self addChildViewController:historyViewController];
    
    self.historyViewController = historyViewController;
    
    [historyViewController didMoveToParentViewController:self];
    
    UIView *decorationView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, CGRectGetHeight(self.view.bounds), 4.0f)];
    decorationView.backgroundColor = [UIColor duckRed];
    [self.view addSubview:decorationView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    if (![self isViewLoaded] || nil == self.view.superview) {
        self.historyViewController = nil;
    }
}

- (void)setupViewControllerTypes {
    
    DDGViewControllerType selectedType = DDGViewControllerTypeHome;
    NSIndexPath *menuIndexPath = self.menuIndexPath;
    
    if (menuIndexPath.section == 0 && menuIndexPath.row < [self.viewControllerTypes count]) {
        selectedType = [[[self.viewControllerTypes objectAtIndex:menuIndexPath.row] valueForKey:DDGViewControllerTypeTypeKey] integerValue];
    }
    
    NSMutableArray *types = [NSMutableArray array];
    
    NSString *homeViewMode = [[NSUserDefaults standardUserDefaults] objectForKey:DDGSettingHomeView];
    
    if ([homeViewMode isEqualToString:DDGSettingHomeViewTypeRecents]) {
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Home",
                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeHistory)
                          } mutableCopy]];
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Stories",
                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeStories)
                          } mutableCopy]];
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Favorites",
                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeSaved)
                          } mutableCopy]];
    } else if ([homeViewMode isEqualToString:DDGSettingHomeViewTypeSaved]) {
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Home",
                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeSaved)
                          } mutableCopy]];
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Stories",
                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeStories)
                          } mutableCopy]];
    } else if ([homeViewMode isEqualToString:DDGSettingHomeViewTypeDuck]) {
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Home",
                            DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeDuck)
                            } mutableCopy]];
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Stories",
                            DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeStories)
                            } mutableCopy]];
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Favorites",
                            DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeSaved)
                            } mutableCopy]];
    } else {
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Home",
                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeHome)
                          } mutableCopy]];
        [types addObject:[@{DDGViewControllerTypeTitleKey : @"Favorites",
                          DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeSaved)
                          } mutableCopy]];        
    }
    
    [types addObject:[@{DDGViewControllerTypeTitleKey : @"Settings",
                      DDGViewControllerTypeTypeKey: @(DDGViewControllerTypeSettings)
                      } mutableCopy]];
    
    self.viewControllerTypes = types;
    
    for (NSDictionary *typeInfo in types) {
        if ([[typeInfo valueForKey:DDGViewControllerTypeTypeKey] integerValue] == selectedType) {
            self.menuIndexPath = [NSIndexPath indexPathForRow:[types indexOfObject:typeInfo] inSection:0];
        }
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setupViewControllerTypes];
    
    NSString *homeViewMode = [[NSUserDefaults standardUserDefaults] objectForKey:DDGSettingHomeView];
    self.historyViewController.showsHistory = ![homeViewMode isEqualToString:DDGSettingHomeViewTypeRecents];
    [self.historyViewController.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

#pragma mark - DDGTableViewAdditionalSectionsDelegate

- (NSInteger)numberOfAdditionalSections {
    return 1;
}

#pragma mark - DDGSearchHandler

- (void)beginSearchInputWithString:(NSString *)string
{
    UIViewController *contentViewController = [self.slideOverMenuController contentViewController];
    if (contentViewController && [contentViewController isKindOfClass:[DDGSearchController class]]) {
        DDGSearchController *searchController = (DDGSearchController *)contentViewController;
        DDGAddressBarTextField *searchField = [searchController.searchBar searchField];
        [self.slideOverMenuController hideMenu:YES completion:^{
            [searchField becomeFirstResponder];
            searchField.text = string;
            [searchController searchFieldDidChange:nil];
        }];
    } else {
        [self loadQueryOrURL:string];
    }
}

- (void)prepareForUserInput {
    DDGWebViewController *webVC = [[DDGWebViewController alloc] initWithNibName:nil bundle:nil];
    DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:webVC managedObjectContext:self.managedObjectContext];
    webVC.searchController = searchController;
    
    [searchController pushContentViewController:webVC animated:NO];
    searchController.state = DDGSearchControllerStateWeb;
    
    [self.slideOverMenuController setContentViewController:searchController];
    
    [searchController.searchBar.searchField becomeFirstResponder];
}

-(void)searchControllerLeftButtonPressed {
    [self.slideOverMenuController showMenu];
}

-(void)loadStory:(DDGStory *)story readabilityMode:(BOOL)readabilityMode {
    DDGWebViewController *webVC = [[DDGWebViewController alloc] initWithNibName:nil bundle:nil];
    DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:webVC managedObjectContext:self.managedObjectContext];
    webVC.searchController = searchController;
    
    [searchController pushContentViewController:webVC animated:NO];
    searchController.state = DDGSearchControllerStateWeb;    
    
    [webVC loadStory:story readabilityMode:readabilityMode];
    self.menuIndexPath = nil;
    
    if (searchController) {
        [self.slideOverMenuController setContentViewController:searchController];
        [self.slideOverMenuController hideMenu];
    }
    
}

-(void)loadQueryOrURL:(NSString *)queryOrURL {
    DDGWebViewController *webVC = [[DDGWebViewController alloc] initWithNibName:nil bundle:nil];
    DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:webVC managedObjectContext:self.managedObjectContext];
    webVC.searchController = searchController;
    
    [searchController pushContentViewController:webVC animated:NO];
    searchController.state = DDGSearchControllerStateWeb;    
    
    [webVC loadQueryOrURL:queryOrURL];
    self.menuIndexPath = nil;    

    if (searchController) {
        [self.slideOverMenuController setContentViewController:searchController];
        [self.slideOverMenuController hideMenu];
    }
}


#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.viewControllerTypes.count;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DDGMenuItemCell *menuItemCell = (DDGMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:@"DDGMenuItemCell"];
    [self configureCell:menuItemCell atIndexPath:indexPath];
    return menuItemCell;
}

- (void)configureCell:(DDGMenuItemCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == 0)
	{
        cell.title = [[self.viewControllerTypes objectAtIndex:indexPath.row] objectForKey:DDGViewControllerTypeTitleKey];
        
        NSDictionary *typeInfo = [self.viewControllerTypes objectAtIndex:indexPath.row];
        DDGViewControllerType type = [[typeInfo objectForKey:DDGViewControllerTypeTypeKey] integerValue];
        
		switch (type)
		{
			case DDGViewControllerTypeHome:
			case DDGViewControllerTypeHistory:
            case DDGViewControllerTypeDuck:
			{
                cell.icon = [UIImage imageNamed:@"Home"];
			}
				break;
			case DDGViewControllerTypeSaved:
			{
                cell.icon = [UIImage imageNamed:@"Saved"];
			}
				break;
			case DDGViewControllerTypeStories:
			{
                cell.icon = [UIImage imageNamed:@"Stories"];
			}
				break;
			case DDGViewControllerTypeSettings:
			{
                cell.icon = [UIImage imageNamed:@"Settings"];
			}
				break;
		}
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    //return 50.0f;
    return 64.0f;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UINib *nib = [UINib nibWithNibName:@"DDGMenuSectionHeaderView" bundle:nil];
    DDGMenuSectionHeaderView *sectionHeaderView = (DDGMenuSectionHeaderView *)[nib instantiateWithOwner:nil options:nil][0];
    __weak DDGUnderViewController *weakSelf = self;
    sectionHeaderView.closeBlock = ^(){
        [weakSelf.slideOverMenuController hideMenu];
    };
//    sectionHeaderView.title = @"Menu";
    sectionHeaderView.title = @"";
    return sectionHeaderView;
}

#pragma mark - Table view delegate

/*
- (NSIndexPath*)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1 && ![[NSUserDefaults standardUserDefaults] boolForKey:DDGSettingRecordHistory])
		return nil;
	
    DDGUnderViewControllerCell *oldMenuCell;
    oldMenuCell = (DDGUnderViewControllerCell *)[tableView cellForRowAtIndexPath:self.menuIndexPath];
    oldMenuCell.active = NO;
    
    DDGUnderViewControllerCell *newMenuCell;
    newMenuCell = (DDGUnderViewControllerCell *)[tableView cellForRowAtIndexPath:indexPath];
    newMenuCell.active = YES;
    
	return indexPath;
}
*/

- (UIViewController *)viewControllerForType:(DDGViewControllerType)type {
    UIViewController *viewController = nil;
    
    switch (type) {
        case DDGViewControllerTypeSaved:
        {
            DDGBookmarksViewController *bookmarks = [[DDGBookmarksViewController alloc] initWithNibName:@"DDGBookmarksViewController" bundle:nil];
            bookmarks.title = NSLocalizedString(@"Searches", @"View controller title: Saved Searches");
            
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.state = DDGSearchControllerStateHome;
            searchController.shouldPushSearchHandlerEvents = YES;
            
            DDGStoriesViewController *stories = [[DDGStoriesViewController alloc] initWithSearchHandler:searchController managedObjectContext:self.managedObjectContext];
            stories.savedStoriesOnly = YES;
            stories.title = NSLocalizedString(@"Stories", @"View controller title: Saved Stories");
            
            DDGTabViewController *tabViewController = [[DDGTabViewController alloc] initWithViewControllers:@[bookmarks, stories]];            
            
            bookmarks.searchController = searchController;
            bookmarks.searchHandler = searchController;
            
            tabViewController.controlViewPosition = DDGTabViewControllerControlViewPositionBottom;
            tabViewController.controlView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
            tabViewController.controlView.backgroundColor = [UIColor duckLightGray];
            [tabViewController.segmentedControl sizeToFit];

            CGRect controlBounds = tabViewController.controlView.bounds;
            CGSize segmentSize = tabViewController.segmentedControl.frame.size;
            segmentSize.width = controlBounds.size.width - 10.0;
            CGRect controlRect = CGRectMake(controlBounds.origin.x + ((controlBounds.size.width - segmentSize.width) / 2.0),
                                            controlBounds.origin.y + ((controlBounds.size.height - segmentSize.height) / 2.0),
                                            segmentSize.width,
                                            segmentSize.height);
            tabViewController.segmentedControl.frame = CGRectIntegral(controlRect);
            tabViewController.segmentedControl.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
            tabViewController.searchControllerBackButtonIconDDG = [[UIImage imageNamed:@"Saved"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

            [tabViewController.controlView addSubview:tabViewController.segmentedControl];
            tabViewController.currentViewControllerIndex = [[NSUserDefaults standardUserDefaults] integerForKey:DDGSavedViewLastSelectedTabIndex];
            tabViewController.delegate = self;
            
            [searchController pushContentViewController:tabViewController animated:NO];            
            
            viewController = searchController;
        }
            
            break;
        case DDGViewControllerTypeHistory: {
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.shouldPushSearchHandlerEvents = YES;
            searchController.state = DDGSearchControllerStateHome;
            DDGHistoryViewController *history = [[DDGHistoryViewController alloc] initWithSearchHandler:searchController managedObjectContext:self.managedObjectContext mode:DDGHistoryViewControllerModeNormal];
            [searchController pushContentViewController:history animated:NO];
            viewController = searchController;
        }
            break;
        case DDGViewControllerTypeStories: {
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.shouldPushSearchHandlerEvents = YES;
            searchController.state = DDGSearchControllerStateHome;
            DDGStoriesViewController *stories = [[DDGStoriesViewController alloc] initWithSearchHandler:searchController managedObjectContext:self.managedObjectContext];
            stories.searchControllerBackButtonIconDDG = [[UIImage imageNamed:@"Stories"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [searchController pushContentViewController:stories animated:NO];
            viewController = searchController;
        }
            break;
        case DDGViewControllerTypeSettings: {
            
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.state = DDGSearchControllerStateHome;
            DDGSettingsViewController *settings = [[DDGSettingsViewController alloc] initWithDefaults];
            settings.managedObjectContext = self.managedObjectContext;
            [searchController pushContentViewController:settings animated:NO];
            viewController = searchController;
            break;
        }
        case DDGViewControllerTypeHome:
        {
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.shouldPushSearchHandlerEvents = YES;
            DDGStoriesViewController *stories = [[DDGStoriesViewController alloc] initWithSearchHandler:searchController managedObjectContext:self.managedObjectContext];
            stories.searchControllerBackButtonIconDDG = [[UIImage imageNamed:@"Home"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [searchController pushContentViewController:stories animated:NO];
            searchController.state = DDGSearchControllerStateHome;
            viewController = searchController;
            break;
        }
        case DDGViewControllerTypeDuck:
        {
            DDGSearchController *searchController = [[DDGSearchController alloc] initWithSearchHandler:self managedObjectContext:self.managedObjectContext];
            searchController.shouldPushSearchHandlerEvents = YES;
            DDGDuckViewController *duckViewController = [[DDGDuckViewController alloc] initWithSearchController:searchController];
            [searchController pushContentViewController:duckViewController animated:NO];
            searchController.state = DDGSearchControllerStateHome;
            viewController = searchController;
        }
        default:
            break;
    }
    
    return viewController;
}

- (UIViewController *)viewControllerForIndexPath:(NSIndexPath *)indexPath {
    UIViewController *viewController = nil;
    
    if(indexPath.section == 0)
    {
        NSDictionary *typeInfo = [self.viewControllerTypes objectAtIndex:indexPath.row];
        viewController = [typeInfo objectForKey:DDGViewControllerTypeControllerKey];
        
        if (nil == viewController) {
            DDGViewControllerType type = [[typeInfo objectForKey:DDGViewControllerTypeTypeKey] integerValue];
            viewController = [self viewControllerForType:type];            
        }
    }
    
    return viewController;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.menuIndexPath = indexPath;
    if (indexPath.section == 0) {
        UIViewController *contentViewController = [self viewControllerForIndexPath:indexPath];
        if (contentViewController) {
            [self.slideOverMenuController setContentViewController:contentViewController];
            [self.slideOverMenuController hideMenu];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - DDGTabViewControllerDelegate

- (void)tabViewController:(DDGTabViewController *)tabViewController didSwitchToViewController:(UIViewController *)viewController atIndex:(NSInteger)tabIndex {
    [[NSUserDefaults standardUserDefaults] setInteger:tabIndex forKey:DDGSavedViewLastSelectedTabIndex];
}

@end
