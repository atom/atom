//
//  JSCocoaLib.h
//  JSCocoa
//
//  Created by Patrick Geiller on 21/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#if !TARGET_IPHONE_SIMULATOR && !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#endif
#import "JSCocoa.h"

@class JSCocoaMemoryBuffer;

@interface JSCocoaOutArgument : NSObject
{
	JSCocoaFFIArgument*		arg;
	JSCocoaMemoryBuffer*	buffer;
	int						bufferIndex;
}
- (BOOL)mateWithJSCocoaFFIArgument:(JSCocoaFFIArgument*)arg;
- (JSValueRef)outJSValueRefInContext:(JSContextRef)ctx;

@end



@interface JSCocoaMemoryBuffer : NSObject
{
	void*	buffer;
	int		bufferSize;
	// NSString holding types
	id		typeString;

	// Indicates whether types are aligned.
	// types not aligned (DEFAULT)
	//	size('fcf') = 4 + 1 + 4 = 9
	// types aligned
	//	size('fcf') = 4 + 4(align) + 4 = 12
	BOOL	alignTypes;
}
+ (id)bufferWithTypes:(id)types;
- (id)initWithTypes:(id)types;
//- (id)initWithTypes:(id)types andValues:(id)values;
//- (id)initWithMemoryBuffers:(id)buffers;

- (void*)pointerForIndex:(NSUInteger)index;
- (char)typeAtIndex:(NSUInteger)index;
- (JSValueRef)valueAtIndex:(NSUInteger)index inContext:(JSContextRef)ctx;
- (BOOL)setValue:(JSValueRef)jsValue atIndex:(NSUInteger)index inContext:(JSContextRef)ctx;
- (NSUInteger)typeCount;

@end


@interface JSCocoaLib : NSObject

+ (id)rootclasses;
+ (id)classes;
+ (id)protocols;
+ (id)imageNames;
+ (id)methods;
+ (id)runtimeReport;

@end



@interface NSObject(ClassWalker)
+ (id)__classImage;
- (id)__classImage;
+ (id)__derivationPath;
- (id)__derivationPath;
+ (NSUInteger)__derivationLevel;
- (NSUInteger)__derivationLevel;
+ (id)__ownMethods;
- (id)__ownMethods;
+ (id)__methods;
- (id)__methods;
+ (id)__subclasses;
- (id)__subclasses;
+ (id)__subclassTree;
- (id)__subclassTree;
+ (id)__ownIvars;
- (id)__ownIvars;
+ (id)__ivars;
- (id)__ivars;
+ (id)__ownProperties;
- (id)__ownProperties;
+ (id)__properties;
- (id)__properties;
+ (id)__ownProtocols;
- (id)__ownProtocols;
+ (id)__protocols;
- (id)__protocols;

@end
