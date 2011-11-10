/* =============================================================================
	FILE:		UKKQueue.m
	PROJECT:	Filie
    
    COPYRIGHT:  (c) 2003 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Clarified license, streamlined UKFileWatcher stuff,
						Changed notifications to be useful and turned off by
						default some deprecated stuff.
        2004-12-28  UK  Several threading fixes.
		2003-12-21	UK	Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import "UKKQueue.h"
#import "UKMainThreadProxy.h"
#import <unistd.h>
#import <fcntl.h>
#import <sys/param.h>

// -----------------------------------------------------------------------------
//  Macros:
// -----------------------------------------------------------------------------

// @synchronized isn't available prior to 10.3, so we use a typedef so
//  this class is thread-safe on Panther but still compiles on older OSs.

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
#define AT_SYNCHRONIZED(n)      @synchronized(n)
#else
#define AT_SYNCHRONIZED(n)
#endif


// -----------------------------------------------------------------------------
//  Globals:
// -----------------------------------------------------------------------------

static UKKQueue * gUKKQueueSharedQueueSingleton = nil;


@implementation UKKQueue

// Deprecated:
#if UKKQUEUE_OLD_SINGLETON_ACCESSOR_NAME
+(UKKQueue*) sharedQueue
{
	return [self sharedFileWatcher];
}
#endif

// -----------------------------------------------------------------------------
//  sharedQueue:
//		Returns a singleton queue object. In many apps (especially those that
//      subscribe to the notifications) there will only be one kqueue instance,
//      and in that case you can use this.
//
//      For all other cases, feel free to create additional instances to use
//      independently.
//
//	REVISIONS:
//		2006-03-13	UK	Renamed from sharedQueue.
//      2005-07-02  UK  Created.
// -----------------------------------------------------------------------------

+(id) sharedFileWatcher
{
    AT_SYNCHRONIZED( self )
    {
        if( !gUKKQueueSharedQueueSingleton )
            gUKKQueueSharedQueueSingleton = [[UKKQueue alloc] init];	// This is a singleton, and thus an intentional "leak".
    }
    
    return gUKKQueueSharedQueueSingleton;
}


// -----------------------------------------------------------------------------
//	* CONSTRUCTOR:
//		Creates a new KQueue and starts that thread we use for our
//		notifications.
//
//	REVISIONS:
//      2004-11-12  UK  Doesn't pass self as parameter to watcherThread anymore,
//                      because detachNewThreadSelector retains target and args,
//                      which would cause us to never be released.
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(id)   init
{
	self = [super init];
	if( self )
	{
		queueFD = kqueue();
		if( queueFD == -1 )
		{
			[self release];
			return nil;
		}
		
		watchedPaths = [[NSMutableArray alloc] init];
		watchedFDs = [[NSMutableArray alloc] init];
		
		// Start new thread that fetches and processes our events:
		keepThreadRunning = YES;
		[NSThread detachNewThreadSelector:@selector(watcherThread:) toTarget:self withObject:nil];
	}
	
	return self;
}


// -----------------------------------------------------------------------------
//	release:
//		Since NSThread retains its target, we need this method to terminate the
//      thread when we reach a retain-count of two. The thread is terminated by
//      setting keepThreadRunning to NO.
//
//	REVISIONS:
//		2004-11-12	UK	Created.
// -----------------------------------------------------------------------------

-(oneway void) release
{
    AT_SYNCHRONIZED(self)
    {
        //NSLog(@"%@ (%d)", self, [self retainCount]);
        if( [self retainCount] == 2 && keepThreadRunning )
            keepThreadRunning = NO;
    }
    
    [super release];
}
    
// -----------------------------------------------------------------------------
//	* DESTRUCTOR:
//		Releases the kqueue again.
//
//	REVISIONS:
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(void) dealloc
{
	delegate = nil;
	[delegateProxy release];
	
	if( keepThreadRunning )
		keepThreadRunning = NO;
	
	// Close all our file descriptors so the files can be deleted:
	NSEnumerator*	enny = [watchedFDs objectEnumerator];
	NSNumber*		fdNum;
	while( (fdNum = [enny nextObject]) )
	{
    	if( close( [fdNum intValue] ) == -1 )
            NSLog(@"dealloc: Couldn't close file descriptor (%d)", errno);
    }
	
	[watchedPaths release];
	watchedPaths = nil;
	[watchedFDs release];
	watchedFDs = nil;
	
	[super dealloc];
    
    //NSLog(@"kqueue released.");
}


// -----------------------------------------------------------------------------
//	queueFD:
//		Returns a Unix file descriptor for the KQueue this uses. The descriptor
//		is owned by this object. Do not close it!
//
//	REVISIONS:
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(int)  queueFD
{
	return queueFD;
}


// -----------------------------------------------------------------------------
//	addPathToQueue:
//		Tell this queue to listen for all interesting notifications sent for
//		the object at the specified path. If you want more control, use the
//		addPathToQueue:notifyingAbout: variant instead.
//
//	REVISIONS:
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(void) addPathToQueue: (NSString*)path
{
	[self addPath: path];
}


-(void) addPath: (NSString*)path
{
	[self addPathToQueue: path notifyingAbout: UKKQueueNotifyAboutRename
												| UKKQueueNotifyAboutWrite
												| UKKQueueNotifyAboutDelete
												| UKKQueueNotifyAboutAttributeChange];
}


// -----------------------------------------------------------------------------
//	addPathToQueue:notfyingAbout:
//		Tell this queue to listen for the specified notifications sent for
//		the object at the specified path.
//
//	REVISIONS:
//      2005-06-29  UK  Files are now opened using O_EVTONLY instead of O_RDONLY
//                      which allows ejecting or deleting watched files/folders.
//                      Thanks to Phil Hargett for finding this flag in the docs.
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(void) addPathToQueue: (NSString*)path notifyingAbout: (u_int)fflags
{
	struct timespec		nullts = { 0, 0 };
	struct kevent		ev;
	int					fd = open( [path fileSystemRepresentation], O_EVTONLY, 0 );
	
    if( fd >= 0 )
    {
        EV_SET( &ev, fd, EVFILT_VNODE, 
				EV_ADD | EV_ENABLE | EV_CLEAR,
				fflags, 0, (void*)path );
		
        AT_SYNCHRONIZED( self )
        {
            [watchedPaths addObject: path];
            [watchedFDs addObject: [NSNumber numberWithInt: fd]];
            kevent( queueFD, &ev, 1, NULL, 0, &nullts );
        }
    }
}


-(void) removePath: (NSString*)path
{
    [self removePathFromQueue: path];
}


// -----------------------------------------------------------------------------
//	removePathFromQueue:
//		Stop listening for changes to the specified path. This removes all
//		notifications. Use this to balance both addPathToQueue:notfyingAbout:
//		as well as addPathToQueue:.
//
//	REVISIONS:
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(void) removePathFromQueue: (NSString*)path
{
    NSUInteger		index = 0;
    int		fd = -1;
    
    AT_SYNCHRONIZED( self )
    {
        index = [watchedPaths indexOfObject: path];
        
        if( index == NSNotFound )
            return;
        
        fd = [[watchedFDs objectAtIndex: index] intValue];
        
        [watchedFDs removeObjectAtIndex: index];
        [watchedPaths removeObjectAtIndex: index];
    }
	
	if( close( fd ) == -1 )
        NSLog(@"removePathFromQueue: Couldn't close file descriptor (%d)", errno);
}


// -----------------------------------------------------------------------------
//	removeAllPathsFromQueue:
//		Stop listening for changes to all paths. This removes all
//		notifications.
//
//  REVISIONS:
//      2004-12-28  UK  Added as suggested by bbum.
// -----------------------------------------------------------------------------

-(void) removeAllPathsFromQueue;
{
    AT_SYNCHRONIZED( self )
    {
        NSEnumerator *  fdEnumerator = [watchedFDs objectEnumerator];
        NSNumber     *  anFD;
        
        while( (anFD = [fdEnumerator nextObject]) != nil )
            close( [anFD intValue] );

        [watchedFDs removeAllObjects];
        [watchedPaths removeAllObjects];
    }
}


// -----------------------------------------------------------------------------
//	watcherThread:
//		This method is called by our NSThread to loop and poll for any file
//		changes that our kqueue wants to tell us about. This sends separate
//		notifications for the different kinds of changes that can happen.
//		All messages are sent via the postNotification:forFile: main bottleneck.
//
//		This also calls sharedWorkspace's noteFileSystemChanged.
//
//      To terminate this method (and its thread), set keepThreadRunning to NO.
//
//	REVISIONS:
//		2005-08-27	UK	Changed to use keepThreadRunning instead of kqueueFD
//						being -1 as termination criterion, and to close the
//						queue in this thread so the main thread isn't blocked.
//		2004-11-12	UK	Fixed docs to include termination criterion, added
//                      timeout to make sure the bugger gets disposed.
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(void)		watcherThread: (id)sender
{
	int					n;
    struct kevent		ev;
    struct timespec     timeout = { 5, 0 }; // 5 seconds timeout.
	int					theFD = queueFD;	// So we don't have to risk accessing iVars when the thread is terminated.
    
    while( keepThreadRunning )
    {
		NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
		
		NS_DURING
			n = kevent( queueFD, NULL, 0, &ev, 1, &timeout );
			if( n > 0 )
			{
				if( ev.filter == EVFILT_VNODE )
				{     
					if( ev.fflags )
					{
						NSString*		fpath = [[(NSString *)ev.udata retain] autorelease];    // In case one of the notified folks removes the path.
						//NSLog(@"UKKQueue: Detected file change: %@", fpath);
						[[NSWorkspace sharedWorkspace] noteFileSystemChanged: fpath];
						
						//NSLog(@"ev.flags = %u",ev.fflags);	// DEBUG ONLY!
						
						if( (ev.fflags & NOTE_RENAME) == NOTE_RENAME ) {
              char path[MAXPATHLEN];
              fcntl((int)ev.ident, F_GETPATH, &path);
							[self postNotification: UKFileWatcherRenameNotification forFile: [NSString stringWithUTF8String:path]];
            }
						if( (ev.fflags & NOTE_WRITE) == NOTE_WRITE ) {
							[self postNotification: UKFileWatcherWriteNotification forFile: fpath];
            }
						if( (ev.fflags & NOTE_DELETE) == NOTE_DELETE ) {
              [self removePathFromQueue:fpath];
              int newFD = open( [fpath fileSystemRepresentation], O_EVTONLY, 0 );
              if (newFD == -1) {
                // It's really a delete
   							[self postNotification: UKFileWatcherDeleteNotification forFile: fpath];
              }
              else {
                // Probably an atomic write, readd to the queue.
                close(newFD);
                [self addPathToQueue:fpath];
                [self postNotification: UKFileWatcherWriteNotification forFile: fpath];
                [self postNotification: UKFileWatcherAttributeChangeNotification forFile: fpath];
              }
            }
						if( (ev.fflags & NOTE_ATTRIB) == NOTE_ATTRIB ) {
							[self postNotification: UKFileWatcherAttributeChangeNotification forFile: fpath];
            }
						if( (ev.fflags & NOTE_EXTEND) == NOTE_EXTEND ) {
							[self postNotification: UKFileWatcherSizeIncreaseNotification forFile: fpath];
            }
						if( (ev.fflags & NOTE_LINK) == NOTE_LINK ) {
							[self postNotification: UKFileWatcherLinkCountChangeNotification forFile: fpath];
            }
						if( (ev.fflags & NOTE_REVOKE) == NOTE_REVOKE ) {
							[self postNotification: UKFileWatcherAccessRevocationNotification forFile: fpath];
            }
					}
				}
			}
		NS_HANDLER
			NSLog(@"Error in UKKQueue watcherThread: %@",localException);
		NS_ENDHANDLER
		
		[pool release];
    }
    
	// Close our kqueue's file descriptor:
	if( close( theFD ) == -1 )
		NSLog(@"release: Couldn't close main kqueue (%d)", errno);
	
    //NSLog(@"exiting kqueue watcher thread.");
}


// -----------------------------------------------------------------------------
//	postNotification:forFile:
//		This is the main bottleneck for posting notifications. If you don't want
//		the notifications to go through NSWorkspace, override this method and
//		send them elsewhere.
//
//	REVISIONS:
//      2004-02-27  UK  Changed this to send new notification, and the old one
//                      only to objects that respond to it. The old category on
//                      NSObject could cause problems with the proxy itself.
//		2004-10-31	UK	Helloween fun: Make this use a mainThreadProxy and
//						allow sending the notification even if we have a
//						delegate.
//		2004-03-13	UK	Documented.
// -----------------------------------------------------------------------------

-(void) postNotification: (NSString*)nm forFile: (NSString*)fp
{
	if( delegateProxy )
    {
        #if UKKQUEUE_BACKWARDS_COMPATIBLE
        if( ![delegateProxy respondsToSelector: @selector(watcher:receivedNotification:forPath:)] )
            [delegateProxy kqueue: self receivedNotification: nm forFile: fp];
        else
        #endif
            [delegateProxy watcher: self receivedNotification: nm forPath: fp];
    }
	
	if( !delegateProxy || alwaysNotify )
	{
		#if UKKQUEUE_SEND_STUPID_NOTIFICATIONS
		[[[NSWorkspace sharedWorkspace] notificationCenter] postNotificationName: nm object: fp];
		#else
		[[[NSWorkspace sharedWorkspace] notificationCenter] postNotificationName: nm object: self
																userInfo: [NSDictionary dictionaryWithObjectsAndKeys: fp, @"path", nil]];
		#endif
	}
}

-(id)	delegate
{
    return delegate;
}

-(void)	setDelegate: (id)newDelegate
{
	id	oldProxy = delegateProxy;
	delegate = newDelegate;
	delegateProxy = [delegate copyMainThreadProxy];
	[oldProxy release];
}

// -----------------------------------------------------------------------------
//	Flag to send a notification even if we have a delegate:
// -----------------------------------------------------------------------------

-(BOOL)	alwaysNotify
{
	return alwaysNotify;
}


-(void)	setAlwaysNotify: (BOOL)n
{
	alwaysNotify = n;
}


// -----------------------------------------------------------------------------
//	description:
//		This method can be used to help in debugging. It provides the value
//      used by NSLog & co. when you request to print this object using the
//      %@ format specifier.
//
//	REVISIONS:
//		2004-11-12	UK	Created.
// -----------------------------------------------------------------------------

-(NSString*)	description
{
	return [NSString stringWithFormat: @"%@ { watchedPaths = %@, alwaysNotify = %@ }", NSStringFromClass([self class]), watchedPaths, (alwaysNotify? @"YES" : @"NO") ];
}

@end


