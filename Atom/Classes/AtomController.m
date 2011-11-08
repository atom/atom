#import "AtomController.h"
#import "AtomApp.h"

#import "JSCocoa.h"

#import <WebKit/WebKit.h>
#import <stdio.h>
#import <sys/types.h>
#import <dirent.h>

@implementation AtomController

@synthesize webView, path, jscocoa;

- (void)dealloc {
  [jscocoa unlinkAllReferences];
  [jscocoa garbageCollect];
  [jscocoa release]; jscocoa = nil;

  [webView release];
  [path release];

  [super dealloc];
}

- (id)initWithPath:(NSString *)aPath {
  aPath = aPath ? aPath : @"/tmp";
    
  self = [super initWithWindowNibName:@"AtomWindow"];
  path = [[aPath stringByStandardizingPath] retain];

  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];
  
  [[webView inspector] showConsole:self];
  
  [self.window setDelegate:self];
  [self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];

  [webView setUIDelegate:self];

  [self setShouldCascadeWindows:YES];
  [self setWindowFrameAutosaveName:@"atomController"];

  jscocoa =   [[JSCocoa alloc] initWithGlobalContext:[[webView mainFrame] globalContext]];
  [jscocoa setObject:self withName:@"$atomController"];

  NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
  NSURL *indexURL = [resourceURL URLByAppendingPathComponent:@"index.html"];
  NSURLRequest *request = [NSURLRequest requestWithURL:indexURL];
  [[webView mainFrame] loadRequest:request];    
}

// Helper methods that should go elsewhere
- (NSString *)tempfile {
  char *directory = "/tmp";
  char *prefix = "temp-file";
  char *tmpPath = tempnam(directory, prefix);
  NSString *tmpPathString = [NSString stringWithUTF8String:tmpPath];
  free(tmpPath);
  
  return tmpPathString;
}

- (NSArray *)scan:(NSString *)rootPath select:(JSValueRefAndContextRef)selectCallback compare:(JSValueRefAndContextRef)compareCallback{
  struct dirent **files;
  
  int (^select)(struct dirent *) = nil;
  if (selectCallback.value) {    
    select = ^(struct dirent *namelist) {
      return 1;
    };
  }

  int (^compare)(const void *, const void *) = nil;
  if (compareCallback.value) {
    compare = ^(const void *pathOne, const void *pathTwo) {
      return 1;
    };
  }
  
  int count = scandir_b([rootPath UTF8String], &files, select, compare);
  NSMutableArray *results = [NSMutableArray array];
  for (int i = 0; i < count; i++) {
    if (strncmp(files[i]->d_name, ".", files[i]->d_namlen) == 0) {
      continue;
    }
    else if (strncmp(files[i]->d_name, ".", files[i]->d_namlen) == 0) {
      continue;
    }
    
    NSString *name = [[NSString alloc] initWithBytes:files[i]->d_name length:files[i]->d_namlen encoding:NSUTF8StringEncoding];
    [results addObject:name];
    [name release];
    free(files[i]);
  }
  free(files);
  
  return results;
}

// WebUIDelegate
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
  return defaultMenuItems;
}

// WindowDelegate
- (BOOL)windowShouldClose:(id)sender {
  [(AtomApp *)NSApp removeController:self];
  return YES;
}
   
@end
