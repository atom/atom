#import <Foundation/Foundation.h>
#import "include/cef_base.h"

@protocol BrowserDelegate <NSObject>

@optional
- (void)afterCreated;
- (void)loadStart;
- (void)loadEnd;
- (bool)keyEventOfType:(cef_handler_keyevent_type_t)type code:(int)code modifiers:(int)modifiers isSystemKey:(bool)isSystemKey isAfterJavaScript:(bool)isAfterJavaScript;

@end
