//
//  AllAlbumsViewController.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "AllAlbumsViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "LoadingScreen.h"
#import "iSub-Swift.h"

@interface AllAlbumsViewController() <CustomUITableViewCellDelegate>
{
    BOOL _reloading;
}
@end

@implementation AllAlbumsViewController

@synthesize headerView, sectionInfo, dataModel, allSongsDataModel, loadingScreen;
@synthesize reloadLabel, reloadButton, reloadTimeLabel, reloadImage;
@synthesize letUserSelectRow, searchOverlay, countLabel, url;
@synthesize isSearching, isProcessingArtists, isAllAlbumsLoading, searchBar, dismissButton;

- (void)createDataModel
{
	self.dataModel = [[SUSAllAlbumsDAO alloc] init];
	self.allSongsDataModel.delegate = nil;
	self.allSongsDataModel = [[SUSAllSongsDAO alloc] initWithDelegate:self];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	self.title = @"Albums";
	
	//Set defaults
	self.letUserSelectRow = YES;	
	self.isSearching = NO;
	
	[self createDataModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createDataModel) name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadingFinishedNotification) name:ISMSNotification_AllSongsLoadingFinished object:nil];	
}


- (void)addCount
{
	//Build the search and reload view
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)];
	self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.headerView.backgroundColor = ISMSHeaderColor;
	
	self.reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.reloadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.reloadButton.frame = CGRectMake(0, 0, 320, 40);
	[self.headerView addSubview:self.reloadButton];
	
	self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	self.countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.countLabel.backgroundColor = [UIColor clearColor];
	self.countLabel.textColor = [UIColor blackColor];
	self.countLabel.textAlignment = NSTextAlignmentCenter;
	self.countLabel.font = ISMSBoldFont(30);
	[self.headerView addSubview:self.countLabel];
	
	self.searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 50, 320, 40)];
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.delegate = self;
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.placeholder = @"Album name";
	[self.headerView addSubview:self.searchBar];
	
	self.reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	self.reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.reloadTimeLabel.backgroundColor = [UIColor clearColor];
	self.reloadTimeLabel.textColor = [UIColor colorWithRed:176.0/255.0 green:181.0/255.0 blue:188.0/255.0 alpha:1];
	self.reloadTimeLabel.textAlignment = NSTextAlignmentCenter;
	self.reloadTimeLabel.font = ISMSRegularFont(11);
	[self.headerView addSubview:self.reloadTimeLabel];
	
	self.countLabel.text = [NSString stringWithFormat:@"%lu Albums", (unsigned long)self.dataModel.count];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	self.reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[defaults objectForKey:[NSString stringWithFormat:@"%@songsReloadTime", settingsS.urlString]]]];
	
	self.tableView.tableHeaderView = self.headerView;
	
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
    
	// Don't run this while the table is updating
	if ([SUSAllSongsLoader isLoading])
	{
		[self showLoadingScreen];
	}
	else
	{		
		// Check if the data has been loaded
		if (self.dataModel.isDataLoaded)
		{
			[self addCount];
		}
		else
		{
			self.tableView.tableHeaderView = nil;

			if ([[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@isAllSongsLoading", settingsS.urlString]] isEqualToString:@"YES"])
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Resume Load?" message:@"If you've reloaded the albums tab since this load started you should choose 'Restart Load'.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Restart Load", @"Resume Load", nil];
				alert.tag = 1;
				[alert show];
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Load?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
				alert.tag = 1;
				[alert show];
			}
		}
	}
	
	[self.tableView reloadData];
	
	[Flurry logEvent:@"AllAlbumsTab"];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self hideLoadingScreen];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark -
#pragma mark Button handling methods

- (void)reloadAction:(id)sender
{
	if (![SUSAllSongsLoader isLoading])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reload?" message:@"This could take a while if you have a big collection.\n\nIMPORTANT: Make sure to plug in your device to keep the app active if you have a large collection.\n\nNote: If you've added new artists, you should reload the Folders tab first." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
		alert.tag = 1;
		[alert show];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait" message:@"You cannot reload the Albums tab while the Folders or Songs tabs are loading" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[self dataSourceDidFinishLoadingNewData];
	}	
}

- (void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 1)
	{
		if (buttonIndex == 1)
		{
			[self showLoadingScreen];//:@[@"Processing Artist:", @"", @"Processing Album:", @""];
			
			[self.allSongsDataModel restartLoad];
			self.tableView.tableHeaderView = nil;
			[self.tableView reloadData];
		}
		else if (buttonIndex == 2)
		{
			[self showLoadingScreen];//:@[@"Processing Album:", @"", @"Processing Song:", @""]];
			
			[self.allSongsDataModel startLoad];
			self.tableView.tableHeaderView = nil;
			[self.tableView reloadData];
		}	
		
		[self dataSourceDidFinishLoadingNewData];
	}
}

