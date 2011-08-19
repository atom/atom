//
//  JSCocoaFFIArgument.m
//  JSCocoa
//
//  Created by Patrick Geiller on 14/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "JSCocoaFFIArgument.h"
#import "JSCocoaController.h"
#import "JSCocoaPrivateObject.h"
#import <objc/runtime.h>


#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import "GDataDefines.h"
#import "GDataXMLNode.h"
#endif

@implementation JSCocoaFFIArgument


- (id)init
{
	self	= [super init];

	ptr				= NULL;
	typeEncoding	= 0;
	isReturnValue	= NO;
	ownsStorage		= YES;
	isOutArgument	= NO;
	
	structureTypeEncoding	= nil;
	structureType.elements	= NULL;
	
	pointerTypeEncoding		= nil;
	
	// Used to store string data while converting JSStrings to char*
	customData		= nil;
	
	return	self;
}

- (void)cleanUp
{
	if (structureTypeEncoding)	[structureTypeEncoding release];
	if (pointerTypeEncoding)	[pointerTypeEncoding release];
	if (ptr && ownsStorage)		free(ptr);
	if (customData)				[customData release];

	if (structureType.elements)	free(structureType.elements);
	ptr = NULL;
}

- (void)dealloc
{
	[self cleanUp];
	[super dealloc];
}
- (void)finalize
{
	[self cleanUp];
	[super finalize];
}

- (NSString*)description
{
	return	[NSString stringWithFormat:@"JSCocoaFFIArgument %p typeEncoding=%c %@ isReturnValue=%d storage=%p", self, 
			typeEncoding, 
			(structureTypeEncoding ? structureTypeEncoding : @""),
			isReturnValue, ptr];
}

+ (NSString*)typeDescriptionForTypeEncoding:(char)typeEncoding fullTypeEncoding:(NSString*)fullTypeEncoding 
{
	switch (typeEncoding)
	{
		case	_C_VOID:	return	@"void";
		case	_C_ID:		return	@"ObjC object";
		case	_C_CLASS:	return	@"ObjC class";
		case	_C_CHR:		return	@"char";
		case	_C_UCHR:	return	@"unsigned char";
		case	_C_SHT:		return	@"short";
		case	_C_USHT:	return	@"unsigned short";
		case	_C_INT:		return	@"int";
		case	_C_UINT:	return	@"unsigned int";
		case	_C_LNG:		return	@"long";
		case	_C_ULNG:	return	@"unsigned long";
		case	_C_LNG_LNG:	return	@"long long";
		case	_C_ULNG_LNG:return	@"unsigned long long";
		case	_C_FLT:		return	@"float";
		case	_C_DBL:		return	@"double";
		case	'{':
		{
			// Special case for getting raw JSValues to ObjC
			BOOL isJSStruct = [fullTypeEncoding hasPrefix:@"{JSValueRefAndContextRef"];
			if (isJSStruct)
			{
				return	@"(JSCocoa structure used to pass JSValueRef without conversion)";
			}

//			if (!JSValueIsObject(ctx, value))	return	NO;
//			JSObjectRef object = JSValueToObject(ctx, value, NULL);
//			void* p = ptr;
//			id r = [JSCocoaFFIArgument structureFullTypeEncodingFromStructureTypeEncoding:fullTypeEncoding];
//			if (!r)	return [NSString stringWithFormat:@"(unknown structure %@)", fullTypeEncoding];
			return	[JSCocoaFFIArgument structureTypeEncodingDescription:fullTypeEncoding];
		}
		case	_C_SEL:		return	@"selector";
		case	_C_CHARPTR:	return	@"char*";
		case	_C_BOOL:	return	@"BOOL";
		case	_C_PTR:		return	@"pointer";
		case	_C_UNDEF:	return	@"(function pointer or block?)";
	}
	return	@"(unknown)";
}

- (NSString*)typeDescription
{
	return [[self class] typeDescriptionForTypeEncoding:typeEncoding fullTypeEncoding:structureTypeEncoding];
}

#pragma mark Getters / Setters

//
// Needed because libffi needs at least sizeof(long) as return value storage
//
- (void)setIsReturnValue:(BOOL)v
{
	isReturnValue = v;
}
- (BOOL)isReturnValue
{
	return	isReturnValue;
}

- (void)setIsOutArgument:(BOOL)v
{
	isOutArgument = v;
}
- (BOOL)isOutArgument
{
	return	isOutArgument;
}

- (char)typeEncoding
{
	return	typeEncoding;
}

- (BOOL)setTypeEncoding:(char)encoding
{
	if ([JSCocoaFFIArgument sizeOfTypeEncoding:encoding] == -1) { 
		NSLog(@"Bad type encoding %c", encoding); 
		return NO;
	};

	typeEncoding = encoding;
	[self allocateStorage];
	
	return	YES;	
}

- (BOOL)setTypeEncoding:(char)encoding withCustomStorage:(void*)storagePtr
{
	if ([JSCocoaFFIArgument sizeOfTypeEncoding:encoding] == -1)	{
		NSLog(@"Bad type encoding %c", encoding); 
		return NO;
	};

	typeEncoding	= encoding;
	ownsStorage		= NO;
	ptr				= storagePtr;
	
	return	YES;
}

- (NSString*)structureTypeEncoding
{
	return	structureTypeEncoding;
}

- (void)setStructureTypeEncoding:(NSString*)encoding
{
	[self setStructureTypeEncoding:encoding withCustomStorage:NULL];
}

- (void)setStructureTypeEncoding:(NSString*)encoding withCustomStorage:(void*)storagePtr
{
	typeEncoding = '{';
	structureTypeEncoding = [[NSString alloc] initWithString:encoding];
	
	if (storagePtr)
	{
		ownsStorage		= NO;
		ptr				= storagePtr;
	}
	else	[self allocateStorage];

	id types = [JSCocoaFFIArgument typeEncodingsFromStructureTypeEncoding:encoding];
	NSUInteger elementCount = [types count];

	//
	// Build FFI type
	//
	structureType.size	= 0;
	structureType.alignment	= 0;
	structureType.type	= FFI_TYPE_STRUCT;
	structureType.elements = malloc(sizeof(ffi_type*)*(elementCount+1));	// +1 is trailing NULL

	int i = 0;
	for (id type in types)
	{
		char charEncoding = *(char*)[type UTF8String];
		structureType.elements[i++] = [JSCocoaFFIArgument ffi_typeForTypeEncoding:charEncoding];
	}
	structureType.elements[elementCount] = NULL;
}

