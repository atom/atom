#import <Cocoa/Cocoa.h>

@class AtomController, AtomMenuItem;

@interface AtomApp : NSApplication <NSApplicationDelegate>

@property (nonatomic, retain) NSMutableArray *controllers;

- (void)removeController:(AtomController *)controller;
- (IBAction)runSpecs:(id)sender;
- (void)performActionForMenuItem:(AtomMenuItem *)item;
- (void)resetMainMenu;

@end
