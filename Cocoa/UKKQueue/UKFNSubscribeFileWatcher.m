/* =============================================================================
	FILE:		UKFNSubscribeFileWatcher.m
	PROJECT:	Filie
    
    COPYRIGHT:  (c) 2005 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Commented, added singleton, added notifications.
		2005-03-02	UK	Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import "UKFNSubscribeFileWatcher.h"
#import <Carbon/Carbon.h>


// -----------------------------------------------------------------------------
//  Prototypes:
// -----------------------------------------------------------------------------

void    UKFileSubscriptionProc(FNMessage message, OptionBits flags, void *refcon, FNSubscriptionRef subscription);


@implementation UKFNSubscribeFileWatcher

// -----------------------------------------------------------------------------
//  sharedFileWatcher:
//		Singleton accessor.
// -----------------------------------------------------------------------------

+(id) sharedFileWatcher
{
	static UKFNSubscribeFileWatcher* sSharedFileWatcher = nil;
	
	if( !sSharedFileWatcher )
		sSharedFileWatcher = [[UKFNSubscribeFileWatcher alloc] init];	// This is a singleton, and thus an intentional "leak".
    
    return sSharedFileWatcher;
}


// -----------------------------------------------------------------------------
//  * CONSTRUCTOR:
// -----------------------------------------------------------------------------

-(id)   init
{
    self = [super init];
    if( !self ) 
        return nil;
    
    subscriptions = [[NSMutableDictionary alloc] init];
    
    return self;
}


// -----------------------------------------------------------------------------
//  * DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void) dealloc
{
    NSEnumerator*   enny = [subscriptions objectEnumerator];
    NSValue*        subValue = nil;
    
    while( (subValue = [enny nextObject]) )
    {
        FNSubscriptionRef   subscription = [subValue pointerValue];
        FNUnsubscribe( subscription );
    }
    
    [subscriptions release];
    [super dealloc];
}


// -----------------------------------------------------------------------------
//  addPath:
//		Start watching the object at the specified path. This only sends write
//		notifications for all changes, as FNSubscribe doesn't tell what actually
//		changed about our folder.
// -----------------------------------------------------------------------------

-(void) addPath: (NSString*)path
{
    OSStatus                    err = noErr;
    static FNSubscriptionUPP    subscriptionUPP = NULL;
    FNSubscriptionRef           subscription = NULL;
    
    if( !subscriptionUPP )
        subscriptionUPP = NewFNSubscriptionUPP( UKFileSubscriptionProc );
    
    err = FNSubscribeByPath( (UInt8*) [path fileSystemRepresentation], subscriptionUPP, (void*)self,
                                kNilOptions, &subscription );
    if( err != noErr )
    {
        NSLog( @"UKFNSubscribeFileWatcher addPath: %@ failed due to error ID=%ld.", path, err );
        return;
    }
    
    [subscriptions setObject: [NSValue valueWithPointer: subscription] forKey: path];
}


// -----------------------------------------------------------------------------
//  removePath:
//		Stop watching the object at the specified path.
// -----------------------------------------------------------------------------

-(void) removePath: (NSString*)path
{
    NSValue*            subValue = nil;
    @synchronized( self )
    {
        subValue = [[[subscriptions objectForKey: path] retain] autorelease];
        [subscriptions removeObjectForKey: path];
    }
    
	if( subValue )
	{
		FNSubscriptionRef   subscription = [subValue pointerValue];
		
		FNUnsubscribe( subscription );
	}
}


// -----------------------------------------------------------------------------
//  sendDelegateMessage:forSubscription:
//		Bottleneck for change notifications. This is called by our callback
//		function to actually inform the delegate and send out notifications.
//
//		This *only* sends out write notifications, as FNSubscribe doesn't tell
//		what changed about our folder.
// -----------------------------------------------------------------------------

-(void) sendDelegateMessage: (FNMessage)message forSubscription: (FNSubscriptionRef)subscription
{
    NSValue*                    subValue = [NSValue valueWithPointer: subscription];
    NSString*                   path = [[subscriptions allKeysForObject: subValue] objectAtIndex: 0];
    
	[[[NSWorkspace sharedWorkspace] notificationCenter] postNotificationName: UKFileWatcherWriteNotification
															object: self
															userInfo: [NSDictionary dictionaryWithObjectsAndKeys: path, @"path", nil]];
	
    [delegate watcher: self receivedNotification: UKFileWatcherWriteNotification forPath: path];
    //NSLog( @"UKFNSubscribeFileWatcher noticed change to %@", path );	// DEBUG ONLY!
}



// -----------------------------------------------------------------------------
//  delegate:
//		Accessor for file watcher delegate.
// -----------------------------------------------------------------------------

-(id)   delegate
{
    return delegate;
}


// -----------------------------------------------------------------------------
//  setDelegate:
//		Mutator for file watcher delegate.
// -----------------------------------------------------------------------------

-(void) setDelegate: (id)newDelegate
{
    delegate = newDelegate;
}


@end


// -----------------------------------------------------------------------------
//  UKFileSubscriptionProc:
//		Callback function we hand to Carbon so it can tell us when something
//		changed about our watched folders. We set the refcon to a pointer to
//		our object. This simply extracts the object and hands the info off to
//		sendDelegateMessage:forSubscription: which does the actual work.
// -----------------------------------------------------------------------------

void    UKFileSubscriptionProc( FNMessage message, OptionBits flags, void *refcon, FNSubscriptionRef subscription )
{
    UKFNSubscribeFileWatcher*   obj = (UKFNSubscribeFileWatcher*) refcon;
    
    if( message == kFNDirectoryModifiedMessage )    // No others exist as of 10.4
        [obj sendDelegateMessage: message forSubscription: subscription];
    else
        NSLog( @"UKFileSubscriptionProc: Unknown message %d", message );
}