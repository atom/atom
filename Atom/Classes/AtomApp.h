#import <Cocoa/Cocoa.h>

@class AtomController;

@interface AtomApp : NSApplication <NSApplicationDelegate>

@property (nonatomic, retain) NSMutableArray *controllers;

- (AtomController *)createController:(NSString *)path;
- (AtomController *)createController:(NSString *)path;
- (void)removeController:(AtomController *)controller;
- (void)reloadController:(AtomController *)controller;

@end