#pragma mark - Search

- (void)createSearchOverlay
{
	self.searchOverlay = [[UIView alloc] init];
	//searchOverlay.frame = CGRectMake(0, 74, 480, 480);
	self.searchOverlay.frame = CGRectMake(0, 0, 480, 480);
	self.searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.searchOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	self.searchOverlay.alpha = 0.0;
	//[self.view.superview addSubview:searchOverlay];
	//[self.tableView.tableFooterView addSubview:searchOverlay];
	self.tableView.tableFooterView = self.searchOverlay;//self.tableView.tableFooterView;
	
	self.dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.dismissButton addTarget:self action:@selector(a_doneSearching:) forControlEvents:UIControlEventTouchUpInside];
	self.dismissButton.frame = self.view.bounds;
	self.dismissButton.enabled = NO;
	[self.searchOverlay addSubview:self.dismissButton];
	
	// Animate the search overlay on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	self.searchOverlay.alpha = 1;
	self.dismissButton.enabled = YES;
	[UIView commitAnimations];
}

- (void)hideSearchOverlay
{
	if (searchOverlay)
	{
		// Animate the search overlay off screen
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.3];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(removeSearchOverlay)];
		self.searchOverlay.alpha = 0;
		self.dismissButton.enabled = NO;
		[UIView commitAnimations];
	}
}

- (void)removeSearchOverlay
{
	[self.searchOverlay removeFromSuperview];
	self.searchOverlay = nil;
	
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar 
{	
	//self.tableView.tableHeaderView;
	
	[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
	
	if ([theSearchBar.text length] == 0)
	{
		[self createSearchOverlay];
		
		self.letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	// Remove the index bar
	self.isSearching = YES;
	[self.tableView reloadData];
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(a_doneSearching:)];
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{
		[self hideSearchOverlay];
		
		self.isSearching = YES;
		self.letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		[self.dataModel searchForAlbumName:searchText];
	}
	else 
	{
		[self.tableView setContentOffset:CGPointMake(0, 50) animated:YES];
		
		[self createSearchOverlay];
		
		self.isSearching = NO;
		self.letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		[databaseS.allAlbumsDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE allAlbumsSearch"];
		}];
	}
	
	[self.tableView reloadData];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{
	[searchBar resignFirstResponder];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar
{
	[self hideSearchOverlay];
}

- (void)a_doneSearching:(id)sender
{
	self.tableView.tableHeaderView = nil;
	[self addCount];
	
	self.searchBar.text = @"";
	[self.searchBar resignFirstResponder];
	
	self.isSearching = NO;
	self.letUserSelectRow = YES;
	self.navigationItem.leftBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[self hideSearchOverlay];
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 28) animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if (self.isSearching)
	{
		return 1;
	}
	else
	{
		NSUInteger count = [[self.dataModel index] count];
		return count;
	}
}

#pragma mark - Tableview methods

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
	if(self.isSearching)
		return @"";
	
	if ([self.dataModel.index count] == 0)
		return @"";
	
	NSString *title = [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:section] name];
	
	return title;
}

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	if(self.isSearching)
	{
		return nil;
	}
	else
	{
		NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
		[titles addObject:@"{search}"];
		for (ISMSIndex *item in self.dataModel.index)
		{
			[titles addObject:item.name];
		}
		
		return titles;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(self.isSearching)
		return -1;
	
	if (index == 0) 
	{
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
		return -1;
	}
	
	return index - 1;
}


- (NSIndexPath *)tableView:(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(self.letUserSelectRow)
		return indexPath;
	else
		return nil;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.isSearching)
	{
		return self.dataModel.searchCount;
	}
	else 
	{
		return [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:section] count];
	}
}

								   
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"AllAlbumsCell";
	CustomUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[CustomUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.delegate = self;
	}
	cell.accessoryType = UITableViewCellAccessoryNone;
		
	ISMSAlbum *anAlbum = nil;
	if(self.isSearching)
	{
		anAlbum = [self.dataModel albumForPositionInSearch:(indexPath.row + 1)];
	}
	else
	{
		NSUInteger sectionStartIndex = [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:indexPath.section] position];
		anAlbum = [self.dataModel albumForPosition:(sectionStartIndex + indexPath.row + 1)];
	}
	
	cell.associatedObject = anAlbum;
	
	cell.coverArtId = anAlbum.coverArtId;
	
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
    
    cell.title = anAlbum.title;
    cell.subTitle = anAlbum.artistName;
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		ISMSAlbum *anAlbum = nil;
		if(isSearching)
		{
			anAlbum = [self.dataModel albumForPositionInSearch:(indexPath.row + 1)];
		}
		else
		{
			NSUInteger sectionStartIndex = [(ISMSIndex *)[self.dataModel.index objectAtIndexSafe:indexPath.section] position];
			anAlbum = [self.dataModel albumForPosition:(sectionStartIndex + indexPath.row + 1)];
		}
		
		FolderViewController* albumViewController = [[FolderViewController alloc] initWithAlbum:anAlbum];
		[self pushViewControllerCustom:albumViewController];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark - Loading Display Handling

