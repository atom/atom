#import <Cocoa/Cocoa.h>

@class AtomController;

@interface AtomApp : NSApplication <NSApplicationDelegate>

@property (nonatomic, retain) NSMutableArray *controllers;

- (AtomController *)createController:(NSString *)path;
- (void)removeController:(AtomController *)controller;

@end
