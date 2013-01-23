//
//  SUVersionDisplayProtocol.h
//  EyeTV
//
//  Created by Uli Kusterer on 08.12.09.
//  Copyright 2009 Elgato Systems GmbH. All rights reserved.
//

#import <Cocoa/Cocoa.h>


/*!
    @protocol
    @abstract	Implement this protocol to apply special formatting to the two
				version numbers.
*/
@protocol SUVersionDisplay

/*!
    @method     
    @abstract   An abstract method to format two version strings.
    @discussion You get both so you can display important distinguishing
				information, but leave out unnecessary/confusing parts.
*/
-(void)	formatVersion: (NSString**)inOutVersionA andVersion: (NSString**)inOutVersionB; 

@end
