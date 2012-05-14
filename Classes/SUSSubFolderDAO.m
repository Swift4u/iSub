//
//  SUSSubFolderDAO.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSSubFolderDAO.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "SUSSubFolderLoader.h"
#import "NSString+md5.h"
#import "Album.h"
#import "Song.h"
#import "MusicSingleton.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "JukeboxSingleton.h"
#import "NSNotificationCenter+MainThread.h"

@interface SUSSubFolderDAO (Private) 
- (NSUInteger)findFirstAlbumRow;
- (NSUInteger)findFirstSongRow;
- (NSUInteger)findAlbumsCount;
- (NSUInteger)findSongsCount;
- (NSUInteger)findFolderLength;
@end

@implementation SUSSubFolderDAO
@synthesize delegate, loader, myId, myArtist;
@synthesize albumsCount, songsCount, folderLength, albumStartRow, songStartRow;

#pragma mark - Lifecycle

- (void)setup
{
    albumStartRow = [self findFirstAlbumRow];
    songStartRow = [self findFirstSongRow];
    albumsCount = [self findAlbumsCount];
    songsCount = [self findSongsCount];
    folderLength = [self findFolderLength];
	//DLog(@"albumsCount: %i", albumsCount);
	//DLog(@"songsCount: %i", songsCount);
}

- (id)init
{
    if ((self = [super init])) 
	{
		[self setup];
    }
    return self;
}

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
    if ((self = [super init])) 
	{
		self.delegate = theDelegate;
		[self setup];
    }
    return self;
}

- (id)initWithDelegate:(id<SUSLoaderDelegate>)theDelegate andId:(NSString *)folderId andArtist:(Artist *)anArtist
{
	if ((self = [super init])) 
	{
		self.delegate = theDelegate;
        self.myId = folderId;
		self.myArtist = anArtist;
		[self setup];
    }
    return self;
}

- (void)dealloc
{
	[loader cancelLoad];
	loader.delegate = nil;
}

- (FMDatabaseQueue *)dbQueue
{
	return databaseS.albumListCacheDbQueue;
}

#pragma mark - Private DB Methods

- (NSUInteger)findFirstAlbumRow
{
    return [self.dbQueue intForQuery:@"SELECT rowid FROM albumsCache WHERE folderId = ? LIMIT 1", [self.myId md5]];
}

- (NSUInteger)findFirstSongRow
{
    return [self.dbQueue intForQuery:@"SELECT rowid FROM songsCache WHERE folderId = ? LIMIT 1", [self.myId md5]];
}

- (NSUInteger)findAlbumsCount
{
    return [self.dbQueue intForQuery:@"SELECT count FROM albumsCacheCount WHERE folderId = ?", [self.myId md5]];
}

- (NSUInteger)findSongsCount
{
    return [self.dbQueue intForQuery:@"SELECT count FROM songsCacheCount WHERE folderId = ?", [self.myId md5]];
}

- (NSUInteger)findFolderLength
{
    return [self.dbQueue intForQuery:@"SELECT length FROM folderLength WHERE folderId = ?", [self.myId md5]];
}

- (Album *)findAlbumForDbRow:(NSUInteger)row
{
    __block Album *anAlbum = nil;
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM albumsCache WHERE ROWID = %i", row]];
		[result next];
		if ([db hadError]) 
		{
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
		else
		{
			anAlbum = [[Album alloc] init];
			anAlbum.title = [result stringForColumn:@"title"];
			anAlbum.albumId = [result stringForColumn:@"albumId"];
			anAlbum.coverArtId = [result stringForColumn:@"coverArtId"];
			anAlbum.artistName = [result stringForColumn:@"artistName"];
			anAlbum.artistId = [result stringForColumn:@"artistId"];
		}
		[result close];
	}];
	
	return anAlbum;
}

- (Song *)findSongForDbRow:(NSUInteger)row
{ 
	return [Song songFromDbRow:row-1 inTable:@"songsCache" inDatabaseQueue:self.dbQueue];
}

- (void)playSongAtDbRow:(NSUInteger)row
{
	// Clear the current playlist
	if (settingsS.isJukeboxEnabled)
		[databaseS resetJukeboxPlaylist];
	else
		[databaseS resetCurrentPlaylistDb];
	
	// Add the songs to the playlist
	NSMutableArray *songIds = [[NSMutableArray alloc] init];
	for (int i = self.albumsCount; i < self.totalCount; i++)
	{
		@autoreleasepool 
		{
			Song *aSong = [self songForTableViewRow:i];
			//DLog(@"song parentId: %@", aSong.parentId);
			//DLog(@"adding song to playlist: %@", aSong);
			[aSong addToCurrentPlaylistDbQueue];
			
			// In jukebox mode, collect the song ids to send to the server
			if (settingsS.isJukeboxEnabled)
				[songIds addObject:aSong.songId];
		}
	}
	
	// If jukebox mode, send song ids to server
	if (settingsS.isJukeboxEnabled)
	{
		[jukeboxS jukeboxStop];
		[jukeboxS jukeboxClearPlaylist];
		[jukeboxS jukeboxAddSongs:songIds];
	}
	
	// Set player defaults
	playlistS.isShuffle = NO;
	
	// Start the song
	[musicS playSongAtPosition:(row - self.songStartRow)];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
}

#pragma mark - Public DAO Methods

- (BOOL)hasLoaded
{
    if (self.albumsCount > 0 || self.songsCount > 0)
        return YES;
    
    return NO;
}

- (NSUInteger)totalCount
{
    return self.albumsCount + self.songsCount;
}

- (Album *)albumForTableViewRow:(NSUInteger)row
{
    NSUInteger dbRow = self.albumStartRow + row;
    
    return [self findAlbumForDbRow:dbRow];
}

- (Song *)songForTableViewRow:(NSUInteger)row
{
    NSUInteger dbRow = self.songStartRow + (row - self.albumsCount);
    
    return [self findSongForDbRow:dbRow];
}

- (void)playSongAtTableViewRow:(NSUInteger)row
{
	NSUInteger dbRow = songStartRow + (row - self.albumsCount);
	[self playSongAtDbRow:dbRow];
}

- (NSArray *)sectionInfo
{
	// Create the section index
	if (self.albumsCount > 10)
	{
		__block NSArray *sectionInfo;
		[self.dbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
			[db executeUpdate:@"CREATE TEMPORARY TABLE albumIndex (title TEXT)"];
			
			[db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid >= ? LIMIT ?", [NSNumber numberWithInt:self.albumStartRow], [NSNumber numberWithInt:self.albumsCount]];
			
			sectionInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"title"];
			[db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
		}];
		
		return [sectionInfo count] < 5 ? nil : sectionInfo;
	}
	
	return nil;
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[SUSSubFolderLoader alloc] initWithDelegate:self];
    self.loader.myId = self.myId;
    self.loader.myArtist = self.myArtist;
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	self.loader.delegate = nil;
	self.loader = nil;
	
    [self setup];
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
