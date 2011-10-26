//
//  JSCocoaFFIArgument.h
//  JSCocoa
//
//  Created by Patrick Geiller on 14/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#if !TARGET_IPHONE_SIMULATOR && !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#define MACOSX
#include <ffi/ffi.h>
#endif
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import "iPhone/libffi/ffi.h"
#endif

@interface JSCocoaFFIArgument : NSObject {
	char		typeEncoding;
	NSString*	structureTypeEncoding;
	NSString*	pointerTypeEncoding;

	void*		ptr;

	ffi_type	structureType;
	
	id			customData;
	BOOL		isReturnValue;
	BOOL		ownsStorage;
	BOOL		isOutArgument;
}

- (NSString*)typeDescription;

- (BOOL)setTypeEncoding:(char)encoding;
- (BOOL)setTypeEncoding:(char)encoding withCustomStorage:(void*)storagePtr;
- (void)setStructureTypeEncoding:(NSString*)encoding;
- (void)setStructureTypeEncoding:(NSString*)encoding withCustomStorage:(void*)storagePtr;
- (void)setPointerTypeEncoding:(NSString*)encoding;

+ (int)sizeOfTypeEncoding:(char)encoding;
+ (int)alignmentOfTypeEncoding:(char)encoding;

+ (ffi_type*)ffi_typeForTypeEncoding:(char)encoding;

+ (int)sizeOfStructure:(NSString*)encoding;


+ (NSArray*)typeEncodingsFromStructureTypeEncoding:(NSString*)structureTypeEncoding;
+ (NSArray*)typeEncodingsFromStructureTypeEncoding:(NSString*)structureTypeEncoding parsedCount:(NSInteger*)count;


+ (NSString*)structureNameFromStructureTypeEncoding:(NSString*)structureTypeEncoding;
+ (NSString*)structureFullTypeEncodingFromStructureTypeEncoding:(NSString*)structureTypeEncoding;
+ (NSString*)structureFullTypeEncodingFromStructureName:(NSString*)structureName;
+ (NSString*)structureTypeEncodingDescription:(NSString*)structureTypeEncoding;

+ (BOOL)fromJSValueRef:(JSValueRef)value inContext:(JSContextRef)ctx typeEncoding:(char)typeEncoding fullTypeEncoding:(NSString*)fullTypeEncoding fromStorage:(void*)ptr;

+ (BOOL)toJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx typeEncoding:(char)typeEncoding fullTypeEncoding:(NSString*)fullTypeEncoding fromStorage:(void*)ptr;

+ (NSInteger)structureToJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx fromCString:(char*)c fromStorage:(void**)storage;
+ (NSInteger)structureToJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx fromCString:(char*)c fromStorage:(void**)ptr initialValues:(JSValueRef*)initialValues initialValueCount:(NSInteger)initialValueCount convertedValueCount:(NSInteger*)convertedValueCount;
+ (NSInteger)structureFromJSObjectRef:(JSObjectRef)value inContext:(JSContextRef)ctx inParentJSValueRef:(JSValueRef)parentValue fromCString:(char*)c fromStorage:(void**)ptr;

+ (void)alignPtr:(void**)ptr accordingToEncoding:(char)encoding;
+ (void)advancePtr:(void**)ptr accordingToEncoding:(char)encoding;


- (void*)allocateStorage;
- (void*)allocatePointerStorage;
- (void**)storage;
- (void**)rawStoragePointer;
- (char)typeEncoding;
- (NSString*)structureTypeEncoding;
- (id)pointerTypeEncoding;


- (void)setIsReturnValue:(BOOL)v;
- (BOOL)isReturnValue;
- (void)setIsOutArgument:(BOOL)v;
- (BOOL)isOutArgument;

- (BOOL)fromJSValueRef:(JSValueRef)value inContext:(JSContextRef)ctx;
- (BOOL)toJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx;


+ (BOOL)boxObject:(id)o toJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx;
+ (BOOL)unboxJSValueRef:(JSValueRef)value toObject:(id*)o inContext:(JSContextRef)ctx;
+ (BOOL)unboxJSArray:(JSObjectRef)value toObject:(id*)o inContext:(JSContextRef)ctx;
+ (BOOL)unboxJSHash:(JSObjectRef)value toObject:(id*)o inContext:(JSContextRef)ctx;


- (ffi_type*)ffi_type;

@end
