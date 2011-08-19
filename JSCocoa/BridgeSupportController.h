//
//  BridgeSupportController.h
//  JSCocoa
//
//  Created by Patrick Geiller on 08/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#if !TARGET_IPHONE_SIMULATOR && !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#endif

@interface BridgeSupportController : NSObject {


	NSMutableArray*			paths;
	NSMutableArray*			xmlDocuments;

	NSMutableDictionary*	hash;
	NSMutableDictionary*	variadicSelectors;
	NSMutableDictionary*	variadicFunctions;
}

+ (id)sharedController;

- (BOOL)loadBridgeSupport:(NSString*)path;
- (BOOL)isBridgeSupportLoaded:(NSString*)path;
- (NSUInteger)bridgeSupportIndexForString:(NSString*)string;

- (NSMutableDictionary*)variadicSelectors;
- (NSMutableDictionary*)variadicFunctions;

/*
- (NSString*)query:(NSString*)name withType:(NSString*)type;
- (NSString*)query:(NSString*)name withType:(NSString*)type inBridgeSupportFile:(NSString*)file;
*/
- (NSString*)queryName:(NSString*)name;
- (NSString*)queryName:(NSString*)name type:(NSString*)type;

- (NSArray*)keys;


@end