//
// type o handling
//	(pointers passed as arguments to a function, function writes values to these arguments)
//
- (void)setPointerTypeEncoding:(NSString*)encoding
{
	typeEncoding = '^';
	pointerTypeEncoding = [[NSString alloc] initWithString:encoding];
}

- (id)pointerTypeEncoding
{
	return	pointerTypeEncoding;
}


- (ffi_type*)ffi_type
{
	if (!typeEncoding)	return	NULL;
	if (pointerTypeEncoding)	return	&ffi_type_pointer;

	if (typeEncoding == '{')	return	&structureType;

	return	[JSCocoaFFIArgument ffi_typeForTypeEncoding:typeEncoding];
}


#pragma mark Storage 

- (void*)allocateStorage
{
	if (!typeEncoding)	return	NSLog(@"No type encoding set in %@", self), NULL;

	// NO ! will destroy structureTypeEncoding
//	[self cleanUp];
	// Special case for structs
	if (typeEncoding == '{')
	{
//		NSLog(@"allocateStorage: Allocating struct");
		// Some front padding for alignment and tail padding for structure
		// ( http://developer.apple.com/documentation/DeveloperTools/Conceptual/LowLevelABI/Articles/IA32.html )
		// Structures are tail-padded to 32-bit multiples.
		
		//	+16 for alignment
		//	+4 for tail padding
//		ptr = malloc([JSCocoaFFIArgument sizeOfStructure:structureTypeEncoding] + 16 + 4); 
		ptr = malloc([JSCocoaFFIArgument sizeOfStructure:structureTypeEncoding] + 4); 
		return	ptr;
	}
	
	int size = [JSCocoaFFIArgument sizeOfTypeEncoding:typeEncoding];

	// Bail if we can't handle our type
	if (size == -1)	return	NSLog(@"Can't handle type %c", typeEncoding), NULL;
	if (size >= 0)	
	{
		int	minimalReturnSize = sizeof(long);
		if (isReturnValue && size < minimalReturnSize)	size = minimalReturnSize;
		ptr = malloc(size);
	}
//	NSLog(@"Allocated size=%d (%p) for object %@", size, ptr, self);
	
	return	ptr;
}

// type o : out arguments (eg fn(int* pointerToIntResult))
- (void*)allocatePointerStorage
{
	typeEncoding = [pointerTypeEncoding UTF8String][1];
	if (typeEncoding == '{')
	{
		structureTypeEncoding = [pointerTypeEncoding substringFromIndex:1];
		[structureTypeEncoding retain];
	}
	[self allocateStorage];
	return ptr;
}

- (void**)storage
{
	if (typeEncoding == '{')
	{
/*	
		int alignOnSize = 16;
		
		int address = (int)ptr;
		if ((address % alignOnSize) != 0)
			address = (address+alignOnSize) & ~(alignOnSize-1);
*/		
		if (pointerTypeEncoding)	return &ptr;
//		return (void**)address;
	}
	
	// Type o : return writable address
//	if (pointerTypeEncoding)
	if (isOutArgument)
	{
		return &ptr;
	}

	return ptr;
}

- (void**)rawStoragePointer
{
	return	ptr;
}

// This	destroys the original pointer value by modifying it in place : maybe change to returning the new address ?
+ (void)alignPtr:(void**)ptr accordingToEncoding:(char)encoding
{
	int alignOnSize = [JSCocoaFFIArgument alignmentOfTypeEncoding:encoding];
	
	long address = (long)*ptr;
	if ((address % alignOnSize) != 0)
		address = (address+alignOnSize) & ~(alignOnSize-1);
//	NSLog(@"alignOf(%c)=%d", encoding, alignOnSize);

	*ptr = (void*)address;
}

// This	destroys the original pointer value by modifying it in place : maybe change to returning the new address ?
+ (void)advancePtr:(void**)ptr accordingToEncoding:(char)encoding
{
	long address = (long)*ptr;
	address += [JSCocoaFFIArgument sizeOfTypeEncoding:encoding];
	*ptr = (void*)address;
}


#pragma mark Conversion

//
// Convert from js value
//
- (BOOL)fromJSValueRef:(JSValueRef)value inContext:(JSContextRef)ctx
{
	BOOL r = [JSCocoaFFIArgument fromJSValueRef:value inContext:ctx typeEncoding:typeEncoding fullTypeEncoding:structureTypeEncoding?structureTypeEncoding:pointerTypeEncoding fromStorage:ptr];
	if (!r)	
	{
		NSLog(@"fromJSValueRef FAILED, jsType=%d encoding=%c structureEncoding=%@", JSValueGetType(ctx, value), typeEncoding, structureTypeEncoding);
	}
	return r;
}

