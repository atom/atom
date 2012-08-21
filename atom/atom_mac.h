#include "include/cef_app.h"

@interface Atom : NSApplication <CefAppProtocol, NSApplicationDelegate> {
@private
  BOOL handlingSendEvent_;
}

+ (void)populateAppSettings:(CefSettings &)settings;
- (void)createWindow;

@end