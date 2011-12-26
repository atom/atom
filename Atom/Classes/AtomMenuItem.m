#import "AtomMenuItem.h"

@implementation AtomMenuItem

@synthesize global = global_, itemPath = path_;

- initWithTitle:(NSString *)title itemPath:(NSString *)itemPath {
  self = [super initWithTitle:title action:@selector(performActionForMenuItem:) keyEquivalent:@""];
  self.itemPath = itemPath;
  return self;
}


@end
