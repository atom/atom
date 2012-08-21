#include "include/cef_app.h"

@interface Atom : NSApplication <CefAppProtocol, NSWindowDelegate, NSApplicationDelegate> {
@private
  BOOL handlingSendEvent_;
}

+ (void)populateAppSettings:(CefSettings &)settings;
- (void)createWindow;
- (void)populateBrowserSettings:(CefBrowserSettings &)settings;

@end