+ (BOOL)fromJSValueRef:(JSValueRef)value inContext:(JSContextRef)ctx typeEncoding:(char)typeEncoding fullTypeEncoding:(NSString*)fullTypeEncoding fromStorage:(void*)ptr
{
	if (!typeEncoding)	return	NO;

//	JSType type = JSValueGetType(ctx, value);
//	NSLog(@"JSType=%d encoding=%c self=%p", type, typeEncoding, self);

	switch  (typeEncoding)
	{
		case	_C_ID:	
		case	_C_CLASS:
		{
			return [self unboxJSValueRef:value toObject:ptr inContext:ctx];
		}
		
		case	_C_CHR:
		case	_C_UCHR:
		case	_C_SHT:
		case	_C_USHT:
		case	_C_INT:
		case	_C_UINT:
		case	_C_LNG:
		case	_C_ULNG:
		case	_C_LNG_LNG:
		case	_C_ULNG_LNG:
		case	_C_FLT:
		case	_C_DBL:
		{
			double number = JSValueToNumber(ctx, value, NULL);
//			unsigned int u = number;
//			NSLog(@"type=%d typeEncoding=%c n=%f uint=%d, %d", JSValueGetType(ctx, value), typeEncoding, number, (unsigned int)number, u);

			switch  (typeEncoding)
			{
				case	_C_CHR:			*(char*)ptr = (char)number;								break;
				case	_C_UCHR:		*(unsigned char*)ptr = (unsigned char)number;			break;
				case	_C_SHT:			*(short*)ptr = (short)number;							break;
				case	_C_USHT:		*(unsigned short*)ptr = (unsigned short)number;			break;
				case	_C_INT:			
				case	_C_UINT:			
				{
#ifdef __BIG_ENDIAN__
					// Two step conversion : to unsigned int then to int. One step conversion fails on PPC.
					unsigned int uint = (unsigned int)number;
					*(signed int*)ptr = (signed int)uint;
					break;
#endif
#ifdef __LITTLE_ENDIAN__
					*(int*)ptr = (int)number;
					break;
#endif
				}
/*				
				case	_C_UINT:			
				{
					// Two step conversion : to unsigned int then to int. One step conversion fails on PPC.
					int uint = (int)number;
					unsigned int u = (unsigned)uint;
					NSLog(@"%d %u", uint, u);
					*(signed int*)ptr = (signed int)uint;
					break;
				}
*/
//				case	_C_UINT:		*(unsigned int*)ptr = (unsigned int)number;				break;
				case	_C_LNG:			*(long*)ptr = (long)number;								break;
				case	_C_ULNG:		*(unsigned long*)ptr = (unsigned long)number;			break;
				case	_C_LNG_LNG:		*(long long*)ptr = (long long)number;					break;
				case	_C_ULNG_LNG:	*(unsigned long long*)ptr = (unsigned long long)number;	break;
				case	_C_FLT:			*(float*)ptr = (float)number;							break;
				case	_C_DBL:			*(double*)ptr = (double)number;							break;
			}
			return	YES;
		}
		case	'{':
		{
			// Special case for getting raw JSValues to ObjC
//			BOOL isJSStruct = NSOrderedSame == [fullTypeEncoding compare:@"{JSValueRefAndContextRef" options:0 range:NSMakeRange(0, sizeof("{JSValueRefAndContextRef")-1)];
			BOOL isJSStruct = [fullTypeEncoding hasPrefix:@"{JSValueRefAndContextRef"];

			if (isJSStruct)
			{
				// Beware ! This context is not the global context and will be valid only for that call.
				// Other uses (closures) use the global context via JSCocoaController.
				JSValueRefAndContextRef*	jsStruct = (JSValueRefAndContextRef*)ptr;
				jsStruct->value	= value;
				jsStruct->ctx	= ctx;
				return	YES;
			}

			if (!JSValueIsObject(ctx, value))	return	NO;
			JSObjectRef object = JSValueToObject(ctx, value, NULL);
			void* p = ptr;
			id type = [JSCocoaFFIArgument structureFullTypeEncodingFromStructureTypeEncoding:fullTypeEncoding];
			NSInteger numParsed =	[JSCocoaFFIArgument structureFromJSObjectRef:object inContext:ctx inParentJSValueRef:NULL fromCString:(char*)[type UTF8String] fromStorage:&p];
			return	numParsed;
		}
		case	_C_SEL:
		{
			id str = NSStringFromJSValue(ctx, value);
			*(SEL*)ptr = NSSelectorFromString(str);
			return	YES;
		}
		case	_C_CHARPTR:
		{
			id str = NSStringFromJSValue(ctx, value);
			*(char**)ptr = (char*)[str UTF8String];
			return	YES;
		}
		case	_C_BOOL:
		{
			bool b = JSValueToBoolean(ctx, value);
			*(BOOL*)ptr = b;
			return	YES;
		}
		
		case	_C_PTR:
		{
			if ([fullTypeEncoding hasPrefix:@"^{OpaqueJSValue"])
			{
				NSLog(@"JSValueRef argument was converted to nil — to pass raw Javascript values to ObjC, use JSValueRefAndContextRef");
				*(id*)ptr = nil;
				return YES;
			}
			return [self unboxJSValueRef:value toObject:ptr inContext:ctx];
		}
		
	}
	return	NO;
}


//
// Convert to js value
//
- (BOOL)toJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx
{
	void* p = ptr;
#ifdef __BIG_ENDIAN__
	long	v;
	// Return value was padded, need to do some shifting on PPC
	if (isReturnValue)
	{
		int size = [JSCocoaFFIArgument sizeOfTypeEncoding:typeEncoding];
		int paddedSize = sizeof(long);
		
		if (size > 0 && size < paddedSize && paddedSize == 4)
		{
			v = *(long*)ptr;
			v = CFSwapInt32(v);
			p = &v;
		}
	}
#endif	
//	if (typeEncoding == '{')	p = [self storage];
	id encoding = structureTypeEncoding ? structureTypeEncoding : pointerTypeEncoding;
	BOOL r = [JSCocoaFFIArgument toJSValueRef:value inContext:ctx typeEncoding:typeEncoding fullTypeEncoding:encoding fromStorage:p];
	if (!r)	NSLog(@"toJSValueRef FAILED");
	return	r;
}


