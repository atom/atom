#import "include/cef_application_mac.h"
#import "atom/atom_application.h"

int main(int argc, char* argv[]) {
  @autoreleasepool {
		CefMainArgs mainArgs(argc, argv);
		CefRefPtr<CefApp> app;
		
//    TODO: Ask marshal why we need this?
//		int exit_code = CefExecuteProcess(mainArgs, app.get());
//		if (exit_code >= 0){
//			return exit_code;
//		}

		NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
		AtomApplication *application = (AtomApplication *)[AtomApplication sharedApplication];
		
		NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
		NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
		[mainNib instantiateNibWithOwner:application topLevelObjects:nil];
		
		[application open:@""];
		
		CefRunMessageLoop();
	}
  
  return 0;
}