#import <Foundation/Foundation.h>
#import "include/cef.h"

@protocol BrowserDelegate <NSObject>

@optional
- (void)afterCreated;
- (void)loadStart;
- (bool)keyEventOfType:(cef_handler_keyevent_type_t)type code:(int)code modifiers:(int)modifiers isSystemKey:(bool)isSystemKey isAfterJavaScript:(bool)isAfterJavaScript;

@end