+ (BOOL)toJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx typeEncoding:(char)typeEncoding fullTypeEncoding:(NSString*)fullTypeEncoding fromStorage:(void*)ptr
{
	if (!typeEncoding)	return	NO;
	
//	NSLog(@"toJSValueRef: %c ptr=%p", typeEncoding, ptr);
	switch  (typeEncoding)
	{
		case	_C_ID:	
		case	_C_CLASS:
		{
			id objcObject = *(id*)ptr;
			return	[self boxObject:(id)objcObject toJSValueRef:value inContext:ctx];

		}
		
		case	_C_VOID: 
			return	YES;

		case	_C_CHR:
		case	_C_UCHR:
		case	_C_SHT:
		case	_C_USHT:
		case	_C_INT:
		case	_C_UINT:
		case	_C_LNG:
		case	_C_ULNG:
		case	_C_LNG_LNG:
		case	_C_ULNG_LNG:
		case	_C_FLT:
		case	_C_DBL:
		{
			double number;
			switch  (typeEncoding)
			{
				case	_C_CHR:			number = *(char*)ptr;				break;
				case	_C_UCHR:		number = *(unsigned char*)ptr;		break;
				case	_C_SHT:			number = *(short*)ptr;				break;
				case	_C_USHT:		number = *(unsigned short*)ptr;		break;
				case	_C_INT:			number = *(int*)ptr;				break;
				case	_C_UINT:		number = *(unsigned int*)ptr;		break;
				case	_C_LNG:			number = *(long*)ptr;				break;
				case	_C_ULNG:		number = *(unsigned long*)ptr;		break;
				case	_C_LNG_LNG:		number = *(long long*)ptr;			break;
				case	_C_ULNG_LNG:	number = *(unsigned long long*)ptr;	break;
				case	_C_FLT:			number = *(float*)ptr;				break;
				case	_C_DBL:			number = *(double*)ptr;				break;
			}
			*value = JSValueMakeNumber(ctx, number);
			return	YES;
		}
		
		
		case	'{':
		{
			// Special case for getting raw JSValues from ObjC to JS
			BOOL isJSStruct = [fullTypeEncoding hasPrefix:@"{JSValueRefAndContextRef"];
			if (isJSStruct)
			{
				JSValueRefAndContextRef*	jsStruct = (JSValueRefAndContextRef*)ptr;
				*value = jsStruct->value;
				return	YES;
			}
		
			void* p = ptr;
			id type = [JSCocoaFFIArgument structureFullTypeEncodingFromStructureTypeEncoding:fullTypeEncoding];
			// Bail if structure not found
			if (!type)	return	0;

//			JSObjectRef jsObject = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
			JSObjectRef jsObject = [[JSCocoa controllerFromContext:ctx] newPrivateObject];
			JSCocoaPrivateObject* private = JSObjectGetPrivate(jsObject);
			private.type = @"struct";
			NSInteger numParsed =	[JSCocoaFFIArgument structureToJSValueRef:value inContext:ctx fromCString:(char*)[type UTF8String] fromStorage:&p];
			return	numParsed;
		}

		case	_C_SEL:
		{
			SEL sel = *(SEL*)ptr;
			id str = NSStringFromSelector(sel);
//			JSStringRef jsName = JSStringCreateWithUTF8CString([str UTF8String]);
			JSStringRef	jsName = JSStringCreateWithCFString((CFStringRef)str);
			*value = JSValueMakeString(ctx, jsName);
			JSStringRelease(jsName);
			return	YES;
		}
		case	_C_BOOL:
		{
			BOOL b = *(BOOL*)ptr;
			*value = JSValueMakeBoolean(ctx, b);
			return	YES;
		}
		case	_C_CHARPTR:
		{
			// Rturn Javascript null if char* is null
			char* charPtr = *(char**)ptr;
			if (!charPtr)	
			{
				*value = JSValueMakeNull(ctx);
				return	YES;
			}
			// Convert to NSString and then to Javascript string
			NSString* name = [NSString stringWithUTF8String:charPtr];
			JSStringRef	jsName = JSStringCreateWithCFString((CFStringRef)name);
			*value = JSValueMakeString(ctx, jsName);
			JSStringRelease(jsName);
			return	YES;
		}
		
		case	_C_PTR:
		{
//			JSObjectRef o = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
			JSObjectRef o = [[JSCocoa controllerFromContext:ctx] newPrivateObject];
			JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
			private.type = @"rawPointer";
			[private setRawPointer:*(void**)ptr encoding:fullTypeEncoding];
			*value = o;
			return	YES;
		}
	}
	
	return	NO;
}

/*

	*value MUST be NULL to be receive allocated JSValue

	The given pointer is advanced in place : its value will change after the call.
	Pass a writeable pointer whose original value you don't care about.
	
*/
+ (NSInteger)structureToJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx fromCString:(char*)c fromStorage:(void**)ptr
{
	return	[self structureToJSValueRef:value inContext:ctx fromCString:c fromStorage:ptr initialValues:nil initialValueCount:0 convertedValueCount:nil];
}

+ (NSInteger)structureToJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx fromCString:(char*)c fromStorage:(void**)ptr initialValues:(JSValueRef*)initialValues initialValueCount:(NSInteger)initialValueCount convertedValueCount:(NSInteger*)convertedValueCount
{
	// Build new structure object
//	JSObjectRef jsObject = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
	JSObjectRef jsObject = [[JSCocoa controllerFromContext:ctx] newPrivateObject];
	JSCocoaPrivateObject* private = JSObjectGetPrivate(jsObject);
	private.type = @"struct";
	private.structureName = [JSCocoaFFIArgument structureNameFromStructureTypeEncoding:[NSString stringWithUTF8String:c]];
	if (!*value)	*value = jsObject;

	char* c0 = c;
	// Skip '{'
	c += 1;
	// Skip '_' if it's there
	if (*c == '_') c++;
	// Skip structureName, '='
	c += [private.structureName length]+1;

	int	openedBracesCount = 1;
	int closedBracesCount = 0;
	for (; *c && closedBracesCount != openedBracesCount; c++)
	{
		if (*c == '{')	openedBracesCount++;
		if (*c == '}')	closedBracesCount++;
		// Parse name then type
		if (*c == '"')
		{
			char* c2 = c+1;
			while (c2 && *c2 != '"') c2++;
			id propertyName = [[[NSString alloc] initWithBytes:c+1 length:(c2-c-1) encoding:NSUTF8StringEncoding] autorelease];
			c = c2;
			// Skip '"'
			c++;
			char encoding = *c;
			
			JSValueRef	valueJS = NULL;
			if (encoding == '{')
			{
				NSInteger numParsed = [self structureToJSValueRef:&valueJS inContext:ctx fromCString:c fromStorage:ptr initialValues:initialValues initialValueCount:initialValueCount convertedValueCount:convertedValueCount];
				c += numParsed;
			}
			else
			{
				// Given a pointer to raw C structure data, convert its members to JS values
				if (ptr)
				{
					// Align 
					[JSCocoaFFIArgument alignPtr:ptr accordingToEncoding:encoding];
					// Get value
					[JSCocoaFFIArgument toJSValueRef:&valueJS inContext:ctx typeEncoding:encoding fullTypeEncoding:nil fromStorage:*ptr];
					// Advance ptr
					[JSCocoaFFIArgument advancePtr:ptr accordingToEncoding:encoding];
				}
				else
				// Given no pointer, get values from initialValues array. If not present, create undefined values
				{
					if (!convertedValueCount)	return 0;
					if (initialValues && initialValueCount && *convertedValueCount < initialValueCount)	valueJS = initialValues[*convertedValueCount];
					else																				valueJS = JSValueMakeUndefined(ctx);									
				}
				if (convertedValueCount)	*convertedValueCount = *convertedValueCount+1;
			}
			JSStringRef	propertyNameJS = JSStringCreateWithCFString((CFStringRef)propertyName);
			JSObjectSetProperty(ctx, jsObject, propertyNameJS, valueJS, 0, NULL);
			JSStringRelease(propertyNameJS);
		}
	}
	return	c-c0-1;
}

