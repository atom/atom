#include "include/cef_app.h"
#include "include/cef_application_mac.h"

class AtomCefClient;

@interface AtomApplication : NSApplication <CefAppProtocol, NSApplicationDelegate> {
  NSWindowController *_backgroundWindowController;
  NSMutableDictionary *_arguments;
  BOOL handlingSendEvent_;
}

+ (id)applicationWithArguments:(char **)argv count:(int)argc;
+ (CefSettings)createCefSettings;
- (void)open:(NSString *)path;
- (IBAction)runSpecs:(id)sender;
- (IBAction)runBenchmarks:(id)sender;
- (void)runSpecsThenExit:(BOOL)exitWhenDone;
- (NSDictionary *)arguments;
- (void)runBenchmarksThenExit:(BOOL)exitWhenDone;

@property (nonatomic, readonly) NSDictionary *arguments;

@end