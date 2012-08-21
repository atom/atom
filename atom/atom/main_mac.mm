#import "include/cef_application_mac.h"
#import "atom/cefclient_mac.h"

int main(int argc, char* argv[]) {
  @autoreleasepool {
		CefMainArgs mainArgs(argc, argv);
		CefRefPtr<CefApp> app;
		
		int exit_code = CefExecuteProcess(mainArgs, app.get());
		if (exit_code >= 0){
			return exit_code;
		}

		NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
		ClientApplication *application = (ClientApplication *)[ClientApplication sharedApplication];
		
		NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
		NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
		[mainNib instantiateNibWithOwner:application topLevelObjects:nil];  // Execute the secondary process, if any.
		
		[application createWindow];
		
		// Run the application message loop.
		CefRunMessageLoop();
	}
  
  // Don't put anything below this line because it won't be executed.
  return 0;
 }