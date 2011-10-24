/* =============================================================================
	FILE:		UKFileWatcher.h
	PROJECT:	Filie
    
    COPYRIGHT:  (c) 2005 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Moved notification constants to .m file.
		2005-02-25	UK	Created.
   ========================================================================== */

/*
    This is a protocol that file change notification classes should adopt.
    That way, no matter whether you use Carbon's FNNotify/FNSubscribe, BSD's
    kqueue or whatever, the object being notified can react to change
    notifications the same way, and you can easily swap one out for the other
    to cater to different OS versions, target volumes etc.
*/

// -----------------------------------------------------------------------------
//  Protocol:
// -----------------------------------------------------------------------------

@protocol UKFileWatcher

// +(id) sharedFileWatcher;			// Singleton accessor. Not officially part of the protocol, but use this name if you provide a singleton.

-(void) addPath: (NSString*)path;
-(void) removePath: (NSString*)path;

-(id)   delegate;
-(void) setDelegate: (id)newDelegate;

@end

// -----------------------------------------------------------------------------
//  Methods delegates need to provide:
// -----------------------------------------------------------------------------

@interface NSObject (UKFileWatcherDelegate)

-(void) watcher: (id<UKFileWatcher>)kq receivedNotification: (NSString*)nm forPath: (NSString*)fpath;

@end


// Notifications this sends:
/*  object			= the file watcher object
	userInfo.path	= file path watched
	These notifications are sent via the NSWorkspace notification center */
extern NSString* UKFileWatcherRenameNotification;
extern NSString* UKFileWatcherWriteNotification;
extern NSString* UKFileWatcherDeleteNotification;
extern NSString* UKFileWatcherAttributeChangeNotification;
extern NSString* UKFileWatcherSizeIncreaseNotification;
extern NSString* UKFileWatcherLinkCountChangeNotification;
extern NSString* UKFileWatcherAccessRevocationNotification;

