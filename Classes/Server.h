//
//  Server.h
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



#define SUBSONIC @"Subsonic"
#define UBUNTU_ONE @"Ubuntu One"
#define PERSONAL_MEDIA_SERVER @"Personal Media Server"

/*typedef enum {
	ServerTypeSubsonic,
	ServerTypeUbuntu
} ServerType;*/


@interface Server : NSObject <NSCoding>

@property (copy) NSString *url;
@property (copy) NSString *username;
@property (copy) NSString *password;
@property (copy) NSString *type;


@end
