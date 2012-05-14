//
//  HomeAlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class Artist, Album;

@interface HomeAlbumViewController : UITableViewController 

@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableArray *listOfAlbums;
@property (nonatomic, copy) NSString *modifier;
@property (nonatomic) NSUInteger offset;
@property (nonatomic) BOOL isMoreAlbums;
@property (nonatomic) BOOL isLoading;

- (void)cancelLoad;

@end
