//
//  AtomWindowController.h
//  Atomicity
//
//  Created by Chris Wanstrath on 8/22/11.
//  Copyright 2011 GitHub. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class JSCocoa;

@interface AtomWindowController : NSWindowController {
  IBOutlet id webView;
  NSString *URL;
  JSCocoa* jscocoa;
}

@property (assign) IBOutlet id webView;
@property (assign) IBOutlet NSString *URL;

-(BOOL) handleKeyEvent:(NSEvent *)event;

@end
