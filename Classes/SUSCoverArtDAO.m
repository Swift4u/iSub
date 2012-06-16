//
//  SUSCoverArtLargeDAO.m
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtDAO.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"

#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "ISMSCoverArtLoader.h"

@implementation SUSCoverArtDAO
@synthesize delegate, isLarge, coverArtId, loader;

- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate
{
	if ((self = [super init]))
	{
		delegate = theDelegate;
	}
	return self;
}

- (id)initWithDelegate:(NSObject<ISMSLoaderDelegate> *)theDelegate coverArtId:(NSString *)artId isLarge:(BOOL)large
{
	if ((self = [super init]))
	{
		delegate = theDelegate;
		isLarge = large;
		coverArtId = [artId copy];
	}
	return self;
}

- (void)dealloc
{
	[loader cancelLoad];
	loader.delegate = nil;
}

#pragma mark - Private DB Methods

- (FMDatabaseQueue *)dbQueue
{
	if (self.isLarge)
		return IS_IPAD() ? databaseS.coverArtCacheDb540Queue : databaseS.coverArtCacheDb320Queue;
	else
		return databaseS.coverArtCacheDb60Queue;
}

#pragma mark - Public DAO methods

- (UIImage *)coverArtImage
{
    NSData *imageData = [self.dbQueue dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [self.coverArtId md5]];
    return imageData ? [UIImage imageWithData:imageData] : self.defaultCoverArtImage;
}

- (UIImage *)defaultCoverArtImage
{	
	if (self.isLarge)
		return IS_IPAD() ? [UIImage imageNamed:@"default-album-art-ipad.png"] : [UIImage imageNamed:@"default-album-art.png"];
	else
		return [UIImage imageNamed:@"default-album-art-small.png"];
}

- (BOOL)isCoverArtCached
{
	if (!self.coverArtId) 
		return NO;
	
    return [self.dbQueue stringForQuery:@"SELECT id FROM coverArtCache WHERE id = ?", [self.coverArtId md5]] ? YES : NO;
}

- (void)downloadArtIfNotExists
{
	if (self.coverArtId)
	{
		if (!self.isCoverArtCached)
			[self startLoad];
	}
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
	[self cancelLoad];
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[ISMSCoverArtLoader alloc] initWithDelegate:self coverArtId:self.coverArtId isLarge:self.isLarge];
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	self.loader.delegate = nil;
	self.loader = nil;
		
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}


@end
