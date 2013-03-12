#include "include/cef_app.h"
#include "include/cef_application_mac.h"

class AtomCefClient;

@interface AtomApplication : NSApplication <CefAppProtocol, NSApplicationDelegate> {
  IBOutlet NSMenuItem *_versionMenuItem;
  NSWindowController *_backgroundWindowController;
  NSDictionary *_arguments;
  NSInvocation *_updateInvocation;
  NSString *_updateStatus;
  BOOL _filesOpened;
  BOOL _handlingSendEvent;
}

+ (AtomApplication *)sharedApplication;
+ (id)applicationWithArguments:(char **)argv count:(int)argc;
+ (CefSettings)createCefSettings;
+ (NSDictionary *)parseArguments:(char **)argv count:(int)argc;
- (void)open:(NSString *)path;
- (void)openDev:(NSString *)path;
- (void)open:(NSString *)path pidToKillWhenWindowCloses:(NSNumber *)pid;
- (IBAction)runSpecs:(id)sender;
- (IBAction)runBenchmarks:(id)sender;
- (void)runSpecsThenExit:(BOOL)exitWhenDone;
- (NSDictionary *)arguments;
- (void)runBenchmarksThenExit:(BOOL)exitWhenDone;

@property (nonatomic, retain) NSDictionary *arguments;

@end
