#import <Cocoa/Cocoa.h>

@class AtomController;

@interface AtomApp : NSApplication <NSApplicationDelegate>

@property (nonatomic, retain) NSMutableArray *controllers;

- (AtomController *)createController:(NSString *)path;
- (void)removeController:(AtomController *)controller;

- (id)storageGet:(NSString *)keyPath defaultValue:(id)defaultValue;
- (id)storageSet:(NSString *)keyPath value:(id)value;

@end
