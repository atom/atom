//
//  JSCocoaLib.m
//  JSCocoa
//
//  Created by Patrick Geiller on 21/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "JSCocoaLib.h"


//
// Handles out arguments of functions and methods.
//	eg NSOpenGLGetVersion(int*, int*) asks for two pointers to int.
//	JSCocoaOutArgument will alloc the memory through JSCocoaFFIArgument and get the result back to Javascript (check out value in JSCocoaController)
//
@implementation JSCocoaOutArgument

- (id)init
{
	self	= [super init];

	arg		= nil;
	buffer	= nil;
	return self;
}
- (void)cleanUp
{
	[arg release];
	[buffer release];
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


//
// convert the out value to a JSValue
//
- (JSValueRef)outJSValueRefInContext:(JSContextRef)ctx
{
	JSValueRef jsValue = NULL;
	[arg toJSValueRef:&jsValue inContext:ctx];
	return	jsValue;
}

// Called from Javascript to extract the resulting value as an object (valueOfCallback returns a string)
- (JSValueRefAndContextRef)outValue
{
	JSValueRefAndContextRef r;

	id	jsc = nil;
	object_getInstanceVariable(self, "__jsCocoaController", (void**)&jsc);
	if (!jsc)	return r;
	
	r.ctx	= [jsc ctx];
	r.value	= [self outJSValueRefInContext:r.ctx];

	return r;
}



//
//	JSCocoaOutArgument holds a JSCocoaFFIArgument around.
//	it stays alive after ffi_call and can be queried by Javascript for type modifier values.
//	
- (BOOL)mateWithJSCocoaFFIArgument:(JSCocoaFFIArgument*)_arg
{
	// If holding a memory buffer, use its pointer
	if (buffer)
	{
		arg	= _arg;
		[arg retain];
		void* ptr = [buffer pointerForIndex:bufferIndex];
		if (!ptr)	return	NO;
		[arg setTypeEncoding:[arg typeEncoding] withCustomStorage:ptr];
		return	YES;
	}

	// Standard pointer
	void* p = [_arg allocatePointerStorage];
	if (!p)	return	NO;
	
	// Zero out storage
	*(void**)p = NULL;
	

	arg	= _arg;
	[arg retain];
	return	YES;
}

- (BOOL)mateWithMemoryBuffer:(id)b atIndex:(int)idx
{
	if (!b || ![b isKindOfClass:[JSCocoaMemoryBuffer class]])	return	NSLog(@"mateWithMemoryBuffer called without a memory buffer (%@)", b), NO;
	buffer = b;
	[buffer retain];
	bufferIndex = idx;
	return	YES;
}

@end



//
// Instead of malloc(sizeof(float)*4), JSCocoaMemoryBuffer expects 'ffff' as an init string.
//	The buffer can be manipulated like an array (buffer[2] = 0.5) 
//		* it can be filled, calling methods to copy data in it
//			- (NSBezierPathElement)elementAtIndex:(NSInteger)index associatedPoints:(NSPointArray)points;
//		* it can be used as data source, calling methods to copy data from it
//			- (void)setAssociatedPoints:(NSPointArray)points atIndex:(NSInteger)index;
//
@implementation JSCocoaMemoryBuffer

+ (id)bufferWithTypes:(id)types
{
	return [[[JSCocoaMemoryBuffer alloc] initWithTypes:types] autorelease];
}


- (id)initWithTypes:(id)_types
{
	self	= [super init];
	buffer	= NULL;

	// Copy types string
	typeString = [NSString stringWithString:_types];
	[typeString retain];

	// Compute buffer size
	const char* types = [typeString UTF8String];
	NSUInteger l = [typeString length];
	bufferSize = 0;
	for (int i=0; i<l; i++)
	{
		int size = [JSCocoaFFIArgument sizeOfTypeEncoding:types[i]];
		if (size == -1)	return	NSLog(@"JSCocoaMemoryBuffer initWithTypes : unknown type %c", types[i]), self;
		bufferSize += size;
	}
	
	if (bufferSize == 0) {
		NSLog(@"initWithTypes has no types");
		return NULL;
	}

	// Malloc
//	NSLog(@"mallocing %d bytes for %@", bufferSize, typeString);
	buffer = malloc(bufferSize);
	memset(buffer, bufferSize, 1);
	
	return	self;
}

- (void)dealloc	
{
	if (buffer)	free(buffer);
	[typeString release];
	[super dealloc];
}
- (void)finalize
{
	if (buffer)	free(buffer);
	[super finalize];
}

//
// Returns pointer for index without any padding
//
- (void*)pointerForIndex:(NSUInteger)idx
{
	const char* types = [typeString UTF8String];
	if (idx >= [typeString length])	return NULL;
	void* pointedValue = buffer;
	for (int i=0; i<idx; i++)
	{
//		NSLog(@"advancing %c", types[i]);
		[JSCocoaFFIArgument advancePtr:&pointedValue accordingToEncoding:types[i]];
	}
	return	pointedValue;
}

- (char)typeAtIndex:(NSUInteger)idx
{
	if (idx >= [typeString length])	return '\0';
	return	[typeString UTF8String][idx];
}

- (NSUInteger)typeCount
{
	return	[typeString length];
}

-(BOOL)referenceObject:(id)o usingPointerAtIndex:(NSUInteger)idx
{
	if ([self typeAtIndex:idx] != '^')	return NO;
	
	void* v = *(void**)[self pointerForIndex:idx];
	if (!v)	return NO;
	*(id*)v = o;
	return YES;
}

- (id)dereferenceObjectAtIndex:(NSUInteger)idx
{
	if ([self typeAtIndex:idx] != '^')	return nil;
	void* v = *(void**)[self pointerForIndex:idx];
	if (!v)	return NULL;

	id o = *(id*)v;
	return o;
	return	*(id*)v;
}

//
// Using JSValueRefAndContextRef as input to get the current context in which to create the return value
//
- (JSValueRef)valueAtIndex:(NSUInteger)idx inContext:(JSContextRef)ctx
{
	char	typeEncoding = [self typeAtIndex:idx];
	void*	pointedValue = [self pointerForIndex:idx];
	if (!pointedValue)	return JSValueMakeUndefined(ctx);
	JSValueRef returnValue;
	[JSCocoaFFIArgument toJSValueRef:&returnValue inContext:ctx typeEncoding:typeEncoding fullTypeEncoding:nil fromStorage:pointedValue];
	return	returnValue;
}

- (BOOL)setValue:(JSValueRef)jsValue atIndex:(NSUInteger)idx inContext:(JSContextRef)ctx
{
	char	typeEncoding = [self typeAtIndex:idx];
	void*	pointedValue = [self pointerForIndex:idx];
	if (!pointedValue)	return NO;
	[JSCocoaFFIArgument fromJSValueRef:jsValue inContext:ctx typeEncoding:typeEncoding fullTypeEncoding:nil fromStorage:pointedValue];
	return	YES;
}


@end



@implementation JSCocoaLib

//
// Class list 
//	Some classes are skipped as adding them to an array crashes (Zombie, classes derived from Object or NSProxy)
//
+ (NSArray*)classes
{
	int classCount		= objc_getClassList(nil, 0);
	Class* classList	= malloc(sizeof(Class)*classCount);
	objc_getClassList(classList, classCount);
	
	
	NSMutableArray* classArray	= [NSMutableArray array];
	for (int i=0; i<classCount; i++)
	{
		id class		= classList[i];
		const char* name= class_getName(class);
		if (!name)		continue;
		id className	= [NSString stringWithUTF8String:name];
		
		id superclass	= class_getSuperclass(class);
		id superclassName = superclass ? [NSString stringWithUTF8String:class_getName(superclass)] : @"";
		
		// Check if this class inherits from NSProxy. isKindOfClass crashes, so use raw ObjC api.
		BOOL	isKindOfNSProxy = NO;
		id c = class;
		while (c)
		{
			if ([[NSString stringWithUTF8String:class_getName(c)] isEqualToString:@"NSProxy"])	isKindOfNSProxy = YES;
			c = class_getSuperclass(c);
		}

		// Skip classes crashing when added to an NSArray
		if ([className hasPrefix:@"_NSZombie_"] 
		||	[className isEqualToString:@"Object"]
		||	[superclassName isEqualToString:@"Object"]
		||	[className isEqualToString:@"NSMessageBuilder"]
		||	[className isEqualToString:@"NSLeafProxy"]
		||	[className isEqualToString:@"__NSGenericDeallocHandler"]
		||	isKindOfNSProxy
		)
		{
			continue;
		}
		
		[classArray addObject:class];
	}

	free(classList);
	return	classArray;
}

+ (NSArray*)rootclasses
{
	id classes = [self classes];
	NSMutableArray* classArray	= [NSMutableArray array];
	for (id class in classes)
	{
		id superclass = class_getSuperclass(class);
		if (superclass)	continue;

		[classArray addObject:class];
	}
	return	classArray;
}

//
// Return an array of { name : imageName, classNames : [className, className, ...] }
//
+ (id)imageNames
{
	id array = [NSMutableArray array];

	unsigned int imageCount;
	const char** imageNames = objc_copyImageNames(&imageCount);

	for (int i=0; i<imageCount; i++)
	{
		const char* cname	= imageNames[i];

		// Gather image class names
		id array2 = [NSMutableArray array];
		unsigned int classCount;
		const char** classNames = objc_copyClassNamesForImage(cname, &classCount);
		for (int j=0; j<classCount; j++)
			[array2 addObject:[NSString stringWithUTF8String:classNames[j]]];

		free(classNames);

		// Hash of name and classNames
		id name	= [NSString stringWithUTF8String:cname];
		id hash = [NSDictionary dictionaryWithObjectsAndKeys:
			name,		@"name",
			array2,		@"classNames",
			nil];
			
		[array addObject:hash];
	}
	free(imageNames);
	return	array;
}

//
// Return protocols and their associated methods
//
+ (id)protocols
{
#if NS_BLOCKS_AVAILABLE
	id array = [NSMutableArray array];
	unsigned int protocolCount;
	Protocol** protocols = objc_copyProtocolList(&protocolCount);

	for (int i=0; i<protocolCount; i++)
	{
		// array2 is modified by the following block
		__block id array2	= [NSMutableArray array];
		Protocol* p	= protocols[i];

		// Common block for copying protocol method descriptions
		void (^b)(BOOL, BOOL) = ^(BOOL isRequiredMethod, BOOL isInstanceMethod) {
			unsigned int descriptionCount;
			struct objc_method_description* methodDescriptions = protocol_copyMethodDescriptionList(p, isRequiredMethod, isInstanceMethod, &descriptionCount);
			for (int j=0; j<descriptionCount; j++)
			{
				struct objc_method_description d = methodDescriptions[j];

				id name			= NSStringFromSelector(d.name);
				id encoding		= [NSString stringWithUTF8String:d.types];
				id isRequired	= [NSNumber numberWithBool:isRequiredMethod];
				id type			= isInstanceMethod ? @"instance" : @"class";

				id hash = [NSDictionary dictionaryWithObjectsAndKeys:
					name,		@"name",
					encoding,	@"encoding",
					isRequired,	@"isRequired",
					type,		@"type",
					nil];
					
				[array2 addObject:hash];
			}
			if (methodDescriptions)	free(methodDescriptions);
		};
		
		// Copy all methods, going through required, non-required, class, instance methods
		b(YES, YES);
		b(YES, NO);
		b(NO, YES);
		b(NO, NO);
		
		// Main object : { name : protocolName, methods : [{ name, encoding, isRequired, type }, ...]
		id name	= [NSString stringWithUTF8String:protocol_getName(p)];
		
		id hash = [NSDictionary dictionaryWithObjectsAndKeys:
			name,		@"name",
			array2,		@"methods",
			nil];
			
		[array addObject:hash];
	}
	free(protocols);
	return	array;
#else
	return	nil;
#endif
}

+ (id)methods
{
	id classes = [self classes];
	id methods = [NSMutableArray array];
	for (id class in classes)
		[methods addObjectsFromArray:[class __ownMethods]];
	return methods;
}

//
// Runtime report
//	Report EVERYTHING
//	classes
//		{ className : { name
//						superclassName
//						derivationPath
//						subclasses
//						methods
//						protocols
//						ivars
//						properties
//					  }
//	protocols
//		{ protocolName : { name
//						   methods
//						 }
//	imageNames
//		{ imageName : { name
//						classNames : [className1, className2, ...]
//					  }
//
+ (id)runtimeReport
{
/*
	id classList	= [self classes];
	id protocols	= [self protocols];
	id imageNames	= [self imageNames];
	
	id classes		= [NSMutableDictionary dictionary];
	int classCount	= [classList count];
//	for (id class in classList)
	for (int i=0; i<classCount; i++)
	{
		id class = [classList objectAtIndex:i];
		id className = [class description];
		NSLog(@"%d/%d %@", i, (classCount-1), className);

		id superclass		= [class superclass];
		id superclassName	= superclass ? [NSString stringWithUTF8String:class_getName(superclass)] : nil;
//NSLog(@"%@ (%d/%d)", className, i, classCount-1);
		id hash = [NSDictionary dictionaryWithObjectsAndKeys:
			className,					@"name",
			superclassName,				@"superclassName",
			[class __derivationPath],	@"derivationPath",
			[class __methods],			@"methods",
			[class __protocols],		@"protocols",
			[class __ivars],			@"ivars",
			[class __properties],		@"properties",
			nil];
		[classes setObject:hash forKey:className];
	}
	
	id dict = [NSDictionary dictionaryWithObjectsAndKeys:
				classes,	@"classes",
				protocols,	@"protocols",
				imageNames,	@"imageNames",
				nil];
*/
	// This happens on the ObjC side, NOT in jsc.	
	// There are 2500 classes to dump, this takes a while.
	// The memory hog is also on the ObjC side, happening during [dict description]
	return	@"Disabled for now, as the resulting hash hangs the app while goring memory";
}

@end


//
// Runtime information
//
@implementation NSObject(ClassWalker)

//
// Class name (description might have been overriden, and classes don't seem to travel well over NSDistantObject)
//
- (id)__className
{	
	return [[self class] description];
}


//
// Returns which framework containing the class
//
+ (id)__classImage
{
	const char* name = class_getImageName(self);
	if (!name)	return	nil;
	return	[NSString stringWithUTF8String:name];
}
- (id)__classImage
{	
	return [[self class] __classImage];
}


//
// Derivation path
//	derivationPath(NSButton) = NSObject, NSResponder, NSView, NSControl, NSButton
//
+ (id)__derivationPath
{
	int level = -1;
	id class = self;
	id classes = [NSMutableArray array];
	while (class)
	{
		[classes insertObject:class atIndex:0];
		level++;
		class = [class superclass];
	}
	return	classes;
}
- (id)__derivationPath
{
	return [[self class] __derivationPath];
}

//
// Derivation level
//
+ (NSUInteger)__derivationLevel
{
	return [[self __derivationPath] count]-1;
}
- (NSUInteger)__derivationLevel
{
	return [[self class] __derivationLevel];
}

//
// Methods
//

// Copy all class or instance (type) methods of a class in an array
static id copyMethods(Class class, NSMutableArray* array, NSString* type)
{
	if ([type isEqualToString:@"class"])	class = objc_getMetaClass(class_getName(class));

	unsigned int methodCount;
	Method* methods = class_copyMethodList(class, &methodCount);

	for (int i=0; i<methodCount; i++)
	{
		Method m	= methods[i];
		Dl_info info;
		dladdr(method_getImplementation(m), &info);

		id name		= NSStringFromSelector(method_getName(m));
		id encoding	= [NSString stringWithUTF8String:method_getTypeEncoding(m)];
		id framework= [NSString stringWithUTF8String:info.dli_fname];
		
		id hash = [NSDictionary dictionaryWithObjectsAndKeys:
			name,		@"name",
			encoding,	@"encoding",
			type,		@"type",
			class,		@"class",
			framework, @"framework",
			nil];
			
		[array addObject:hash];
	}
	free(methods);
	return	array;
}
+ (id)__ownMethods
{
	id methods = [NSMutableArray array];
	copyMethods([self class], methods, @"class");
	copyMethods([self class], methods, @"instance");
	return methods;
}
- (id)__ownMethods
{
	return [[self class] __ownMethods];
}
+ (id)__methods
{
	id classes	= [self __derivationPath];
	id methods	= [NSMutableArray array];
	for (id class in classes)
		[methods addObjectsFromArray:[class __ownMethods]];
	return	methods;
}
- (id)__methods
{
	return [[self class] __methods];
}


//
// Subclasses
//

// Recursively go breadth first all a class' subclasses
static void populateSubclasses(Class class, NSMutableArray* array, NSMutableDictionary* subclassesHash)
{
	// Add ourselves
	[array addObject:class];
	
	id className	= [NSString stringWithUTF8String:class_getName(class)];
	id subclasses = [subclassesHash objectForKey:className];
	for (id subclass in subclasses)
	{
		populateSubclasses(subclass, array, subclassesHash);
	}
}
// Build a hash of className : [direct subclasses] then walk it down recursively.
+ (id)__subclasses
{
#if NS_BLOCKS_AVAILABLE
	id classes		= [JSCocoaLib classes];
	id subclasses	= [NSMutableArray array];
	id subclassesHash	= [NSMutableDictionary dictionary];
	
	for (id class in classes)
	{
		id superclass		= [class superclass];
		if (!superclass)	continue;
		id superclassName	= [NSString stringWithUTF8String:class_getName(superclass)];
		
		id subclassesArray	= [subclassesHash objectForKey:superclassName];
		if (!subclassesArray)
		{
			subclassesArray	= [NSMutableArray array];
			[subclassesHash setObject:subclassesArray forKey:superclassName];
		}
		[subclassesArray addObject:class];
	}
	
	// (Optional) sort by class name
	for (id className in subclassesHash)
	{
		id subclassesArray = [subclassesHash objectForKey:className];
		[subclassesArray sortUsingComparator:
			^(id a, id b)	
			{
				// Case insensitive compare + remove underscores for sorting (yields [..., NSStatusBarButton, _NSThemeWidget, NSToolbarButton] )
				return [[[a description] stringByReplacingOccurrencesOfString:@"_" withString:@""] 
						compare:[[b description] stringByReplacingOccurrencesOfString:@"_" withString:@""] options:NSCaseInsensitiveSearch];
			}];
	}
	
	populateSubclasses(self, subclasses, subclassesHash);
	return	subclasses;
#else
	return	nil;
#endif
}
- (id)__subclasses
{
	return [[self class] __subclasses];
}

// Returns a string showing subclasses, prefixed with as many spaces as their derivation level
+ (id)__subclassTree
{
	id subclasses = [self __subclasses];
	id str = [NSMutableString string];
	for (id subclass in subclasses)
	{
		NSUInteger level = [subclass __derivationLevel];
		for (int i=0; i<level; i++)
			[str appendString:@" "];
		[str appendString:[NSString stringWithUTF8String:class_getName(subclass)]];
		[str appendString:@"\n"];
	}
	return	str;
}
- (id)__subclassTree
{
	return [[self class] __subclassTree];
}

//
// ivars
//
+ (id)__ownIvars
{
	unsigned int ivarCount;
	Ivar* ivars = class_copyIvarList(self, &ivarCount);
	
	id array = [NSMutableArray array];
	for (int i=0; i<ivarCount; i++)
	{
		Ivar ivar	= ivars[i];
		
		id name		= [NSString stringWithUTF8String:ivar_getName(ivar)];
		id encoding	= [NSString stringWithUTF8String:ivar_getTypeEncoding(ivar)]; 
		id offset	= [NSNumber numberWithLong:ivar_getOffset(ivar)]; 
		id hash = [NSDictionary dictionaryWithObjectsAndKeys:
			name,		@"name",
			encoding,	@"encoding",
			offset,		@"offset",
			self,		@"class",
			nil];
			
		[array addObject:hash];
	}
	
	free(ivars);
	return	array;
}
- (id)__ownIvars
{
	return [[self class] __ownIvars];
}
+ (id)__ivars
{
	id classes	= [self __derivationPath];
	id ivars	= [NSMutableArray array];
	for (id class in classes)
		[ivars addObjectsFromArray:[class __ownIvars]];
	return	ivars;
}
- (id)__ivars
{
	return [[self class] __ivars];
}

//
// Properties
//
+ (id)__ownProperties
{
	unsigned int propertyCount;
	objc_property_t* properties = class_copyPropertyList(self, &propertyCount);
	
	id array = [NSMutableArray array];
	for (int i=0; i<propertyCount; i++)
	{
		objc_property_t property	= properties[i];
		
		id name			= [NSString stringWithUTF8String:property_getName(property)];
		id attributes	= [NSString stringWithUTF8String:property_getAttributes(property)]; 
		id hash = [NSDictionary dictionaryWithObjectsAndKeys:
			name,		@"name",
			attributes,	@"attributes",
			self,		@"class",
			nil];
		[array addObject:hash];
	}
	
	free(properties);
	return	array;
}
- (id)__ownProperties
{
	return [[self class] __ownProperties];
}
+ (id)__properties
{
	id classes		= [self __derivationPath];
	id properties	= [NSMutableArray array];
	for (id class in classes)
		[properties addObjectsFromArray:[class __ownProperties]];
	return	properties;
}
- (id)__properties
{
	return [[self class] __properties];
}

//
// Protocols
//
+ (id)__ownProtocols
{
	unsigned int protocolCount;
	Protocol** protocols = class_copyProtocolList(self, &protocolCount);
	
	id array = [NSMutableArray array];
	for (int i=0; i<protocolCount; i++)
	{
		id name = [NSString stringWithUTF8String:protocol_getName(protocols[i])];
		id hash = [NSDictionary dictionaryWithObjectsAndKeys:
			name,		@"name",
			self,		@"class",
			nil];
		[array addObject:hash];
	}
	
	free(protocols);
	return	array;
}
- (id)__ownProtocols
{
	return [[self class] __ownProtocols];
}

+ (id)__protocols
{
	id classes		= [self __derivationPath];
	id protocols	= [NSMutableArray array];
	for (id class in classes)
		[protocols addObjectsFromArray:[class __ownProtocols]];
	return	protocols;
}
- (id)__protocols
{
	return [[self class] __protocols];
}

@end
