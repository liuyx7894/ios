//
//  DDGStoriesProvider.m
//  DuckDuckGo
//
//  Created by Ishaan Gulrajani on 7/17/12.
//
//

#import "DDGStoriesProvider.h"
#import "DDGCache.h"

#import "NSArray+ConcurrentIteration.h"

@implementation DDGStoriesProvider
static DDGStoriesProvider *sharedProvider;

#pragma mark - Lifecycle

+(DDGStoriesProvider *)sharedProvider {
    @synchronized(self) {
        if(!sharedProvider)
            sharedProvider = [[DDGStoriesProvider alloc] init];
        
        return sharedProvider;
    }
}

#pragma mark - Downloading sources

-(void)downloadSources {
    NSURL *url = [NSURL URLWithString:@"http://caine.duckduckgo.com/watrcoolr.js?o=json&type_info=1"];
    NSData *response = [NSData dataWithContentsOfURL:url];
    NSArray *newSources = [NSJSONSerialization JSONObjectWithData:response 
                                                          options:NSJSONReadingMutableContainers 
                                                            error:nil];
    for(NSMutableDictionary *source in newSources) {
        
        // if not found, oldSource will be nil
        int oldSourceID = [self indexOfSourceWithID:[source objectForKey:@"id"]];
        
        if(oldSourceID != NSNotFound)
            [source setObject:[[self.sources objectAtIndex:oldSourceID] objectForKey:@"enabled"] forKey:@"enabled"];
        else
            [source setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
        
    }
    
    [DDGCache setObject:newSources forKey:@"sources" inCache:@"misc"];
}

-(NSArray *)sources {
    return [DDGCache objectForKey:@"sources" inCache:@"misc"];
}

-(NSArray *)enabledSourceIDs {
    NSArray *sources = self.sources;
    NSMutableArray *enabledSources = [[NSMutableArray alloc] initWithCapacity:sources.count];
    for(NSDictionary *source in sources) {
        if([[source objectForKey:@"enabled"] boolValue])
            [enabledSources addObject:[source objectForKey:@"id"]];
    }
    return enabledSources;
}

-(int)indexOfSourceWithID:(NSString *)sourceID {
    NSArray *oldSources = [DDGCache objectForKey:@"sources" inCache:@"misc"];

    __block int result = NSNotFound;
    [oldSources enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if([[obj objectForKey:@"id"] isEqualToString:sourceID]) {
            result = idx;
        }
    }];

    return result;
}

-(void)setSourceWithID:(NSString *)sourceID enabled:(BOOL)enabled {
    NSMutableArray *sources = [self.sources mutableCopy];

    int sourceIdx = [self indexOfSourceWithID:sourceID];
    NSMutableDictionary *source = [[sources objectAtIndex:sourceIdx] mutableCopy];
    [source setObject:[NSNumber numberWithBool:enabled] forKey:@"enabled"];
    
    [sources removeObjectAtIndex:sourceIdx];
    [sources addObject:source];
    
    [DDGCache setObject:sources forKey:@"sources" inCache:@"misc"];
}

#pragma mark - Downloading stories

-(NSArray *)stories {
    return [DDGCache objectForKey:@"stories" inCache:@"misc"];
}

-(void)downloadStoriesInTableView:(UITableView *)tableView success:(void (^)())success {
    // do everything in the background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        
        [self downloadSources];
        
        NSString *urlStr = @"http://caine.duckduckgo.com/watrcoolr.js?o=json&s=";
        urlStr = [urlStr stringByAppendingString:[[self enabledSourceIDs] componentsJoinedByString:@","]];
        
        NSURL *url = [NSURL URLWithString:urlStr];
        NSData *response = [NSData dataWithContentsOfURL:url];
        NSArray *newStories = [NSJSONSerialization JSONObjectWithData:response
                                                              options:0
                                                                error:nil];
        
        NSArray *addedStories = [self indexPathsofStoriesInArray:newStories andNotArray:self.stories];
        NSArray *removedStories = [self indexPathsofStoriesInArray:self.stories andNotArray:newStories];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // update the stories array
            [DDGCache setObject:newStories forKey:@"stories" inCache:@"misc"];
            
            // record the last-updated time
            [DDGCache setObject:[NSDate date] forKey:@"storiesUpdated" inCache:@"misc"];
            
            // update the table view with added and removed stories
            [tableView beginUpdates];
            [tableView insertRowsAtIndexPaths:addedStories
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView deleteRowsAtIndexPaths:removedStories
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView endUpdates];
                        
            // execute the given callback
            success();
        });
        
        // download story images (this method doesn't return until all story images are downloaded)
        [newStories iterateConcurrentlyWithThreads:5 block:^(int i, id obj) {
            NSDictionary *story = (NSDictionary *)obj;
            BOOL reload = NO;
            
            if(![DDGCache objectForKey:[story objectForKey:@"id"] inCache:@"storyImages"]) {
                
                // main image: download it and resize it as needed
                NSString *imageURL = [story objectForKey:@"image"];
                NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];
                UIImage *image = [UIImage imageWithData:imageData];
                
                if(!image)
                    image = [UIImage imageNamed:@"noimage.png"];

                [DDGCache setObject:imageData forKey:[story objectForKey:@"id"] inCache:@"storyImages"];
                reload = YES;
            }
            
            if(![DDGCache objectForKey:[story objectForKey:@"id"] inCache:@"faviconImages"]) {
                // favicon
                NSString *storyURL = [story objectForKey:@"url"];
                [self loadFaviconForURLString:storyURL storyID:[story objectForKey:@"id"]];
                reload = YES;
            }
            
            if(reload) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
                });
            }
            
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // execute the given callback
            success();
        });
            
    });
}

-(NSArray *)indexPathsofStoriesInArray:(NSArray *)newStories andNotArray:(NSArray *)oldStories {
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    
    for(int i=0;i<newStories.count;i++) {
        NSString *storyID = [[newStories objectAtIndex:i] objectForKey:@"id"];
        
        BOOL matchFound = NO;
        for(NSDictionary *oldStory in oldStories) {
            if([storyID isEqualToString:[oldStory objectForKey:@"id"]]) {
                matchFound = YES;
                break;
            }
        }
        
        if(!matchFound)
            [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    }
    return [indexPaths copy];
}

-(NSURL *)faviconURLForDomain:(NSString *)domain {
    // http://i2.duck.co/i/reddit.com.ico
    NSString *faviconURLString = [NSString stringWithFormat:@"http://i2.duck.co/i/%@.ico",domain];
    return [NSURL URLWithString:faviconURLString];
}

-(void)loadFaviconForURLString:(NSString *)urlString storyID:(NSString *)storyID {
    if(!urlString || [urlString isEqual:[NSNull null]])
        return;
    
    NSString *domain = [[NSURL URLWithString:urlString] host];
    
    while(![DDGCache objectForKey:storyID inCache:@"faviconImages"]) {
        NSData *response = [NSData dataWithContentsOfURL:[self faviconURLForDomain:domain]];
        [DDGCache setObject:response forKey:storyID inCache:@"faviconImages"];
        
        NSMutableArray *domainParts = [[domain componentsSeparatedByString:@"."] mutableCopy];
        if(domainParts.count == 1)
            return; // we're definitely down to just a TLD by now and still couldn't get a favicon.
        [domainParts removeObjectAtIndex:0];
        domain = [domainParts componentsJoinedByString:@"."];
    }
}

@end