//
//  AtomWindowController.h
//  Atomicity
//
//  Created by Chris Wanstrath on 8/22/11.
//  Copyright 2011 GitHub. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AtomWindowController : NSWindowController {
  IBOutlet id webView;
  NSString *URL;
}

@property (assign) IBOutlet id webView;
@property (assign) IBOutlet NSString *URL;

@end
