/* =============================================================================
	FILE:		UKMainThreadProxy.h
	PROJECT:	UKMainThreadProxy
    
    PURPOSE:    Send a message to object theObject to [theObject mainThreadProxy]
                instead and the message will be received on the main thread by
                theObject.

    COPYRIGHT:  (c) 2004 M. Uli Kusterer, all rights reserved.
    
	AUTHORS:	M. Uli Kusterer - UK
    
    LICENSES:   MIT License

	REVISIONS:
		2006-03-13	UK	Clarified license.
		2004-10-14	UK	Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>


// -----------------------------------------------------------------------------
//  Categories:
// -----------------------------------------------------------------------------

@interface NSObject (UKMainThreadProxy)

-(id)	mainThreadProxy;		// You can't init or release this object.
-(id)	copyMainThreadProxy;	// Gives you a retained version.

@end


// -----------------------------------------------------------------------------
//  Classes:
// -----------------------------------------------------------------------------

/*
	This object is created as a proxy in a second thread for an existing object.
	All messages you send to this object will automatically be sent to the other
	object on the main thread, except NSObject methods like retain/release etc.
*/

@interface UKMainThreadProxy : NSObject
{
	IBOutlet id		target;
}

-(id)	initWithTarget: (id)targ;

@end
