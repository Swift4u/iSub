//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresGenreUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "CellOverlay.h"
#import "Song.h"
#import "NSNotificationCenter+MainThread.h"

@implementation GenresGenreUITableViewCell

@synthesize genreNameScrollView, genreNameLabel;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		genreNameScrollView = [[UIScrollView alloc] init];
		genreNameScrollView.frame = CGRectMake(5, 0, 300, 44);
		genreNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		genreNameScrollView.showsVerticalScrollIndicator = NO;
		genreNameScrollView.showsHorizontalScrollIndicator = NO;
		genreNameScrollView.userInteractionEnabled = NO;
		genreNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:genreNameScrollView];
		
		genreNameLabel = [[UILabel alloc] init];
		genreNameLabel.backgroundColor = [UIColor clearColor];
		genreNameLabel.textAlignment = UITextAlignmentLeft; // default
		genreNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[genreNameScrollView addSubview:genreNameLabel];
	}
	
	return self;
}


- (void)layoutSubviews 
{	
    [super layoutSubviews];
		
	// Automatically set the width based on the width of the text
	genreNameLabel.frame = CGRectMake(0, 0, 270, 44);
	CGSize expectedLabelSize = [genreNameLabel.text sizeWithFont:genreNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:genreNameLabel.lineBreakMode]; 
	CGRect newFrame = genreNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	genreNameLabel.frame = newFrame;
}

#pragma mark - Overlay

- (void)showOverlay
{
	[super showOverlay];
	
	if (self.isOverlayShowing)
	{
		if (viewObjectsS.isOfflineMode)
		{
			self.overlayView.downloadButton.enabled = NO;
			self.overlayView.downloadButton.hidden = YES;
		}
	}
}

- (void)downloadAllSongs
{
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (viewObjectsS.isOfflineMode)
	{
		dbQueue = databaseS.songCacheDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE"];
	}
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, genreNameLabel.text];
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCacheQueue];
		}
		[result close];
	}];
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
}

- (void)downloadAction
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(downloadAllSongs) withObject:nil afterDelay:0.05];
	
	self.overlayView.downloadButton.alpha = .3;
	self.overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAllSongs
{
	FMDatabaseQueue *dbQueue;
	NSString *query;
	
	if (viewObjectsS.isOfflineMode)
	{
		dbQueue = databaseS.songCacheDbQueue;
		query = @"SELECT md5 FROM cachedSongsLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	else
	{
		dbQueue = databaseS.genresDbQueue;
		query = @"SELECT md5 FROM genresLayout WHERE genre = ? ORDER BY seg1 COLLATE NOCASE";
	}
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query, genreNameLabel.text];
		
		while ([result next])
		{
			if ([result stringForColumnIndex:0] != nil)
				[[Song songFromGenreDb:[NSString stringWithString:[result stringForColumnIndex:0]]] addToCurrentPlaylist];
		}
		[result close];
	}];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[viewObjectsS hideLoadingScreen];
}

- (void)queueAction
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(queueAllSongs) withObject:nil afterDelay:0.05];
	[self hideOverlay];
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	if (genreNameLabel.frame.size.width > genreNameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:genreNameLabel.frame.size.width/(float)150];
		genreNameScrollView.contentOffset = CGPointMake(genreNameLabel.frame.size.width - genreNameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:genreNameLabel.frame.size.width/(float)150];
	genreNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
