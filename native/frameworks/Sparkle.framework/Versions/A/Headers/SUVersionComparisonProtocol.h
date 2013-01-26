//
//  SUVersionComparisonProtocol.h
//  Sparkle
//
//  Created by Andy Matuschak on 12/21/07.
//  Copyright 2007 Andy Matuschak. All rights reserved.
//

#ifndef SUVERSIONCOMPARISONPROTOCOL_H
#define SUVERSIONCOMPARISONPROTOCOL_H

#import <Cocoa/Cocoa.h>

/*!
    @protocol
    @abstract    Implement this protocol to provide version comparison facilities for Sparkle.
*/
@protocol SUVersionComparison

/*!
    @method     
    @abstract   An abstract method to compare two version strings.
    @discussion Should return NSOrderedAscending if b > a, NSOrderedDescending if b < a, and NSOrderedSame if they are equivalent.
*/
- (NSComparisonResult)compareVersion:(NSString *)versionA toVersion:(NSString *)versionB;	// *** MAY BE CALLED ON NON-MAIN THREAD!

@end

#endif