+ (NSInteger)structureFromJSObjectRef:(JSObjectRef)object inContext:(JSContextRef)ctx inParentJSValueRef:(JSValueRef)parentValue fromCString:(char*)c fromStorage:(void**)ptr
{
	id structureName = [JSCocoaFFIArgument structureNameFromStructureTypeEncoding:[NSString stringWithUTF8String:c]];
	char* c0 = c;
	// Skip '{'
	c += 1;
	// Skip '_' if it's there
	if (*c == '_') c++;
	// Skip structureName, '='
	c += [structureName length]+1;

//	NSLog(@"%@", structureName);
	int	openedBracesCount = 1;
	int closedBracesCount = 0;
	for (; *c && closedBracesCount != openedBracesCount; c++)
	{
		if (*c == '{')	openedBracesCount++;
		if (*c == '}')	closedBracesCount++;
		// Parse name then type
		if (*c == '"')
		{
			char* c2 = c+1;
			while (c2 && *c2 != '"') c2++;
			id propertyName = [[[NSString alloc] initWithBytes:c+1 length:(c2-c-1) encoding:NSUTF8StringEncoding] autorelease];
			c = c2;
			
			// Skip '"'
			c++;
			char encoding = *c;
			
			JSStringRef propertyNameJS = JSStringCreateWithUTF8CString([propertyName UTF8String]);
			JSValueRef	valueJS = JSObjectGetProperty(ctx, object, propertyNameJS, NULL);
			JSStringRelease(propertyNameJS);
//			JSObjectRef objectProperty2 = JSValueToObject(ctx, valueJS, NULL);

//			NSLog(@"%c %@ %p %p", encoding, propertyName, valueJS, objectProperty2);
			if (encoding == '{')
			{
				if (JSValueIsObject(ctx, valueJS))
				{
					JSObjectRef objectProperty = JSValueToObject(ctx, valueJS, NULL);
					NSInteger numParsed = [self structureFromJSObjectRef:objectProperty inContext:ctx inParentJSValueRef:NULL fromCString:c fromStorage:ptr];
					c += numParsed;
				}
				else	return	0;
			}
			else
			{
				// Align 
				[JSCocoaFFIArgument alignPtr:ptr accordingToEncoding:encoding];
				// Get value
				[JSCocoaFFIArgument fromJSValueRef:valueJS inContext:ctx typeEncoding:encoding fullTypeEncoding:nil fromStorage:*ptr];
				// Advance ptr
				[JSCocoaFFIArgument advancePtr:ptr accordingToEncoding:encoding];
			}
			
		}
	}
	return	c-c0-1;
}



#pragma mark Encoding size, alignment, FFI

+ (int)sizeOfTypeEncoding:(char)encoding
{
	switch (encoding)
	{
		case	_C_ID:		return	sizeof(id);
		case	_C_CLASS:	return	sizeof(Class);
		case	_C_SEL:		return	sizeof(SEL);
		case	_C_CHR:		return	sizeof(char);
		case	_C_UCHR:	return	sizeof(unsigned char);
		case	_C_SHT:		return	sizeof(short);
		case	_C_USHT:	return	sizeof(unsigned short);
		case	_C_INT:		return	sizeof(int);
		case	_C_UINT:	return	sizeof(unsigned int);
		case	_C_LNG:		return	sizeof(long);
		case	_C_ULNG:	return	sizeof(unsigned long);
		case	_C_LNG_LNG:	return	sizeof(long long);
		case	_C_ULNG_LNG:return	sizeof(unsigned long long);
		case	_C_FLT:		return	sizeof(float);
		case	_C_DBL:		return	sizeof(double);
		case	_C_BOOL:	return	sizeof(BOOL);
		case	_C_VOID:	return	sizeof(void);
		case	_C_PTR:		return	sizeof(void*);
		case	_C_CHARPTR:	return	sizeof(char*);
		// Function pointers
//		case	_C_UNDEF:	return	sizeof(void*);
		// Blocks are encoded with @?
	}
	return	-1;
}

/*
	__alignOf__ returns 8 for double, but its struct align is 4

	use dummy structures to get struct alignment, each having a byte as first element
*/
typedef	struct { char a; id b;			} struct_C_ID;
typedef	struct { char a; char b;		} struct_C_CHR;
typedef	struct { char a; short b;		} struct_C_SHT;
typedef	struct { char a; int b;			} struct_C_INT;
typedef	struct { char a; long b;		} struct_C_LNG;
typedef	struct { char a; long long b;	} struct_C_LNG_LNG;
typedef	struct { char a; float b;		} struct_C_FLT;
typedef	struct { char a; double b;		} struct_C_DBL;
typedef	struct { char a; BOOL b;		} struct_C_BOOL;

