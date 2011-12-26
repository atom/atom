#import <AppKit/AppKit.h>

@interface AtomMenuItem : NSMenuItem

@property BOOL global;
@property (nonatomic, retain) NSString *itemPath;

- initWithTitle:(NSString *)title itemPath:(NSString *)itemPath;

@end
