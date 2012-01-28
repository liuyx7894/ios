//
//  DDGViewController.h
//  DuckDuckGo2
//
//  Created by Chris Heimark on 12/9/11.
//  Copyright (c) 2011 DuckDuckGo, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DDGSearchController.h"
#import "DataHelper.h"

@interface DDGViewController : UIViewController<UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, DDGSearchHandler, DataHelperDelegate>
{
	IBOutlet UITableViewCell *loadedCell;
	IBOutlet UITableView *tableView;
	IBOutlet DDGSearchController *searchController;
	
	id entries;
	DataHelper *dataHelper;

    NSString *webQuery;
    NSString *webURL;
}

@property (nonatomic, strong) IBOutlet UITableViewCell *loadedCell;
@property (nonatomic, strong) IBOutlet UITableView	*tableView;
@property (nonatomic, strong) IBOutlet DDGSearchController *searchController;

@property (nonatomic, strong) id entries;

- (void)loadEntries;
- (UIImage*)loadImage:(NSString*)url;

@end