+ (int)alignmentOfTypeEncoding:(char)encoding
{
	switch (encoding)
	{
		case	_C_ID:		return	offsetof(struct_C_ID, b);
		case	_C_CLASS:	return	offsetof(struct_C_ID, b);
		case	_C_SEL:		return	offsetof(struct_C_ID, b);
		case	_C_CHR:		return	offsetof(struct_C_CHR, b);
		case	_C_UCHR:	return	offsetof(struct_C_CHR, b);
		case	_C_SHT:		return	offsetof(struct_C_SHT, b);
		case	_C_USHT:	return	offsetof(struct_C_SHT, b);
		case	_C_INT:		return	offsetof(struct_C_INT, b);
		case	_C_UINT:	return	offsetof(struct_C_INT, b);
		case	_C_LNG:		return	offsetof(struct_C_LNG, b);
		case	_C_ULNG:	return	offsetof(struct_C_LNG, b);
		case	_C_LNG_LNG:	return	offsetof(struct_C_LNG_LNG, b);
		case	_C_ULNG_LNG:return	offsetof(struct_C_LNG_LNG, b);
		case	_C_FLT:		return	offsetof(struct_C_FLT, b);
		case	_C_DBL:		return	offsetof(struct_C_DBL, b);
		case	_C_BOOL:	return	offsetof(struct_C_BOOL, b);
		case	_C_PTR:		return	offsetof(struct_C_ID, b);
		case	_C_CHARPTR:	return	offsetof(struct_C_ID, b);
	}
	return	-1;
}


+ (ffi_type*)ffi_typeForTypeEncoding:(char)encoding
{
	switch (encoding)
	{
		case	_C_ID:
		case	_C_CLASS:
		case	_C_SEL:
		case	_C_PTR:		
		case	_C_CHARPTR:		return	&ffi_type_pointer;
						
		case	_C_CHR:			return	&ffi_type_sint8;
		case	_C_UCHR:		return	&ffi_type_uint8;
		case	_C_SHT:			return	&ffi_type_sint16;
		case	_C_USHT:		return	&ffi_type_uint16;
		case	_C_INT:
		case	_C_LNG:			return	&ffi_type_sint32;
		case	_C_UINT:
		case	_C_ULNG:		return	&ffi_type_uint32;
		case	_C_LNG_LNG:		return	&ffi_type_sint64;
		case	_C_ULNG_LNG:	return	&ffi_type_uint64;
		case	_C_FLT:			return	&ffi_type_float;
		case	_C_DBL:			return	&ffi_type_double;
		case	_C_BOOL:		return	&ffi_type_sint8;
		case	_C_VOID:		return	&ffi_type_void;
	}
	return	NULL;
}

//
// Type encodings
//	http://developer.apple.com/mac/library/documentation/cocoa/conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
//
//	Will change a bit between 32 and 64 bits (NSUInteger I->Q, CGFloat f->d)
//
static NSMutableDictionary* typeEncodings = nil;
+ (NSString*)typeEncodingForType:(NSString*)encoding
{
	if (!typeEncodings)
	{
		typeEncodings = [NSMutableDictionary new];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(char)]					forKey:@"char"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(int)]					forKey:@"int"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(short)]					forKey:@"short"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(long)]					forKey:@"long"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(long long)]				forKey:@"long long"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(unsigned char)]			forKey:@"unsigned char"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(unsigned int)]			forKey:@"unsigned int"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(unsigned short)]			forKey:@"unsigned short"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(unsigned long)]			forKey:@"unsigned long"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(unsigned long long)]		forKey:@"unsigned long long"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(float)]					forKey:@"float"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(double)]					forKey:@"double"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(bool)]					forKey:@"bool"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(void)]					forKey:@"void"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(char*)]					forKey:@"char*"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(id)]						forKey:@"id"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(Class)]					forKey:@"Class"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(SEL)]					forKey:@"selector"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(BOOL)]					forKey:@"BOOL"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(void*)]					forKey:@"void*"];

		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(NSInteger)]				forKey:@"NSInteger"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(NSUInteger)]				forKey:@"NSUInteger"];
		[typeEncodings setValue:[NSString stringWithUTF8String:@encode(CGFloat)]				forKey:@"CGFloat"];
	}
	return [typeEncodings valueForKey:encoding];
}


#pragma mark Structure encoding, size

/*
	From
		{_NSRect={_NSPoint=ff}{_NSSize=ff}}
		
	Return
		{_NSRect="origin"{_NSPoint="x"f"y"f}"size"{_NSSize="width"f"height"f}}
*/
+ (NSString*)structureNameFromStructureTypeEncoding:(NSString*)encoding
{
	// Extract structure name
	// skip '{'
	char*	c = (char*)[encoding UTF8String]+1;
	// skip '_' if it's there
	if (*c == '_')	c++;
	char*	c2 = c;
	while (*c2 && *c2 != '=') c2++;
	return [[[NSString alloc] initWithBytes:c length:(c2-c) encoding:NSUTF8StringEncoding] autorelease];
}

+ (NSMutableArray*)encodingsFromStructureTypeEncoding:(NSString*)encoding
{
	return	nil;
}

+ (NSString*)structureFullTypeEncodingFromStructureTypeEncoding:(NSString*)encoding
{
	id structureName = [JSCocoaFFIArgument structureNameFromStructureTypeEncoding:encoding];
	return	[self structureFullTypeEncodingFromStructureName:structureName];
}

+ (NSString*)structureFullTypeEncodingFromStructureName:(NSString*)structureName
{
	// Fetch structure type encoding from BridgeSupport
//	id xml = [[BridgeSupportController sharedController] query:structureName withType:@"struct"];
	id xml = [[BridgeSupportController sharedController] queryName:structureName type:@"struct"];

	if (xml == nil)
	{
		NSLog(@"No structure encoding found for %@", structureName);
		return	nil;
	}
	id xmlDocument = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:nil];
	if (!xmlDocument)	return	NO;
	id rootElement = [xmlDocument rootElement];
#if __LP64__	
	id type = [[rootElement attributeForName:@"type64"] stringValue];
#else
	id type = [[rootElement attributeForName:@"type"] stringValue];
#endif
	// Retain the string as releasing xmlDocument deallocs it
	[[type retain] autorelease];

	[xmlDocument release];
	return	type;
}


