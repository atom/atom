// CocoaOniguruma is copyrighted free software by Satoshi Nakagawa <psychs AT limechat DOT net>.
// You can redistribute it and/or modify it under the new BSD license.

#import <Foundation/Foundation.h>
#import "oniguruma.h"
#import "OnigRegexp.h"


@class OnigRegexp;
@class OnigResult;


@interface NSString (OnigRegexpUtility)

// pattern is OnigRegexp or NSString

- (NSRange)rangeOfRegexp:(id)pattern;

// based on ruby's split

- (NSArray*)split;
- (NSArray*)splitByRegexp:(id)pattern;
- (NSArray*)splitByRegexp:(id)pattern limit:(int)limit;

// based on ruby's gsub

- (NSString*)replaceByRegexp:(id)pattern with:(NSString*)string;
- (NSString*)replaceAllByRegexp:(id)pattern with:(NSString*)string;

- (NSString*)replaceByRegexp:(id)pattern withCallback:(id)object selector:(SEL)sel;
- (NSString*)replaceAllByRegexp:(id)pattern withCallback:(id)object selector:(SEL)sel;

#if defined(NS_BLOCKS_AVAILABLE)
- (NSString*)replaceByRegexp:(id)pattern withBlock:(NSString* (^)(OnigResult*))block;
- (NSString*)replaceAllByRegexp:(id)pattern withBlock:(NSString* (^)(OnigResult*))block;
#endif

@end


@interface NSMutableString (OnigRegexpUtility)

// pattern is OnigRegexp or NSString

// based on ruby's gsub

- (NSMutableString*)replaceByRegexp:(id)pattern with:(NSString*)string;
- (NSMutableString*)replaceAllByRegexp:(id)pattern with:(NSString*)string;

- (NSMutableString*)replaceByRegexp:(id)pattern withCallback:(id)object selector:(SEL)sel;
- (NSMutableString*)replaceAllByRegexp:(id)pattern withCallback:(id)object selector:(SEL)sel;

#if defined(NS_BLOCKS_AVAILABLE)
- (NSMutableString*)replaceByRegexp:(id)pattern withBlock:(NSString* (^)(OnigResult*))block;
- (NSMutableString*)replaceAllByRegexp:(id)pattern withBlock:(NSString* (^)(OnigResult*))block;
#endif
@end
