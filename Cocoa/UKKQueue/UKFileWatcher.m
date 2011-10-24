/* =============================================================================
	FILE:		UKKQueue.m
	PROJECT:	Filie
    
    COPYRIGHT:  (c) 2005-06 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Created, moved notification constants here as exportable
						symbols.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "UKFileWatcher.h"


// -----------------------------------------------------------------------------
//  Constants:
// -----------------------------------------------------------------------------

// Do not rely on the actual contents of these constants. They will eventually
//	be changed to be more generic and less KQueue-specific.

NSString* UKFileWatcherRenameNotification				= @"UKKQueueFileRenamedNotification";
NSString* UKFileWatcherWriteNotification				= @"UKKQueueFileWrittenToNotification";
NSString* UKFileWatcherDeleteNotification				= @"UKKQueueFileDeletedNotification";
NSString* UKFileWatcherAttributeChangeNotification		= @"UKKQueueFileAttributesChangedNotification";
NSString* UKFileWatcherSizeIncreaseNotification			= @"UKKQueueFileSizeIncreasedNotification";
NSString* UKFileWatcherLinkCountChangeNotification		= @"UKKQueueFileLinkCountChangedNotification";
NSString* UKFileWatcherAccessRevocationNotification		= @"UKKQueueFileAccessRevocationNotification";