+ (NSArray*)typeEncodingsFromStructureTypeEncoding:(NSString*)structureTypeEncoding
{
	return [self typeEncodingsFromStructureTypeEncoding:structureTypeEncoding parsedCount:nil];
}


+ (NSArray*)typeEncodingsFromStructureTypeEncoding:(NSString*)structureTypeEncoding parsedCount:(NSInteger*)count
{
	id types = [[[NSMutableArray alloc] init] autorelease];
	char* c = (char*)[structureTypeEncoding UTF8String];
	char* c0 = c;
	int	openedBracesCount = 0;
	int closedBracesCount = 0;
	for (;*c; c++)
	{
		if (*c == '{')
		{
			openedBracesCount++;
			while (*c && *c != '=') c++;
			if (!*c)	continue;
		}
		if (*c == '}')
		{
			closedBracesCount++;
			
			// If we parsed something (c>c0) and have an equal amount of opened and closed braces, we're done
			if (c0 != c && openedBracesCount == closedBracesCount)	
			{
				c++;
				break;
			}
			continue;
		}
		if (*c == '=')	continue;
		
		[types addObject:[NSString stringWithFormat:@"%c", *c]];

		// Special case for pointers
		if (*c == '^')
		{
			// Skip pointers to pointers (^^^)
			while (*c && *c == '^')	c++;
			
			// Skip type, special case for structure
			if (*c == '{')
			{
				int	openedBracesCount2 = 1;
				int closedBracesCount2 = 0;
				c++;
				for (; *c && closedBracesCount2 != openedBracesCount2; c++)
				{
					if (*c == '{')	openedBracesCount2++;
					if (*c == '}')	closedBracesCount2++;
				}
				c--;
			}
			else c++;
		}
	}
	if (count) *count = c-c0;
	if (closedBracesCount != openedBracesCount)		return NSLog(@"Could not parse structure type encodings for %@", structureTypeEncoding), nil;
	return	types;
}

//
// Given a structure encoding string, produce a human readable format
//
+ (NSInteger)structureTypeEncodingDescription:(NSString*)structureTypeEncoding inString:(NSMutableString**)str
{
	char* c = (char*)[structureTypeEncoding UTF8String];
	char* c0 = c;
	// Skip '{'
	c += 1;
	// Skip '_' if it's there
	if (*c == '_') c++;
	// Skip structureName, '='
//	c += [private.structureName length]+1;
	id structureName = [self structureNameFromStructureTypeEncoding:structureTypeEncoding];
	c += [structureName length]+1;

	int	openedBracesCount = 1;
	int closedBracesCount = 0;
	int propertyCount = 0;
	for (; *c && closedBracesCount != openedBracesCount; c++)
	{
		if (*c == '{')	
		{
			[*str appendString:@"{"];
			openedBracesCount++;
		}
		if (*c == '}')	
		{
			[*str appendString:@"}"];
			closedBracesCount++;
		}
		// Parse name then type
		if (*c == '"')
		{
			propertyCount++;
			if (propertyCount > 1)	[*str appendString:@", "];
			char* c2 = c+1;
			while (c2 && *c2 != '"') c2++;
			id propertyName = [[[NSString alloc] initWithBytes:c+1 length:(c2-c-1) encoding:NSUTF8StringEncoding] autorelease];
			c = c2;
			// Skip '"'
			c++;
			char encoding = *c;
			[*str appendString:propertyName];
			[*str appendString:@": "];
			
//			JSValueRef	valueJS = NULL;
			if (encoding == '{')
			{
				[*str appendString:@"{"];
				NSInteger parsed = [self structureTypeEncodingDescription:[NSString stringWithUTF8String:c] inString:str];
				c += parsed;
//				NSLog(@"parsed %@ (%d)", substr, [substr length]);
			}
			else
			{
				[*str appendString:@"("];
				[*str appendString:[self typeDescriptionForTypeEncoding:encoding fullTypeEncoding:nil]];
				[*str appendString:@")"];
			}
		}
	}
	return	c-c0-1;
}
+ (NSString*)structureTypeEncodingDescription:(NSString*)structureTypeEncoding
{
	id fullStructureTypeEncoding = [self structureFullTypeEncodingFromStructureTypeEncoding:structureTypeEncoding];
	if (!fullStructureTypeEncoding)	return	[NSString stringWithFormat:@"(Could not describe struct %@)", structureTypeEncoding];

	id str = [NSMutableString stringWithFormat:@"%@{", [self structureNameFromStructureTypeEncoding:fullStructureTypeEncoding]];
	[self structureTypeEncodingDescription:fullStructureTypeEncoding inString:&str];
	[str appendString:@"}"];
	return	str;
}


+ (int)sizeOfStructure:(NSString*)encoding
{
	id types = [self typeEncodingsFromStructureTypeEncoding:encoding];
	int computedSize = 0;
	void** ptr = (void**)&computedSize;
	for (id type in types)
	{
		char charEncoding = *(char*)[type UTF8String];
		// Align 
		[JSCocoaFFIArgument alignPtr:ptr accordingToEncoding:charEncoding];
		// Advance ptr
		[JSCocoaFFIArgument advancePtr:ptr accordingToEncoding:charEncoding];
	}
	return	computedSize;
}


#pragma mark Object boxing / unboxing

//
// Box
//
+ (BOOL)boxObject:(id)objcObject toJSValueRef:(JSValueRef*)value inContext:(JSContextRef)ctx {
	// Return null if our pointer is null
	if (!objcObject) {
		*value = JSValueMakeNull(ctx);
		return	YES;
	}
	// Use a global boxing function to always return the same Javascript object 
	//	when requesting multiple boxings of the same ObjC object
	*value = [[JSCocoa controllerFromContext:ctx] boxObject:objcObject];
	return	YES;
}

