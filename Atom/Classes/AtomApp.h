#import <Cocoa/Cocoa.h>

@class AtomController;

@interface AtomApp : NSApplication <NSApplicationDelegate>

@property (nonatomic, retain) NSMutableArray *controllers;

- (void)removeController:(AtomController *)controller;
- (IBAction)runSpecs:(id)sender;
- (void)resetMainMenu;

@end