- (void)registerForLoadingNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsLoadingArtists object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsLoadingAlbums object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsArtistName object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsAlbumName object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLoadingScreen:) name:ISMSNotification_AllSongsSongName object:nil];
}

- (void)unregisterForLoadingNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsLoadingArtists object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsLoadingAlbums object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsArtistName object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsAlbumName object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_AllSongsSongName object:nil];
}

- (void)updateLoadingScreen:(NSNotification *)notification
{
	NSString *name = nil;
	if ([notification.object isKindOfClass:[NSString class]])
	{
		name = [NSString stringWithString:(NSString *)notification.object];
	}
	
	if ([notification.name isEqualToString:ISMSNotification_AllSongsLoadingArtists])
	{
		self.isProcessingArtists = YES;
		self.loadingScreen.loadingTitle1.text = @"Processing Artist:";
		self.loadingScreen.loadingTitle2.text = @"Processing Album:";
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsLoadingAlbums])
	{
		self.isProcessingArtists = NO;
		self.loadingScreen.loadingTitle1.text = @"Processing Album:";
		self.loadingScreen.loadingTitle2.text = @"Processing Song:";
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsSorting])
	{
		self.loadingScreen.loadingTitle1.text = @"Sorting";
		self.loadingScreen.loadingTitle2.text = @"";
		self.loadingScreen.loadingMessage1.text = name;
		self.loadingScreen.loadingMessage2.text = @"";
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsArtistName])
	{
		self.isProcessingArtists = YES;
		self.loadingScreen.loadingTitle1.text = @"Processing Artist:";
		self.loadingScreen.loadingTitle2.text = @"Processing Album:";
		self.loadingScreen.loadingMessage1.text = name;
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsAlbumName])
	{
		if (self.isProcessingArtists)
			self.loadingScreen.loadingMessage2.text = name;
		else
			self.loadingScreen.loadingMessage1.text = name;
	}
	else if ([notification.name isEqualToString:ISMSNotification_AllSongsSongName])
	{
		self.isProcessingArtists = NO;
		self.loadingScreen.loadingTitle1.text = @"Processing Album:";
		self.loadingScreen.loadingTitle2.text = @"Processing Song:";
		self.loadingScreen.loadingMessage2.text = name;
	}
}

- (void)showLoadingScreen
{
	self.loadingScreen = [[LoadingScreen alloc] initOnView:self.view withMessage:@[@"Processing Artist:", @"", @"Processing Album:", @""] blockInput:YES mainWindow:NO];
	self.tableView.scrollEnabled = NO;
	self.tableView.allowsSelection = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.navigationItem.rightBarButtonItem = nil;
	
	[self registerForLoadingNotifications];
}

- (void)hideLoadingScreen
{
	[self unregisterForLoadingNotifications];
	
	self.tableView.scrollEnabled = YES;
	self.tableView.allowsSelection = YES;
	
	// Hide the loading screen
	[self.loadingScreen hide];
	self.loadingScreen = nil;
}

#pragma mark - LoaderDelegate methods

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	[self.tableView reloadData];
	[self createDataModel];
    [self hideLoadingScreen];
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	// Don't do anything, handled by the notification
}

- (void)loadingFinishedNotification
{
	[self.tableView reloadData];
	[self createDataModel];
	[self addCount];
    [self hideLoadingScreen];
}

#pragma mark - Pull to refresh methods

- (BOOL)shouldSetupRefreshControl
{
    return YES;
}

- (void)didPullToRefresh
{
	if (!_reloading)
	{
		_reloading = YES;
		[self reloadAction:nil];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	_reloading = NO;
	
    [self.refreshControl endRefreshing];
}

#pragma mark - CustomUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(CustomUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSAlbum class]])
    {
        ISMSAlbum *album = associatedObject;
        ISMSArtist *artist = [ISMSArtist artistWithName:album.artistName andArtistId:album.artistId];
        
        [databaseS downloadAllSongs:album.albumId artist:artist];
    }
    
    [cell.overlayView disableDownloadButton];
}

- (void)tableCellQueueButtonPressed:(CustomUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSAlbum class]])
    {
        ISMSAlbum *album = associatedObject;
        ISMSArtist *artist = [ISMSArtist artistWithName:album.artistName andArtistId:album.artistId];
        
        [databaseS queueAllSongs:album.albumId artist:artist];
    }
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
}


@end