//
// Unbox
//
+ (BOOL)unboxJSValueRef:(JSValueRef)value toObject:(id*)o inContext:(JSContextRef)ctx
{
	//
	//	Boxing
	//	
	//	string	-> NSString
	//	null	-> nil	(no box)
	//	number	-> NSNumber
	//	[]		-> NSMutableArray
	//	{}		-> NSMutableDictionary
	//
	
	// null
	if (!value || JSValueIsNull(ctx, value) || JSValueIsUndefined(ctx, value))
	{
		*(id*)o = nil;
		return	YES;
	}
	
	
	// string
	if (JSValueIsString(ctx, value))
	{
		JSStringRef resultStringJS = JSValueToStringCopy(ctx, value, NULL);
		NSString* resultString = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
//		NSLog(@"unboxed=%@", resultString);
		JSStringRelease(resultStringJS);
		[NSMakeCollectable(resultString) autorelease];
		*(id*)o = resultString;
		return	YES;
	}
	
	
	// number
	if (JSValueIsNumber(ctx, value))
	{
		double v = JSValueToNumber(ctx, value, NULL);
		// Integer
		if (fabs(round(v)-v) < 1e-6)
		{
			if (v < 0)	
			{
				*(id*)o = [NSNumber numberWithInt:(int)v];
//				NSLog(@"int %d", (int)v);
			}
			else		
			{
				*(id*)o = [NSNumber numberWithUnsignedInt:(unsigned int)v];
//				NSLog(@"UNSIGNED int %d", (unsigned int)v);
			}
		}
		// Double
		else
		{
			*(id*)o = [NSNumber numberWithDouble:v];
//			NSLog(@"double %f", v);
		}
		return	YES;
	}

	// bool
	if (JSValueIsBoolean(ctx, value))
	{
		bool v = JSValueToBoolean(ctx, value);
		if (v)	*(id*)o = [NSNumber numberWithBool:YES];
		else	*(id*)o = nil;
		return	YES;
	}

	// From here we must have a Javascript object (Array, Hash) or a boxed Cocoa object
	if (!JSValueIsObject(ctx, value))	
		return	NO;

	JSObjectRef jsObject = JSValueToObject(ctx, value, NULL);
	JSCocoaPrivateObject* private = JSObjectGetPrivate(jsObject);
	// Pure js hashes and arrays are converted to NSArray and NSDictionary
	if (!private)
	{
		// Use an anonymous function to test if object is Array or Object (hash)
		//	(can't use this.constructor==Array.prototype.constructor with JSEvaluateScript it doesn't take thisObject into account)
		JSStringRef scriptJS = JSStringCreateWithUTF8CString("return arguments[0].constructor == Array.prototype.constructor");
		JSObjectRef fn = JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
		JSValueRef result = JSObjectCallAsFunction(ctx, fn, NULL, 1, (JSValueRef*)&jsObject, NULL);
		JSStringRelease(scriptJS);

		BOOL isArray = JSValueToBoolean(ctx, result);
		
		if (isArray)	return	[self unboxJSArray:jsObject toObject:o inContext:ctx];
		else			return	[self unboxJSHash:jsObject toObject:o inContext:ctx];
	}
	// ## Hmmm ? CGColorRef is returned as a pointer but CALayer.foregroundColor asks an objc object (@)
/*
	if ([private.type isEqualToString:@"rawPointer"])			*(id*)o = [private rawPointer];
	else														*(id*)o = [private object];
*/

	id obj = [private object];
	
	if ([private.type isEqualToString:@"rawPointer"])			*(id*)o = [private rawPointer];
	else if (obj)															*(id*)o = obj;
	else	if ([private.type isEqualToString:@"externalJSValueRef"])
	{
		// Convert external jsValues by calling valueOf
		JSValueRef v = valueOfCallback(ctx, NULL, JSValueToObject(ctx, value, NULL), 0, NULL, NULL);
		return [self unboxJSValueRef:v toObject:o inContext:ctx];
	}
	else
	{
//	NSLog(@"********* %@", private.type);
		*(id*)o = nil;
	}

	return	YES;
}

//
// Convert ['a', 'b', 1.23] to an NSArray
//
+ (BOOL)unboxJSArray:(JSObjectRef)object toObject:(id*)o inContext:(JSContextRef)ctx
{
	// Get property count
	JSValueRef	exception = NULL;
	JSStringRef lengthJS = JSStringCreateWithUTF8CString("length");
	NSUInteger length = JSValueToNumber(ctx, JSObjectGetProperty(ctx, object, lengthJS, NULL), &exception);
	JSStringRelease(lengthJS);
	if (exception)	return	NO;

	// Converted array
	id array = [NSMutableArray array];
	// Converted array property
	id value;
	int i;
	// Loop over all properties of the array and call our trusty unboxer. 
	// He might reenter that function to convert arrays inside that array.
	for (i=0; i<length; i++)
	{
		JSValueRef jsValue =  JSObjectGetPropertyAtIndex(ctx, object, i, &exception);
		if (exception)	return	NO;
		if (![self unboxJSValueRef:jsValue toObject:&value inContext:ctx])	return	NO;
		// Add converted value to array
		[array addObject:value];		
	}
	*o = array;
	return	YES;
}

//
// Convert { hello : 'world', count : 7 } to an NSDictionary
//
+ (BOOL)unboxJSHash:(JSObjectRef)object toObject:(id*)o inContext:(JSContextRef)ctx
{
	// Keys
	JSPropertyNameArrayRef names = JSObjectCopyPropertyNames(ctx, object);
	NSUInteger length = JSPropertyNameArrayGetCount(names);

	// Converted hash
	id hash = [NSMutableDictionary dictionary];
	// Converted array property
	id value;

	JSValueRef	exception = NULL;
	int i;
	for (i=0; i<length; i++)
	{
		JSStringRef name	= JSPropertyNameArrayGetNameAtIndex(names, i);
		JSValueRef jsValue	= JSObjectGetProperty(ctx, object, name, &exception);
		if (exception)	return	NO;
		if (![self unboxJSValueRef:jsValue toObject:&value inContext:ctx])	return	NO;
		if (!value)	value = [NSValue valueWithPointer:NULL];
		
		// Add converted value to hash
		id key				= (NSString*)JSStringCopyCFString(kCFAllocatorDefault, name);
		[hash setObject:value forKey:key];
		[NSMakeCollectable(key) release];
	}
	JSPropertyNameArrayRelease(names);
	*o = hash;
	return	YES;
}



@end
