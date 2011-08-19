//
//  JSCocoa.m
//  JSCocoa
//
//  Created by Patrick Geiller on 09/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//


#import "JSCocoaController.h"
#import "JSCocoaLib.h"

#pragma mark JS objects forward definitions

// Global object
static	JSValueRef	OSXObject_getProperty(JSContextRef, JSObjectRef, JSStringRef, JSValueRef*);
static	void		OSXObject_getPropertyNames(JSContextRef, JSObjectRef, JSPropertyNameAccumulatorRef);

// Private JS object callbacks
static	void		jsCocoaObject_initialize(JSContextRef, JSObjectRef);
static	void		jsCocoaObject_finalize(JSObjectRef);
static	JSValueRef	jsCocoaObject_callAsFunction(JSContextRef, JSObjectRef, JSObjectRef, size_t, const JSValueRef [], JSValueRef*);
//static	bool		jsCocoaObject_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
static	JSValueRef	jsCocoaObject_getProperty(JSContextRef, JSObjectRef, JSStringRef, JSValueRef*);
static	bool		jsCocoaObject_setProperty(JSContextRef, JSObjectRef, JSStringRef, JSValueRef, JSValueRef*);
static	bool		jsCocoaObject_deleteProperty(JSContextRef, JSObjectRef, JSStringRef, JSValueRef*);
static	void		jsCocoaObject_getPropertyNames(JSContextRef, JSObjectRef, JSPropertyNameAccumulatorRef);
static	JSObjectRef jsCocoaObject_callAsConstructor(JSContextRef, JSObjectRef, size_t, const JSValueRef [], JSValueRef*);
static	JSValueRef	jsCocoaObject_convertToType(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception);
static	bool		jsCocoaObject_hasInstance(JSContextRef ctx, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef* exception);

static	JSValueRef	jsCocoaInfo_getProperty(JSContextRef, JSObjectRef, JSStringRef, JSValueRef*);
static	void		jsCocoaInfo_getPropertyNames(JSContextRef, JSObjectRef, JSPropertyNameAccumulatorRef);

// Set on valueOf callback property of objects
#define	JSCocoaInternalAttribute kJSPropertyAttributeDontEnum

// These will be destroyed when the last JSCocoa instance dies
static	JSClassRef			OSXObjectClass		= NULL;
static	JSClassRef			jsCocoaObjectClass	= NULL;
static	JSClassRef			jsCocoaFunctionClass= NULL;
static	JSClassRef			jsCocoaInfoClass	= NULL;
static	JSClassRef			hashObjectClass		= NULL;

// Convenience method to throw a Javascript exception
static void throwException(JSContextRef ctx, JSValueRef* exception, NSString* reason);


// iPhone specifics
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
const JSClassDefinition kJSClassDefinitionEmpty = { 0, 0, 
													NULL, NULL, 
													NULL, NULL, 
													NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
#import "GDataDefines.h"
#import "GDataXMLNode.h"
#endif

// Appended to swizzled method names
#define OriginalMethodPrefix	@"original"
	
	





//
// JSCocoaController
//
#pragma mark -
#pragma mark JSCocoaController

@interface JSCocoaController (Private)
- (void) callDelegateForException:(JSValueRef)exception;
@end

@implementation JSCocoaController


// Instance properties
@synthesize delegate=_delegate;
@synthesize useSafeDealloc, useSplitCall, useJSLint, useAutoCall, callSelectorsMissingTrailingSemicolon, canSetOnBoxedObjects, logAllExceptions;

// Shared data

	// Given a jsFunction, retrieve its closure (jsFunction's pointer address is used as key)
	static	id	closureHash;
	// Given a jsFunction, retrieve its selector
	static	id	jsFunctionSelectors;
	// Given a jsFunction, retrieve which class it's attached to
	static	id	jsFunctionClasses;
	// Given a class, return the parent class implementing JSCocoaHolder method
	static	id	jsClassParents;
	// List of all ObjC classes written in Javascript
	static	id	jsClasses;
	
	// Given a class + methodName, retrieve its jsFunction
	static	id	jsFunctionHash;
	
	// Split call cache
	static	id	splitCallCache;

	// Shared instance stats
	static	id	sharedInstanceStats	= nil;
	
	// Boxed objects
//	static	id	boxedObjects;


	// Auto call zero arg methods : allow NSWorkspace.sharedWorkspace instead of NSWorkspace.sharedWorkspace()
//	static	BOOL	useAutoCall;
	// Allow calling obj.method(...) instead of obj.method_(...)
//	static	BOOL	callSelectorsMissingTrailingSemicolon;
	// Allows setting javascript values on boxed objects (which are collected after nulling all references to them)
//	static	BOOL	canSetOnBoxedObjects;
	
	// If true, all exceptions will be sent to NSLog, event if they're caught later on by some Javascript core
//	static	BOOL	logAllExceptions;
	// Is speaking when throwing exceptions
//	static	BOOL	isSpeaking;
	
	// Controller count
	static	int		controllerCount = 0;

	// Hash used to quickly check for variadic methods, Original, Super, toString, valueOf ...
	NSMutableDictionary*	customCallPaths;
	BOOL					customCallPathsCacheIsClean;
	
	// Javascript functions defined for ObjC classes are stored in this hash
	// __globalJSFunctionRepository__[className][propertyName]

//
// Init
//
- (id)initWithGlobalContext:(JSGlobalContextRef)_ctx
{
//	NSLog(@"JSCocoa : %p spawning with context %p", self, _ctx);
	self	= [super init];
	controllerCount++;

	useAutoCall			= YES;
	callSelectorsMissingTrailingSemicolon	= YES;
	canSetOnBoxedObjects= NO;
	logAllExceptions	= NO;
	boxedObjects		= [NSMutableDictionary new];

	@synchronized(self)
	{
		if (!sharedInstanceStats)	
		{
			sharedInstanceStats = [NSMutableDictionary new];
			closureHash			= [NSMutableDictionary new];
			jsFunctionSelectors	= [NSMutableDictionary new];
			jsFunctionClasses	= [NSMutableDictionary new];
			jsFunctionHash		= [NSMutableDictionary new];
			splitCallCache		= [NSMutableDictionary new];
			jsClassParents		= [NSMutableDictionary new];
//			boxedObjects		= [NSMutableDictionary new];
			jsClasses			= [NSMutableArray new];
			customCallPathsCacheIsClean = NO;
			customCallPaths	= nil;			
		}
	}

	//
	// Javascript classes with our callbacks
	//
	if (!OSXObjectClass) {
		//
		// OSX object javascript definition
		//
		JSClassDefinition OSXObjectDefinition		= kJSClassDefinitionEmpty;
		OSXObjectDefinition.className				= "OSX";
		OSXObjectDefinition.getProperty				= OSXObject_getProperty;
		OSXObjectDefinition.getPropertyNames		= OSXObject_getPropertyNames;
		OSXObjectClass								= JSClassCreate(&OSXObjectDefinition);


		//
		// Private object, used for holding references to objects, classes, structs
		//
		JSClassDefinition jsCocoaObjectDefinition	= kJSClassDefinitionEmpty;
		jsCocoaObjectDefinition.className			= "JSCocoa box";
		jsCocoaObjectDefinition.initialize			= jsCocoaObject_initialize;
		jsCocoaObjectDefinition.finalize			= jsCocoaObject_finalize;
//		jsCocoaObjectDefinition.hasProperty			= jsCocoaObject_hasProperty;
		jsCocoaObjectDefinition.getProperty			= jsCocoaObject_getProperty;
		jsCocoaObjectDefinition.setProperty			= jsCocoaObject_setProperty;
		jsCocoaObjectDefinition.deleteProperty		= jsCocoaObject_deleteProperty;
		jsCocoaObjectDefinition.getPropertyNames	= jsCocoaObject_getPropertyNames;
//		jsCocoaObjectDefinition.callAsFunction		= jsCocoaObject_callAsFunction;
		jsCocoaObjectDefinition.callAsConstructor	= jsCocoaObject_callAsConstructor;
//		jsCocoaObjectDefinition.hasInstance			= jsCocoaObject_hasInstance;
		jsCocoaObjectDefinition.convertToType		= jsCocoaObject_convertToType;
		jsCocoaObjectClass							= JSClassCreate(&jsCocoaObjectDefinition);


		//
		// Second kind of private object, used to hold method and function names
		//	Separated from the object because "typeof NSDate.date" gave "function" instead of object, preventing enumeration in WebKit inspector
		//
		JSClassDefinition jsCocoaFunctionDefinition	= kJSClassDefinitionEmpty;
		jsCocoaFunctionDefinition.className			= "JSCocoa box";
		jsCocoaFunctionDefinition.parentClass		= jsCocoaObjectClass;
		jsCocoaFunctionDefinition.callAsFunction	= jsCocoaObject_callAsFunction;
		jsCocoaFunctionClass						= JSClassCreate(&jsCocoaFunctionDefinition);
		

		//
		// Holds __info in objects
		//
		JSClassDefinition jsCocoaInfoDefinition		= kJSClassDefinitionEmpty;
		jsCocoaInfoDefinition.className				= "Runtime info";
		jsCocoaInfoDefinition.getProperty			= jsCocoaInfo_getProperty;
		jsCocoaInfoDefinition.getPropertyNames		= jsCocoaInfo_getPropertyNames;
		jsCocoaInfoClass							= JSClassCreate(&jsCocoaInfoDefinition);

		
		//
		// Private Hash of derived classes, storing js values
		//
		JSClassDefinition jsCocoaHashObjectDefinition	= kJSClassDefinitionEmpty;
		hashObjectClass									= JSClassCreate(&jsCocoaHashObjectDefinition);
	}
	
	//
	// Start context
	//
	
	// Starting from our own context
	if (!_ctx)
	{
		ctx = JSGlobalContextCreate(OSXObjectClass);
	}
	// Starting from an existing context
	else
	{
		ctx = _ctx;
		//JSGlobalContextRetain(ctx);
		JSObjectRef o = JSObjectMake(ctx, OSXObjectClass, NULL);
		// Set a global var named 'OSX' which will fulfill the usual role of JSCocoa's global object
		JSStringRef	jsName = JSStringCreateWithUTF8CString("OSX");
		JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), jsName, o, kJSPropertyAttributeDontDelete, NULL);
		JSStringRelease(jsName);
		
		[self accomodateWebKitInspector];
	}

#if !TARGET_IPHONE_SIMULATOR && !TARGET_OS_IPHONE
	[self loadFrameworkWithName:@"AppKit"];
	[self loadFrameworkWithName:@"CoreFoundation"];
	[self loadFrameworkWithName:@"Foundation"];
	[self loadFrameworkWithName:@"CoreGraphics" inPath:@"/System/Library/Frameworks/ApplicationServices.framework/Frameworks"];
#endif	

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
	[BurksPool setJSFunctionHash:jsFunctionHash];
#endif
	// Create a reference to ourselves, and make it read only, don't enum, don't delete
	[self setObjectNoRetain:self withName:@"__jsc__" attributes:kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontEnum|kJSPropertyAttributeDontDelete];

	// Load class kit
	if (!_ctx)
	{
		useJSLint		= NO;
		id lintPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"jslint-jscocoa" ofType:@"js"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:lintPath])	{
			BOOL b = [self evalJSFile:lintPath];
			if (!b)
				NSLog(@"[JSCocoa initWithGlobalContext:] JSLint not loaded");
		}
		id classKitPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"class" ofType:@"js"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:classKitPath])	[self evalJSFile:classKitPath];
	}

	// Objects can use their own dealloc, normally used up by JSCocoa
	// JSCocoa registers 'safeDealloc' in place of 'dealloc' and calls it in the next run loop cycle. 
	// (Dealloc might be called by JS GC, and running JS fails at this time)
	// useSafeDealloc will be turned to NO upon JSCocoaController dealloc
	useSafeDealloc	= YES;
	// Yep !
	useJSLint		= YES;
	// ObjJ syntax renders split call moot
	useSplitCall	= NO;
	ownsContext		= NO;

	[JSCocoa updateCustomCallPaths];
	return	self;
}

- (id)init
{
	id o = [self initWithGlobalContext:nil];
	ownsContext = YES;
	return	o;
}


//
// Dealloc
//
- (void)cleanUp
{
//	NSLog(@"JSCocoa : %p dying (ownsContext=%d)", self, ownsContext);
	[self setUseSafeDealloc:NO];

	// Cleanup if we created the JavascriptCore context.
	// If not, let user do it. In a WebView, this method will be called during JS GC,
	// and trying to execute more JS code will fail.
	// User must clean up manually by calling unlinkAllReferences then destroying the webView
	
	
	if (ownsContext) {
		[self unlinkAllReferences];
		JSGarbageCollect(ctx);
		[self setObjectNoRetain:self withName:@"__jsc__" attributes:kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontEnum|kJSPropertyAttributeDontDelete];
	}
    
	controllerCount--;
	if (controllerCount == 0)
	{
		if (OSXObjectClass) {
			JSClassRelease(OSXObjectClass);
			JSClassRelease(jsCocoaObjectClass);
			JSClassRelease(jsCocoaFunctionClass);
			JSClassRelease(jsCocoaInfoClass);
			JSClassRelease(hashObjectClass);
			OSXObjectClass = nil;
			jsCocoaObjectClass = nil;
			jsCocoaFunctionClass = nil;
			jsCocoaInfoClass = nil;
			hashObjectClass = nil;
		}
        
        // We need to nil these all out, since they are static
        // and if we make another JSCocoaController after this- they will
        // still be around and that's kinda bad (like crashing bad).
		[sharedInstanceStats release];
        sharedInstanceStats = nil;
		[closureHash release];
        closureHash = nil;
		[jsFunctionSelectors release];
        jsFunctionSelectors = nil;
		[jsFunctionClasses release];
        jsFunctionClasses = nil;
		[jsFunctionHash release];
        jsFunctionHash = nil;
		[splitCallCache release];
        splitCallCache = nil;
		[jsClassParents release];
        jsClassParents = nil;
//		[boxedObjects release];
//        boxedObjects = nil;
		[customCallPaths release];
		customCallPaths = nil;
		
		
		// Remove classes : go backwards to remove child classes first
		for (id class in [jsClasses reverseObjectEnumerator])
			objc_disposeClassPair([class pointerValue]);

		[jsClasses release];
		jsClasses = nil;
	}

	[self removeObjectWithName:@"__jsc__"];
	if (ownsContext)
		JSGlobalContextRelease(ctx);	

	[boxedObjects release];
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
// Shared instance
//
static id JSCocoaSingleton = NULL;

+ (id)sharedController
{
	@synchronized(self)
	{
		if (!JSCocoaSingleton)
		{
			// 1. alloc
			// 2. store pointer 
			// 3. call init
			//	
			//	Why ? if init is calling sharedController, the pointer won't have been set and it will call itself over and over again.
			//
			JSCocoaSingleton = [self alloc];
//			NSLog(@"JSCocoa : allocating shared instance %p", JSCocoaSingleton);
			[JSCocoaSingleton init];
		}
	}
	return	JSCocoaSingleton;
}
+ (BOOL)hasSharedController
{
	return	!!JSCocoaSingleton;
}

// Retrieves the __jsc__ variable from a context and unbox it
+ (id)controllerFromContext:(JSContextRef)ctx
{
	JSStringRef jsName = JSStringCreateWithUTF8CString("__jsc__");
	JSValueRef jsValue = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), jsName, NULL);
	JSStringRelease(jsName);
	id jsc = nil;
	[JSCocoaFFIArgument unboxJSValueRef:jsValue toObject:&jsc inContext:ctx];
	// Commented as it falsely reports failure when controller is cleaning up while being deallocated
//	if (!jsc)	NSLog(@"controllerFromContext couldn't find found the JSCocoaController in ctx %p", ctx);
	return	jsc;
}

// Report if we're running a nightly JavascriptCore, with GC
+ (void)hazardReport
{
	Dl_info info;
	// Get info about a JavascriptCore symbol
	dladdr(dlsym(RTLD_DEFAULT, "JSClassCreate"), &info);
	
	BOOL runningFromSystemLibrary = [[NSString stringWithUTF8String:info.dli_fname] hasPrefix:@"/System"];
	if (!runningFromSystemLibrary)	NSLog(@"***Running a nightly JavascriptCore***");
#if !TARGET_OS_IPHONE
	if ([NSGarbageCollector defaultCollector])	NSLog(@"***Running with ObjC Garbage Collection***");
#endif
}
// Report what we're running on
+ (NSString*)runningArchitecture
{
#if defined(__ppc__)
	return @"PPC";
// Unsupported
//#elif defined(__ppc64__)
//	return @"PPC64";
#elif defined(__i386__) 
	return @"i386";
#elif defined(__x86_64__) 
	return @"x86_64";
#elif TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
	return @"iPhone";
#elif TARGET_OS_IPHONE && TARGET_IPHONE_SIMULATOR
	return @"iPhone Simulator";
#else
	return @"unknown architecture";
#endif
}

// Replace the toString function with our own
- (void)accomodateWebKitInspector
{
	// The inspector uses Object's toString to extract the class name and print it,
	//	we replace that class name with valueOf when called for JSCocoa boxes
	char* script = "\
		var _old_toString = Object.prototype.toString		\n\
		Object.prototype.toString = function ()				\n\
		{													\n\
			var str = _old_toString.call(this)				\n\
			if (!str.match(/JSCocoa/))						\n\
				return str									\n\
			return '[Object ' + (this.valueOf()) + ']'		\n\
		}													\n\
															";
	JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)[NSString stringWithUTF8String:script]);
	JSEvaluateScript(ctx, scriptJS, NULL, NULL, 1, NULL);
	JSStringRelease(scriptJS);
}


#pragma mark Script evaluation

//
// Quick eval of strings and functions returning ObjC objects
//
- (id)eval:(NSString*)script			{	return [self toObject:[self evalJSString:script]];				}
- (id)callFunction:(NSString*)name		{	return [self toObject:[self callJSFunctionNamed:name withArgumentsArray:nil]];	}
- (id)callFunction:(NSString*)name withArguments:(NSArray*)arguments	{	return [self toObject:[self callJSFunctionNamed:name withArgumentsArray:arguments]];	}
- (BOOL)hasFunction:(NSString*)name		{	return [self hasJSFunctionNamed:name];	}

- (BOOL)isSyntaxValid:(NSString*)script	{	return [self isSyntaxValid:script error:nil];	}


//
// Eval of strings, functions, files, returning JavascriptCore objects
//
#pragma mark Script evaluation returning JavascriptCore objects

//
// Evaluate a file
// 
- (BOOL)evalJSFile:(NSString*)path toJSValueRef:(JSValueRef*)returnValue
{
	NSError*	error;
	id script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	// Skip .DS_Store and directories
	if (script == nil)	return	NSLog(@"evalJSFile could not open %@ (%@) — Check file encoding (should be UTF8) and file build phase (should be in \"Copy Bundle Resources\")", path, error), NO;
	
	//
	// Delegate canLoadJSFile
	//
	if (_delegate && [_delegate respondsToSelector:@selector(JSCocoa:canLoadJSFile:)] && ![_delegate JSCocoa:self canLoadJSFile:path])	return	NO;

	// Expand macros
	script = [self expandJSMacros:script path:path];
	if (!script) {
		NSLog(@"evalJSFile:toJSValueRef: expandJSMacros returned null on %@", path);
		return NO;
	}

	//
	// Delegate canEvaluateScript, willEvaluateScript
	//
	if (_delegate)
	{
		if ([_delegate respondsToSelector:@selector(JSCocoa:canEvaluateScript:)] && ![_delegate JSCocoa:self canEvaluateScript:script])	return	NO;
		if ([_delegate respondsToSelector:@selector(JSCocoa:willEvaluateScript:)])	script = [_delegate JSCocoa:self willEvaluateScript:script];
	}
	
	if (!customCallPathsCacheIsClean)	[JSCocoa updateCustomCallPaths];
	
	// Convert script and script URL to js strings
	// JSStringRef scriptJS		= JSStringCreateWithUTF8CString([script UTF8String]);
	// Using CreateWithUTF8 yields wrong results on PPC
	JSStringRef scriptJS	= JSStringCreateWithCFString((CFStringRef)script);
	JSStringRef scriptPath	= JSStringCreateWithUTF8CString([path UTF8String]);
    
	// Eval !
	JSValueRef	exception = NULL;
	JSValueRef result = JSEvaluateScript(ctx, scriptJS, NULL, scriptPath, 1, &exception);
	if (returnValue)	*returnValue = result;
	// Release
	JSStringRelease(scriptPath);
	JSStringRelease(scriptJS);
	if (exception) 
	{
//		NSLog(@"JSException - %@", [self formatJSException:exception]);
        [self callDelegateForException:exception];
		return	NO;
	}
	return	YES;
}


//
// Evaluate a file, without caring about return result
// 
- (BOOL)evalJSFile:(NSString*)path
{
	return	[self evalJSFile:path toJSValueRef:nil];
}

//
// Evaluate a string
// 
- (JSValueRef)evalJSString:(NSString*)script withScriptPath:(NSString*)path
{
	if (!script)	return	NULL;

	// Expand macros
	id expandedScript = [self expandJSMacros:script path:path];
	if (expandedScript)
		script = expandedScript;
	
	//
	// Delegate canEvaluateScript, willEvaluateScript
	//
	if (_delegate)
	{
		if ([_delegate respondsToSelector:@selector(JSCocoa:canEvaluateScript:)] && ![_delegate JSCocoa:self canEvaluateScript:script])	return	NULL;
		if ([_delegate respondsToSelector:@selector(JSCocoa:willEvaluateScript:)])	script = [_delegate JSCocoa:self willEvaluateScript:script];
	}
	
	if (!script)
		return NSLog(@"evalJSString has nothing to eval"), NULL;	

	if (!customCallPathsCacheIsClean)	[JSCocoa updateCustomCallPaths];
	
	JSStringRef		scriptJS	= JSStringCreateWithCFString((CFStringRef)script);
	JSValueRef		exception	= NULL;
	JSStringRef		scriptPath = path ? JSStringCreateWithUTF8CString([path UTF8String]) : NULL;
	JSValueRef		result = JSEvaluateScript(ctx, scriptJS, NULL, scriptPath, 1, &exception);
	JSStringRelease(scriptJS);
	if (path)		JSStringRelease(scriptPath);

	if (exception) 
	{
        [self callDelegateForException:exception];
		return	NULL;
	}

	return	result;
}

// Evaluate a string, no script path
- (JSValueRef)evalJSString:(NSString*)script
{
	return [self evalJSString:script withScriptPath:nil];
}



//
// Call a Javascript function by function reference (JSValueRef)
// 
- (JSValueRef)callJSFunction:(JSValueRef)function withArguments:(NSArray*)arguments
{
	JSObjectRef	jsFunction = JSValueToObject(ctx, function, NULL);
	// Return if function is not of function type
	if (!jsFunction)			return	NSLog(@"callJSFunction : value is not a function"), NULL;

	// Convert arguments
	JSValueRef* jsArguments = NULL;
	NSUInteger	argumentCount = [arguments count];
	if (argumentCount)
	{
		jsArguments = malloc(sizeof(JSValueRef)*argumentCount);
		for (int i=0; i<argumentCount; i++)
		{
			char typeEncoding = _C_ID;
			id argument = [arguments objectAtIndex:i];
			[JSCocoaFFIArgument toJSValueRef:&jsArguments[i] inContext:ctx typeEncoding:typeEncoding fullTypeEncoding:NULL fromStorage:&argument];
		}
	}

	if (!customCallPathsCacheIsClean)	[JSCocoa updateCustomCallPaths];

	JSValueRef exception = NULL;
	JSValueRef returnValue = JSObjectCallAsFunction(ctx, jsFunction, NULL, argumentCount, jsArguments, &exception);
	if (jsArguments) free(jsArguments);

	if (exception) 
	{
//		NSLog(@"JSException in callJSFunction : %@", [self formatJSException:exception]);
        [self callDelegateForException:exception];
		return	NULL;
	}

	return	returnValue;
}

//
// Call a Javascript function by name
//	Arguments require nil termination : [[JSCocoa sharedController] callJSFunctionNamed:@"myFunction" withArguments:arg1, arg2, nil]
// 
- (JSValueRef)callJSFunctionNamed:(NSString*)name withArguments:(id)firstArg, ... 
{
	// Convert args to array
	id arg, arguments = [NSMutableArray array];
	if (firstArg)	[arguments addObject:firstArg];

	if (firstArg)
	{
		va_list	args;
		va_start(args, firstArg);
		while ((arg = va_arg(args, id)))	
			[arguments addObject:arg];
		va_end(args);
	}

	// Get global object
	JSObjectRef globalObject	= JSContextGetGlobalObject(ctx);
	JSValueRef exception		= NULL;
	
	// Get function as property of global object
	JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
	JSValueRef jsFunctionValue = JSObjectGetProperty(ctx, globalObject, jsFunctionName, &exception);
	JSStringRelease(jsFunctionName);
	if (exception)				
	{
//		return	NSLog(@"%@", [self formatJSException:exception]), NULL;
        [self callDelegateForException:exception];
		return	NULL;
	}
	
	// Return if function is not of function type
	JSObjectRef	jsFunction = JSValueToObject(ctx, jsFunctionValue, NULL);
	if (!jsFunction)			return	NSLog(@"callJSFunctionNamed : %@ is not a function", name), NULL;
	// Call !
	return	[self callJSFunction:jsFunction withArguments:arguments];
}

//
// Call a Javascript function by name
//	Arguments must be in an NSArray : [[JSCocoa sharedController] callJSFunctionNamed:@"myFunction" withArgumentsArray:[NSArray array...]]
//
- (JSValueRef)callJSFunctionNamed:(NSString*)name withArgumentsArray:(NSArray*)arguments
{
	JSObjectRef jsFunction = [self JSFunctionNamed:name];
	if (!jsFunction)	return	NSLog(@"callJSFunctionNamed found no function %@", name), NULL;
	return	[self callJSFunction:jsFunction withArguments:arguments];
}

//
// Get a function by name, check if a function exists by name
//
- (JSObjectRef)JSFunctionNamed:(NSString*)name
{
	JSValueRef exception		= NULL;
	// Get function as property of global object
	JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
	JSValueRef jsFunctionValue = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), jsFunctionName, &exception);
	JSStringRelease(jsFunctionName);
	if (exception)				
	{
//		return	NSLog(@"%@", [self formatJSException:exception]), NO;
        [self callDelegateForException:exception];
		return	NO;
	}
	
	return	JSValueToObject(ctx, jsFunctionValue, NULL);	
}

- (BOOL)hasJSFunctionNamed:(NSString*)name
{
	return	!![self JSFunctionNamed:name];
}

//
// Expand macros
//
- (NSString*)expandJSMacros:(NSString*)script path:(NSString*)path errors:(NSMutableArray*)array
{
	// Normal path, with macro expansion for class definitions
	// OR
	// Lintex path
	id functionName = @"expandJSMacros";
	// Expand macros
	BOOL hasFunction = [self hasJSFunctionNamed:functionName];
	if (hasFunction && useJSLint)
	{
		JSValueRef v = [self callJSFunctionNamed:functionName withArguments:script, path?path:@"null", array, nil];
		id expandedScript = [self unboxJSValueRef:v];
		// Bail if expansion failed
		if (!expandedScript || ![expandedScript isKindOfClass:[NSString class]])	
			return NSLog(@"%@ expansion failed on script %@ (%@) ", functionName, script, path), NULL;

		script = expandedScript;
	}
	return	script;
}
- (NSString*)expandJSMacros:(NSString*)script path:(NSString*)path
{
	return [self expandJSMacros:script path:path errors:nil];
}

//
// Syntax validation
//
- (BOOL)isSyntaxValid:(NSString*)script error:(NSString**)outError
{
	id errors = [NSMutableArray array];
	script = [self expandJSMacros:script path:nil errors:errors];
	if (!script) {
		NSLog(@"isSyntaxValid: expandJSMacros returned null on %@", script);
		return NO;
	}

	JSStringRef scriptJS	= JSStringCreateWithUTF8CString([script UTF8String]);
	JSValueRef	exception	= NULL;
	BOOL b = JSCheckScriptSyntax(ctx, scriptJS, scriptJS, 1, &exception);
	JSStringRelease(scriptJS);
	
	if (exception)
	{
		NSMutableArray* errorList = [NSMutableArray array];
		NSString* str = [self formatJSException:exception];
		[errorList addObject:str];
		for (id error in errors)
		{
			[errorList addObject:[error valueForKey:@"error"]];
			if ([error valueForKey:@"line"])		[errorList addObject:[error valueForKey:@"line"]];
			if ([error valueForKey:@"position"])	[errorList addObject:[error valueForKey:@"position"]];
		}
		if (outError)
			*outError = [errorList componentsJoinedByString:@"\n"];
	}
	
	return b;
}



//
// Unbox a JSValueRef
//
- (id)unboxJSValueRef:(JSValueRef)value
{
	id object = nil;
	[JSCocoaFFIArgument unboxJSValueRef:value toObject:&object inContext:ctx];
	return object;
}

//
// Conversion boolean / number / string
//
- (BOOL)toBool:(JSValueRef)value
{
	if (!value)	return false;
	return JSValueToBoolean(ctx, value);
}

- (double)toDouble:(JSValueRef)value
{
	if (!value)	return 0;
	return JSValueToNumber(ctx, value, NULL);
}

- (int)toInt:(JSValueRef)value
{
	if (!value)	return 0;
	return (int)JSValueToNumber(ctx, value, NULL);
}

- (NSString*)toString:(JSValueRef)value
{
	if (!value)	return nil;
	JSStringRef resultStringJS = JSValueToStringCopy(ctx, value, NULL);
	NSString* resultString = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
	JSStringRelease(resultStringJS);
	[NSMakeCollectable(resultString) autorelease];
	return	resultString;
}

- (id)toObject:(JSValueRef)value
{
	return [self unboxJSValueRef:value];
}



//
// Add/Remove an ObjC object variable to the global context
//
- (BOOL)setObject:(id)object withName:(NSString*)name attributes:(JSPropertyAttributes)attributes {
	JSObjectRef o			= [self boxObject:object];
	// Set
	JSValueRef exception	= NULL;
	JSStringRef	jsName		= JSStringCreateWithUTF8CString([name UTF8String]);
	JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), jsName, o, attributes, &exception);
	JSStringRelease(jsName);

	if (exception) {
        [self callDelegateForException:exception];
		return	NO;
	}
	return	YES;
}

- (BOOL)setObject:(id)object withName:(NSString*)name {
	return [self setObject:object withName:name attributes:kJSPropertyAttributeNone];
}

- (BOOL)setObjectNoRetain:(id)object withName:(NSString*)name attributes:(JSPropertyAttributes)attributes {
	if (![self setObject:self withName:name attributes:attributes])
		return NO;
	// Get reference back and set it to no retain
	JSValueRef jsSelf = [self evalJSString:name];
	JSCocoaPrivateObject* private = JSObjectGetPrivate(JSValueToObject(ctx, jsSelf, NULL));
	// Overwrite settings
	[private setObjectNoRetain:self];
	// And discard private's retain
	[self release];
	
	return YES;
}

- (id)objectWithName:(NSString*)name {
	JSValueRef jsSelf = [self evalJSString:name];
	return [self toObject:jsSelf];
}


- (BOOL)removeObjectWithName:(NSString*)name
{
	JSValueRef	exception = NULL;
	// Delete
	JSStringRef	jsName = JSStringCreateWithUTF8CString([name UTF8String]);
	JSObjectDeleteProperty(ctx, JSContextGetGlobalObject(ctx), jsName, &exception);
	JSStringRelease(jsName);

	if (exception)	
	{
        [self callDelegateForException:exception];
		return	NO;
	}

	return	YES;
}

//
//
#pragma mark Loading Frameworks
//
//
- (BOOL)loadFrameworkWithName:(NSString*)name
{
	// Only check /System/Library/Frameworks for now
	return	[self loadFrameworkWithName:name inPath:@"/System/Library/Frameworks"];
}

//
// Load framework
//	even if framework has no bridgeSupport, load it anyway - it could contain ObjC classes
//
- (BOOL)loadFrameworkWithName:(NSString*)name inPath:(NSString*)inPath
{
	id path = [NSString stringWithFormat:@"%@/%@.framework/Resources/BridgeSupport/%@.bridgesupport", inPath, name, name];

	// Return YES if already loaded
	if ([[BridgeSupportController sharedController] isBridgeSupportLoaded:path])	return	YES;

	// Load framework
	id libPath = [NSString stringWithFormat:@"%@/%@.framework/%@", inPath, name, name];
	void* address = dlopen([libPath UTF8String], RTLD_LAZY);
	if (!address)	return	NSLog(@"Could not load framework dylib %@", libPath), NO;

	// Try loading .bridgesupport file
	if (![[BridgeSupportController sharedController] loadBridgeSupport:path])	return	NSLog(@"Could not load framework bridgesupport %@", path), NO;

	// Try loading extra dylib (inline functions made callable and compiled to a .dylib)
	id extraLibPath = [NSString stringWithFormat:@"%@/%@.framework/Resources/BridgeSupport/%@.dylib", inPath, name, name];
	/*address = */dlopen([extraLibPath UTF8String], RTLD_LAZY);
	// Don't fail if we didn't load the extra dylib as it is optional
//	if (!address)	return	NSLog(@"Did not load extra framework dylib %@", path), NO;

	customCallPathsCacheIsClean = NO;
	
	return	YES;
}

+ (void)updateCustomCallPaths
{
	if (customCallPaths)	[customCallPaths release];
	customCallPaths = [NSMutableDictionary new];
	
	[customCallPaths addEntriesFromDictionary:[[BridgeSupportController sharedController] variadicFunctions]];
	[customCallPaths addEntriesFromDictionary:[[BridgeSupportController sharedController] variadicSelectors]];

	[customCallPaths setObject:@"true" forKey:@"Original"];
	[customCallPaths setObject:@"true" forKey:@"Super"];
	[customCallPaths setObject:@"true" forKey:@"toString"];
	[customCallPaths setObject:@"true" forKey:@"valueOf"];
	
	customCallPathsCacheIsClean = YES;
}


# pragma mark Unsorted methods
+ (void)log:(NSString*)string
{
	NSLog(@"%@", string);
}
- (void)log:(NSString*)string
{
	NSLog(@"%@", string);
}
/*
- (id)system:(NSString*)string
{
	system([string UTF8String]);
	return	nil;
}
*/
/*
+ (void)logAndSay:(NSString*)string
{
	[self log:string];
	if (isSpeaking)	system([[NSString stringWithFormat:@"say %@ &", string] UTF8String]);
}
*/
- (JSObjectRef)newPrivateObject {
	JSCocoaPrivateObject* private = [[JSCocoaPrivateObject alloc] init];
	[private setCtx:ctx];
#ifdef __OBJC_GC__
	// Mark internal object as non collectable
	[[NSGarbageCollector defaultCollector] disableCollectorForPointer:private];
#endif
	JSObjectRef o = JSObjectMake(ctx, jsCocoaObjectClass, private);
	// Object is retained by jsCocoaObject_initialize, release it to make 'private' sole owner
	[private release];
	return	o;
}
- (JSObjectRef)newPrivateFunction {
	JSCocoaPrivateObject* private = [[JSCocoaPrivateObject alloc] init];
	[private setCtx:ctx];
#ifdef __OBJC_GC__
	// Mark internal object as non collectable
	[[NSGarbageCollector defaultCollector] disableCollectorForPointer:private];
#endif
	JSObjectRef o = JSObjectMake(ctx, jsCocoaFunctionClass, private);
	// Object is retained by jsCocoaObject_initialize, release it to make 'private' sole owner
	[private release];
	return	o;
}
/*
+ (JSObjectRef)jsCocoaPrivateObjectInContext:(JSContextRef)ctx {
	JSCocoaPrivateObject* private = [[JSCocoaPrivateObject alloc] init];
	[private setCtx:
#ifdef __OBJC_GC__
	// Mark internal object as non collectable
	[[NSGarbageCollector defaultCollector] disableCollectorForPointer:private];
#endif
	JSObjectRef o = JSObjectMake(ctx, jsCocoaObjectClass, private);
	[private release];
	return	o;
}
+ (JSObjectRef)jsCocoaPrivateFunctionInContext:(JSContextRef)ctx {
	JSCocoaPrivateObject* private = [[JSCocoaPrivateObject alloc] init];
#ifdef __OBJC_GC__
	// Mark internal object as non collectable
	[[NSGarbageCollector defaultCollector] disableCollectorForPointer:private];
#endif
	JSObjectRef o = JSObjectMake(ctx, jsCocoaFunctionClass, private);
	// Object is retained by jsCocoaObject_initialize, release it to make 'private' sole owner
	[private release];
	return	o;
}
*/
/*
- (BOOL)useAutoCall
{
	return	useAutoCall;
}
- (void)setUseAutoCall:(BOOL)b
{
	useAutoCall = b;
}

- (BOOL)callSelectorsMissingTrailingSemicolon
{
	return	callSelectorsMissingTrailingSemicolon;
}
- (void)setCallSelectorsMissingTrailingSemicolon:(BOOL)b
{
	callSelectorsMissingTrailingSemicolon = b;
}
*/
/*
- (BOOL)canSetOnBoxedObjects
{
	return	canSetOnBoxedObjects;
}
- (void)setCanSetOnBoxedObjects:(BOOL)b
{
	canSetOnBoxedObjects = b;
}
*/

- (JSGlobalContextRef)ctx
{
	return	ctx;
}

- (id)instanceStats
{
	return	sharedInstanceStats;
}

/*
//
// On auto calling 'instance' (eg NSString.instance), call is not done on property get (unlike NSWorkspace.sharedWorkspace)
// Instancing can't happen on get as instance may have parameters. 
// Instancing will therefore be delayed and must happen
//	* in fromJSValueRef
//	* in property get (NSString.instance.count, getting 'count')
//	* in valueOf (handled automatically as JavascriptCore will request 'valueOf' through property get)
//
+ (void)ensureJSValueIsObjectAfterInstanceAutocall:(JSValueRef)jsValue inContext:(JSContextRef)ctx
{
	NSLog(@"***For zero arg instance, use obj.instance() instead of obj.instance***");
}
*/

//
// Method signature helper
//
+ (const char*)typeEncodingOfMethod:(NSString*)methodName class:(NSString*)className
{
	id class = objc_getClass([className UTF8String]);
	if (!class)	return	nil;
	
	Method m = class_getClassMethod(class, NSSelectorFromString(methodName));
	if (!m)		m = class_getInstanceMethod(class, NSSelectorFromString(methodName));
	if (!m)		return	nil;
	
	return	method_getTypeEncoding(m);	
}
- (const char*)typeEncodingOfMethod:(NSString*)methodName class:(NSString*)className
{
	return [JSCocoa typeEncodingOfMethod:methodName class:className];
}


+ (id)parentObjCClassOfClassName:(NSString*)className
{
	return	[jsClassParents objectForKey:className];
}

//
//
#pragma mark Common encoding parsing
//
//
// This is parsed from method_getTypeEncoding
//	Later : Use method_copyArgumentType ?
+ (NSMutableArray*)parseObjCMethodEncoding:(const char*)typeEncoding
{
	id argumentEncodings = [NSMutableArray array];
	char* argsParser = (char*)typeEncoding;
	for(; *argsParser; argsParser++)
	{
		// Skip ObjC argument order
		if (*argsParser >= '0' && *argsParser <= '9')	continue;
		else
		// Skip ObjC 'const', 'oneway' markers
		if (*argsParser == 'r' || *argsParser == 'V')	continue;
		else
		if (*argsParser == '{')
		{
			// Parse structure encoding
			NSInteger count = 0;
			[JSCocoaFFIArgument typeEncodingsFromStructureTypeEncoding:[NSString stringWithUTF8String:argsParser] parsedCount:&count];

			id encoding = [[NSString alloc] initWithBytes:argsParser length:count encoding:NSUTF8StringEncoding];
			id argumentEncoding = [[JSCocoaFFIArgument alloc] init];
			// Set return value
			if ([argumentEncodings count] == 0)	[argumentEncoding setIsReturnValue:YES];
			[argumentEncoding setStructureTypeEncoding:encoding];
			[argumentEncodings addObject:argumentEncoding];
			[argumentEncoding release];

			[encoding release];
			argsParser += count-1;
		}
		else
		{
			// Custom handling for pointers as they're not one char long.
//			char type = *argsParser;
			char* typeStart = argsParser;
			if (*argsParser == '^')
				while (*argsParser && !(*argsParser >= '0' && *argsParser <= '9'))	argsParser++;

			id argumentEncoding = [[JSCocoaFFIArgument alloc] init];
			// Set return value
			if ([argumentEncodings count] == 0)	[argumentEncoding setIsReturnValue:YES];
			
			// If pointer, copy pointer type (^i, ^{NSRect}) to the argumentEncoding
			if (*typeStart == '^')
			{
				id encoding = [[NSString alloc] initWithBytes:typeStart length:argsParser-typeStart encoding:NSUTF8StringEncoding];
				[argumentEncoding setPointerTypeEncoding:encoding];
				[encoding release];
			}
			else
			{
				BOOL didSet = [argumentEncoding setTypeEncoding:*typeStart];
				if (!didSet)
				{
					[argumentEncoding release];
					return	nil;
				}
				// Blocks are '@?', skip '?'
				if (typeStart[0] == _C_ID && typeStart[1] == _C_UNDEF)
					argsParser++;
			}
			
			[argumentEncodings addObject:argumentEncoding];
			[argumentEncoding release];
		}
		if (!*argsParser)	break;
	}
	return	argumentEncodings;
}

//
// This is parsed from BridgeSupport's xml
//
+ (NSMutableArray*)parseCFunctionEncoding:(NSString*)xml functionName:(NSString**)functionNamePlaceHolder
{
	id argumentEncodings = [NSMutableArray array];
	id xmlDocument = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:nil];
	[xmlDocument autorelease];

	id rootElement = [xmlDocument rootElement];
	*functionNamePlaceHolder = [[rootElement attributeForName:@"name"] stringValue];
	
	// Parse children and return value
	NSUInteger i, numChildren	= [rootElement childCount];
	id	returnValue		= NULL;
	for (i=0; i<numChildren; i++)
	{
		id child = [rootElement childAtIndex:i];
		if ([child kind] != NSXMLElementKind)	continue;
		
		BOOL	isReturnValue = [[child name] isEqualToString:@"retval"];
		if ([[child name] isEqualToString:@"arg"] || isReturnValue)
		{
#if __LP64__	
			id typeEncoding = [[child attributeForName:@"type64"] stringValue];
			if (!typeEncoding)	typeEncoding = [[child attributeForName:@"type"] stringValue];
#else
			id typeEncoding = [[child attributeForName:@"type"] stringValue];
#endif			
			char typeEncodingChar = [typeEncoding UTF8String][0];
		
			id argumentEncoding = [[JSCocoaFFIArgument alloc] init];
			// Set return value — NO, as return value might not be the first element. Use retval to decide.
//			if ([argumentEncodings count] == 0)		[argumentEncoding setIsReturnValue:YES];
					if (typeEncodingChar == '{')	[argumentEncoding setStructureTypeEncoding:typeEncoding];
			else	if (typeEncodingChar == '^')
			{
				// Special case for functions like CGColorSpaceCreateWithName
				if ([typeEncoding isEqualToString:@"^{__CFString=}"])	[argumentEncoding setTypeEncoding:_C_ID];
				else													[argumentEncoding setPointerTypeEncoding:typeEncoding];
			}
			else														
			{
				BOOL didSet = [argumentEncoding setTypeEncoding:typeEncodingChar];
				if (!didSet)
				{
					[argumentEncoding release];
					return	nil;
				}
			}

			// Add argument
			if (!isReturnValue)
			{
				[argumentEncodings addObject:argumentEncoding];
				[argumentEncoding release];
			}
			// Keep return value on the side
			else	
			{
				returnValue = argumentEncoding;
				[argumentEncoding setIsReturnValue:YES];
			}
		}
	}
	
	// If no return value was set, default to void
	if (!returnValue)
	{
		id argumentEncoding = [[JSCocoaFFIArgument alloc] init];
		// Set return value
		if ([argumentEncodings count] == 0)	[argumentEncoding setIsReturnValue:YES];
		[argumentEncoding setTypeEncoding:'v'];
		returnValue = argumentEncoding;
	}
	
	// Move return value to first position  
	[argumentEncodings insertObject:returnValue atIndex:0];
	[returnValue release];
	
	return argumentEncodings;
}



//
//
#pragma mark Class Creation
//
//
+ (Class)createClass:(char*)className parentClass:(char*)parentClass
{
	Class class = objc_getClass(className);
	if (class)	return class;
	// Return now if parent class does not exist
	if (!objc_getClass(parentClass))	return	nil;
	// Each new class gets room for a js hash storing data and some get / set methods
	class = objc_allocateClassPair(objc_getClass(parentClass), className, 0);
	// Only add on classes that don't have the js data
	BOOL hasHash = !!class_getInstanceVariable(objc_getClass(parentClass), "__jsHash");
	if (!hasHash)	
	{
		// Add hash and context
		class_addIvar(class, "__jsHash", sizeof(void*), log2(sizeof(void*)), "^");
		class_addIvar(class, "__jsCocoaController", sizeof(void*), log2(sizeof(void*)), "^");
	}
	// Finish creating class
	objc_registerClassPair(class);

	// After creating class, add js methods : custom dealloc, get / set
	id JSCocoaMethodHolderClass = objc_getClass("JSCocoaMethodHolder");
	Method deallocJS = class_getInstanceMethod(JSCocoaMethodHolderClass, @selector(deallocAndCleanupJS));
	IMP deallocJSImp = method_getImplementation(deallocJS);
	if (!hasHash)
	{
		// Alloc debug
		Method m = class_getClassMethod(JSCocoaMethodHolderClass, @selector(allocWithZone:));
		class_addMethod(objc_getMetaClass(className), @selector(allocWithZone:), method_getImplementation(m), method_getTypeEncoding(m));	

		m = class_getInstanceMethod(JSCocoaMethodHolderClass, @selector(copyWithZone:));
		class_addMethod(class, @selector(copyWithZone:), method_getImplementation(m), method_getTypeEncoding(m));

		// Add dealloc
		class_addMethod(class, @selector(dealloc), deallocJSImp, method_getTypeEncoding(deallocJS));
		
		// Add js hash get / set /delete
		m = class_getInstanceMethod(JSCocoaMethodHolderClass, @selector(setJSValue:forJSName:));
		class_addMethod(class, @selector(setJSValue:forJSName:), method_getImplementation(m), method_getTypeEncoding(m));

		m = class_getInstanceMethod(JSCocoaMethodHolderClass, @selector(JSValueForJSName:));
		class_addMethod(class, @selector(JSValueForJSName:), method_getImplementation(m), method_getTypeEncoding(m));

		m = class_getInstanceMethod(JSCocoaMethodHolderClass, @selector(deleteJSValueForJSName:));
		class_addMethod(class, @selector(deleteJSValueForJSName:), method_getImplementation(m), method_getTypeEncoding(m));		

#ifdef __OBJC_GC__
		// GC finalize
		m = class_getInstanceMethod(JSCocoaMethodHolderClass, @selector(finalize));
		class_addMethod(class, @selector(finalize), method_getImplementation(m), method_getTypeEncoding(m));	
#endif		
	}
	
	// Retrieve parent ObjC class - used for runtime super allocWithZone: and dealloc calls
	id c = class;
	IMP existingSetJSValueImp = class_getMethodImplementation(JSCocoaMethodHolderClass, @selector(setJSValue:forJSName:));
	while (c)
	{
		IMP imp = class_getMethodImplementation(c, @selector(setJSValue:forJSName:));
		if (imp != existingSetJSValueImp)	break;
		c = [c superclass];
	}
	[jsClassParents setObject:c forKey:[NSString stringWithUTF8String:className]];
	[jsClasses addObject:[NSValue valueWithPointer:class]];
	return	class;
}



+ (BOOL)overloadInstanceMethod:(NSString*)methodName class:(Class)class jsFunction:(JSValueRefAndContextRef)valueAndContext
{
	JSObjectRef jsObject = JSValueToObject(valueAndContext.ctx, valueAndContext.value, NULL);
	if (!jsObject)	return	NSLog(@"overloadInstanceMethod : function is not an object"), NO;
	
	SEL selector = NSSelectorFromString(methodName);
	Method m = class_getInstanceMethod(class, selector);
	if (!m)			return NSLog(@"overloadInstanceMethod : can't overload a method that does not exist - %@.%@", class, methodName), NO;
//	NSLog(@"overloading %@ (%s)", methodName, encoding);
	return	[self addInstanceMethod:methodName class:class jsFunction:valueAndContext encoding:(char*)method_getTypeEncoding(m)];
}

+ (BOOL)overloadClassMethod:(NSString*)methodName class:(Class)class jsFunction:(JSValueRefAndContextRef)valueAndContext
{
	JSObjectRef jsObject = JSValueToObject(valueAndContext.ctx, valueAndContext.value, NULL);
	if (!jsObject)	return	NSLog(@"overloadClassMethod : function is not an object"), NO;
	
	SEL selector = NSSelectorFromString(methodName);
	Method m = class_getClassMethod(class, selector);
	if (!m)			return NSLog(@"overloadClassMethod : can't overload a method that does not exist - %@.%@", class, methodName), NO;
//	NSLog(@"overloading class method %@ (%s)", methodName, encoding);
	return	[self addClassMethod:methodName class:class jsFunction:valueAndContext encoding:(char*)method_getTypeEncoding(m)];
}

/*

	Add a JS function as method on a Cocoa class

	Given a js function, and using its pointer as a key
		* register a unique key (class + methodName) in jsFunctionHash, used to delete existing closures when setting a new method
		* register its associated methodName in jsFunctionSelectors, its associated class in jsFunctionClasses
			used when calling super (this.Super(arguments)) to get methodName and className from a jsFunction

	The closure made from the jsFunction+its encoding is stored in closureHash.

*/
+ (BOOL)addMethod:(NSString*)methodName class:(Class)class jsFunction:(JSValueRefAndContextRef)valueAndContext encoding:(char*)encoding
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
	// For the iPhone, use a Burks Pool, storing pointer to implementations matching required type encodings
	id typeEncodings = [JSCocoaController parseObjCMethodEncoding:encoding];
	if (!typeEncodings)	return NSLog(@"addMethod : Invalid encoding %s for %@.%@", encoding, class, methodName), NO;

	SEL selector = NSSelectorFromString(methodName);
	IMP fn = [BurksPool IMPforTypeEncodings:typeEncodings];
	if (!fn)	return	NSLog(@"No BurksPool encoding found when adding %@.%@(%s)", class, methodName, encoding), NO;

	// First addMethod : use class_addMethod to set closure
	if (!class_addMethod(class, selector, fn, encoding))
	{
		// After that, we need to patch the method's implementation to set closure
		Method method = class_getInstanceMethod(class, selector);
		if (!method)	method = class_getClassMethod(class, selector);
		method_setImplementation(method, fn);
	}

	// Register js functions in hashes
	id jsc = [JSCocoaController controllerFromContext:valueAndContext.ctx];

	id keyForClassAndMethod	= [NSString stringWithFormat:@"%@ %@", class, methodName];
	id keyForFunction		= [NSString stringWithFormat:@"%p", valueAndContext.value];

	id privateObject = [[JSCocoaPrivateObject alloc] init];
	[privateObject setJSValueRef:valueAndContext.value ctx:[jsc ctx]];
	[jsFunctionHash setObject:privateObject forKey:keyForClassAndMethod];

	valueAndContext.ctx = [jsc ctx];
	[BurksPool addMethod:methodName class:class jsFunction:valueAndContext encodings:typeEncodings];
	
	[jsFunctionSelectors setObject:methodName forKey:keyForFunction];
	[jsFunctionClasses setObject:class forKey:keyForFunction];
	
	return	YES;
#else
	if (!encoding)	return	NSLog(@"addMethod called with null encoding"), NO;
	
	SEL selector = NSSelectorFromString(methodName);

	id keyForClassAndMethod	= [NSString stringWithFormat:@"%@ %@", class, methodName];
	id keyForFunction		= [NSString stringWithFormat:@"%p", valueAndContext.value];

	id existingMethodForJSFunction = [closureHash valueForKey:keyForFunction];
	if (existingMethodForJSFunction)
	{
		NSLog(@"jsFunction proposed for %@.%@ already registered", class, methodName);
		return	NO;
	}

//	NSLog(@"keyForFunction=%p for %@.%@", keyForFunction, class, methodName);
	
	id jsc = [JSCocoaController controllerFromContext:valueAndContext.ctx];
	JSContextRef ctx = [jsc ctx];
	id privateObject = [[JSCocoaPrivateObject alloc] init];
	[privateObject setJSValueRef:valueAndContext.value ctx:ctx];

	//	Remove previous method
	id existingPrivateObject = [jsFunctionHash objectForKey:keyForClassAndMethod];

	// Closure cleanup - dangerous as instances might still be around AND IF dealloc/release is overloaded
	if (existingPrivateObject)
	{
		id keyForExistingFunction = [NSString stringWithFormat:@"%p", [existingPrivateObject jsValueRef]];

		[closureHash			removeObjectForKey:keyForExistingFunction];
		[jsFunctionSelectors	removeObjectForKey:keyForExistingFunction];
		[jsFunctionClasses		removeObjectForKey:keyForExistingFunction];
		[jsFunctionHash			removeObjectForKey:keyForClassAndMethod];
	}
	
	[jsFunctionHash setObject:privateObject forKey:keyForClassAndMethod];
	[privateObject release];

	id closure = [[JSCocoaFFIClosure alloc] init];
	[closureHash setObject:closure forKey:keyForFunction];
	[closure release];

	// Make a FFI closure, a function pointer callable with the argument encodings we provide)
	id typeEncodings = [JSCocoaController parseObjCMethodEncoding:encoding];
	if (!typeEncodings)	return NSLog(@"addMethod : Invalid encoding %s for %@.%@", encoding, class, methodName), NO;
	IMP fn = [closure setJSFunction:valueAndContext.value inContext:ctx argumentEncodings:typeEncodings objC:YES];

	// If successful, set it as method
	if (fn)
	{
		// First addMethod : use class_addMethod to set closure
		class_replaceMethod(class, selector, fn, encoding);

		// Register selector for jsFunction 
		[jsFunctionSelectors setObject:methodName forKey:keyForFunction];
		[jsFunctionClasses setObject:class forKey:keyForFunction];
	}
	else
		return	NSLog(@"addMethod %@ on %@ FAILED : no functionPointer in closure", methodName, class), NO;

	return	YES;
#endif	
}


+ (BOOL)addInstanceMethod:(NSString*)methodName class:(Class)class jsFunction:(JSValueRefAndContextRef)valueAndContext encoding:(char*)encoding
{
	// Custom case for dealloc, renamed to safeDealloc and called in the next run loop cycle
	if ([methodName isEqualToString:@"dealloc"])
		methodName = @"safeDealloc";
		
	return [self addMethod:methodName class:class jsFunction:valueAndContext encoding:encoding];
}
+ (BOOL)addClassMethod:(NSString*)methodName class:(Class)class jsFunction:(JSValueRefAndContextRef)valueAndContext encoding:(char*)encoding
{
	return [self addMethod:methodName class:objc_getMetaClass(class_getName(class)) jsFunction:valueAndContext encoding:encoding];
}
//
// Swizzlers !
//
+ (BOOL)swizzleInstanceMethod:(NSString*)methodName class:(Class)class jsFunction:(JSValueRefAndContextRef)valueAndContext
{
	// Always add method to existing class to make sure we're swizzling this class' method and not the parent's.
	// Courtesy of Jonathan 'Wolf' Rentzsch's JRSwizzle http://github.com/rentzsch/jrswizzle/tree/master
	SEL origSel_				= NSSelectorFromString(methodName);
	Method origMethod			= class_getInstanceMethod(class, origSel_);
	if (!origMethod)			return	NSLog(@"Method does not exist in instance swizzle %@.%@", class, methodName), NO;

	// Prefix method name with "original"
	id originalMethodName		= [NSString stringWithFormat:@"%@%@", OriginalMethodPrefix, methodName];
	SEL altSel_					= NSSelectorFromString(originalMethodName);

	// If method is already swizzled, reswizzle it to reset the class. 
	// addMethod: will overwrite our first swizzled method, which is what we want.
	// ^NO — the swizzled method might have been deallocated, so just overwrite altSel's implementation with origSel's
	if ([class instancesRespondToSelector:altSel_])
		method_setImplementation(class_getInstanceMethod(class, altSel_), class_getMethodImplementation(class, origSel_));

	BOOL b = [self addMethod:originalMethodName class:class jsFunction:valueAndContext encoding:(char*)method_getTypeEncoding(origMethod)];
	if (!b)						return NO;

	class_addMethod(class, origSel_, class_getMethodImplementation(class, origSel_), method_getTypeEncoding(origMethod));
	method_exchangeImplementations(class_getInstanceMethod(class, origSel_), class_getInstanceMethod(class, altSel_));
	return	YES;
}
+ (BOOL)swizzleClassMethod:(NSString*)methodName class:(Class)class jsFunction:(JSValueRefAndContextRef)valueAndContext
{
	class = objc_getMetaClass(class_getName(class));

	// Always add method to existing class to make sure we're swizzling this class' method and not the parent's.
	// Courtesy of Jonathan 'Wolf' Rentzsch's JRSwizzle http://github.com/rentzsch/jrswizzle/tree/master
	SEL origSel_				= NSSelectorFromString(methodName);
	Method origMethod			= class_getClassMethod(class, origSel_);
	if (!origMethod)			return	NSLog(@"Method does not exist in class swizzle %@.%@", class, methodName), NO;

	// Prefix method name with "original"
	id originalMethodName		= [NSString stringWithFormat:@"%@%@", OriginalMethodPrefix, methodName];
	SEL altSel_					= NSSelectorFromString(originalMethodName);

	// If method is already swizzled, reswizzle it to reset the class. 
	// addMethod: will overwrite our first swizzled method, which is what we want.
	if ([class respondsToSelector:altSel_])	
		method_setImplementation(class_getClassMethod(class, altSel_), class_getMethodImplementation(class, origSel_));

	BOOL b = [self addMethod:originalMethodName class:class jsFunction:valueAndContext encoding:(char*)method_getTypeEncoding(origMethod)];
	if (!b)						return NO;

	class_addMethod(class, origSel_, class_getMethodImplementation(class, origSel_), method_getTypeEncoding(origMethod));
	method_exchangeImplementations(class_getClassMethod(class, origSel_), class_getClassMethod(class, altSel_));
	return	YES;
}


#pragma mark Split call

/*
	From a split call
		object.set( { value : 5, forKey : 'messageCount' } )

	Find the matching selector and set new values for methodName, argumentCount, arguments
		object.setValue_forKey_(5, 'messageCount')

	After calling, arguments NEED TO BE DEALLOCATED if they changed.
	-> introduced because under GC, NSData gets collected early.

*/
+ (BOOL)trySplitCall:(id*)_methodName class:(Class)class argumentCount:(size_t*)_argumentCount arguments:(JSValueRef**)_arguments ctx:(JSContextRef)c
{
	id methodName			= *_methodName;
	size_t argumentCount	= *_argumentCount;
	JSValueRef* arguments	= *_arguments;
	if (argumentCount != 1)	return	NO;

	// Get property array
	JSObjectRef o = JSValueToObject(c, arguments[0], NULL);
	if (!o)	return	NO;
	JSPropertyNameArrayRef jsNames = JSObjectCopyPropertyNames(c, o);
	
	// Convert js names to NSString names : { jsName1 : value1, jsName2 : value 2 } -> NSArray[name1, name2]
	id names = [NSMutableArray array];
	size_t i, nameCount = JSPropertyNameArrayGetCount(jsNames);
	// Length of target selector = length of method + length of each (argument + ':')
	NSUInteger targetSelectorLength = [methodName length];
	// Actual arguments
	JSValueRef*	actualArguments = malloc(sizeof(JSValueRef)*nameCount);
	for (i=0; i<nameCount; i++)
	{
		JSStringRef jsName = JSPropertyNameArrayGetNameAtIndex(jsNames, i);
		id name = (id)JSStringCopyCFString(kCFAllocatorDefault, jsName);
		id nameWithColon = [[NSString stringWithFormat:@"%@:", name] lowercaseString];
		targetSelectorLength += [nameWithColon length];
		[names addObject:nameWithColon];
		[NSMakeCollectable(name) release];
		
		// Get actual argument
		actualArguments[i] = JSObjectGetProperty(c, o, jsName, NULL);
		// NO ! We didn't create it, we don't release it
//		JSStringRelease(jsName);
	}
	JSPropertyNameArrayRelease(jsNames);

	// We'll save the matching selector in this key
	id key = [NSMutableString stringWithFormat:@"%@-%@", class, methodName];
	id sortedNames = [names sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	for (id n in sortedNames)	[key appendString:n];
	key = [key lowercaseString];
	
	// Check if this selector already has a match
	id existingSelector = [splitCallCache objectForKey:key];
	if (existingSelector)
	{
		*_methodName	= existingSelector;
		*_argumentCount	= nameCount;
		*_arguments		= actualArguments;
		return	YES;
	}
	
	
	// Search through every class level
	id lowerCaseMethodName = [methodName lowercaseString];
	while (class)
	{
		// Get method list
		unsigned int methodCount;
		Method* methods = class_copyMethodList(class, &methodCount);

		// Search each method of this level
		for (i=0; i<methodCount; i++)
		{
			Method m = methods[i];
			id name = [NSStringFromSelector(method_getName(m)) lowercaseString];
			// Is this selector's length the same as the one we're searching ?
			if ([name length] == targetSelectorLength)
			{
				char* s = (char*)[name UTF8String];
				const char* t = [lowerCaseMethodName UTF8String];
				size_t l = strlen(t);
				// Does the selector start with the method name ?
				if (strncmp(s, t, l) == 0)
				{
					s += l;
					// Go through arguments and check if they're part of the string
					NSInteger consumedLength = 0;
					for (id n in sortedNames)
					{
						if (strstr(s, [n UTF8String]))	consumedLength += [n length];
					}
					// We've found our selector if we've consumed every argument
					if (consumedLength == strlen(s))
					{
						id selector		= NSStringFromSelector(method_getName(m));
						*_methodName	= selector;
						*_argumentCount	= nameCount;
						*_arguments		= actualArguments;

						// Store in split call cache
						[splitCallCache setObject:selector forKey:key];

						free(methods);
						return	YES;
					}
				}
			}
		}
		
		free(methods);
		class = [class superclass];
	}
	free(actualArguments);
	return	NO;
}

/*
	Check if class has a method starting with 'start'
	If YES, it's potentially a split call : we'll return an object in getProperty
	If NO, we'll return NULL in getProperty

*/
+ (BOOL)isMaybeSplitCall:(NSString*)_start forClass:(id)class
{
	int i;
	id start = [_start lowercaseString];
	// Search through every class level
	while (class)
	{
		// Get method list
		unsigned int methodCount;
		Method* methods = class_copyMethodList(class, &methodCount);

		// Search each method of this level
		for (i=0; i<methodCount; i++)
		{
			Method m = methods[i];
			id name = [NSStringFromSelector(method_getName(m)) lowercaseString];
			if ([name hasPrefix:start])
			{
				free(methods);
				return	YES;
			}
		}
		
		free(methods);
		class = [class superclass];
	}
	return	NO;
}


#pragma mark Variadic call
- (BOOL)isMethodVariadic:(id)methodName class:(id)class
{
	// Go up the class tree until we find a variadic method or exhaust superclasses
	while (class)
	{
		id className = [class description];
		id xml = [[BridgeSupportController sharedController] queryName:className];
		// Go up if this class has no description
		if (!xml)	
		{
			class = [class superclass];
			continue;
		}

		// Get XML definition
		id error;
		// Clang will report a leak here, but NSXMLDocument auto releases itself if it fails loading
		id xmlDocument = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
		if (error)	return	NSLog(@"(isMethodVariadic:class:) malformed xml while getting method %@ of class %@ : %@", methodName, class, error), NO;
			
		// Query method
		id xpath = [NSString stringWithFormat:@"*[@selector=\"%@\" and @variadic=\"true\"]", methodName];
		id nodes = [[xmlDocument rootElement] nodesForXPath:xpath error:&error];
		if (error)	NSLog(@"isMethodVariadic:error: %@", error);

		// It's a variadic method if XPath returned one result
		BOOL	isVariadic = [nodes count] == 1;
		[xmlDocument release];
		if (isVariadic)	return YES;
		
		class = [class superclass];
	}
	return	NO;
}

- (BOOL)isFunctionVariadic:(id)functionName
{
	id xml = [[BridgeSupportController sharedController] queryName:functionName];

	// Get XML definition
	id error;
	id xmlDocument = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
	if (error)	return	NSLog(@"(isMethodVariadic:class:) malformed xml while getting function %@ : %@", functionName, error), NO;

	// Query method
	id xpath = @"//*[@variadic=\"true\"]";
	id nodes = [[xmlDocument rootElement] nodesForXPath:xpath error:&error];
	if (error)	NSLog(@"isMethodVariadic:error: %@", error);

	// It's a variadic method if XPath returned one result
	BOOL	isVariadic = [nodes count] == 1;
	[xmlDocument release];
	return	isVariadic;
}



#pragma mark Boxed object hash

//+ (JSObjectRef)boxedJSObject:(id)o inContext:(JSContextRef)ctx
- (JSObjectRef)boxObject:(id)o
{
//	NSLog(@"QUICK FIX : key is ctx+llx, AND ctx is always the global context");

	id key	= [NSString stringWithFormat:@"%p", o];
	id value= [boxedObjects valueForKey:key];
	
//	NSLog(@"boxing (in ctx %p) %@ (key %@)", ctx, o, key);
	// If object is boxed, up its usage count and return it
	if (value)
	{
//		NSLog(@"CACHE HIT %@", key);
//		NSLog(@"upusage %@ (rc=%d) %d", o, [o retainCount], [value usageCount]);
		return	[value jsObject];
	}

	// o --> (JS)JSObjectRef(o) --> (ObjC)BoxedJSObject(JSObjectRef(o)), 
	//								^stored in the boxedObjects hash to always return the same box for the same object

	//
	// Create a new ObjC box around the JSValueRef boxing the JSObject
	//
	// We are returning an ObjC object to Javascript.
	// That ObjC object is boxed in a Javascript object.
	// For all boxing requests of the same ObjC object, that Javascript object needs to be unique for object comparisons to work :
	//		NSApplication.sharedApplication == NSApplication.sharedApplication
	//		(JavascriptCore has no hook for object to object comparison, that's why objects need to be unique)
	// To guarantee unicity, we keep a cache of boxed objects. 
	// As boxed objects are JSObjectRef not derived from NSObject, we box them in an ObjC object.
	//

	// Box the ObjC object in a JSObjectRef
//	JSObjectRef jsObject = [JSCocoa jsCocoaPrivateObjectInContext:ctx];
	JSObjectRef jsObject = [self newPrivateObject];
	JSCocoaPrivateObject* private = JSObjectGetPrivate(jsObject);
	private.type = @"@";
	[private setObject:o];
	
	// Box the JSObjectRef in our ObjC object
	value = [[BoxedJSObject alloc] init];
	[value setJSObject:jsObject];

	// Add to dictionary and make it sole owner
	[boxedObjects setValue:value forKey:key];
	[value release];
	return	jsObject;
}

- (BOOL)isObjectBoxed:(id)o {
	id key	= [NSString stringWithFormat:@"%p", o];
	return !![boxedObjects valueForKey:key];
}

- (void)deleteBoxOfObject:(id)o {
	id key	= [NSString stringWithFormat:@"%p", o];
	id value= [boxedObjects valueForKey:key];
	if (!value)
		return;
	[boxedObjects removeObjectForKey:key];
}

/*
+ (void)downBoxedJSObjectCount:(id)o
{
	id key = [NSString stringWithFormat:@"%p", o];
	id value = [boxedObjects valueForKey:key];
	if (!value)
		return;

	[boxedObjects removeObjectForKey:key];
}

+ (id)boxedObjects
{
	return boxedObjects;
}
*/
#pragma mark Helpers
- (id)selectorForJSFunction:(JSObjectRef)function
{
	return [jsFunctionSelectors valueForKey:[NSString stringWithFormat:@"%p", function]];
}

- (id)classForJSFunction:(JSObjectRef)function
{
	return [jsFunctionClasses valueForKey:[NSString stringWithFormat:@"%p", function]];
}

//
//	Given an exception, get its line number, source URL, error message and return them in a NSString
//	When throwing an exception from Javascript, throw an object instead of a string. 
//	This way, JavascriptCore will add line and sourceURL.
//	(throw new String('error') instead of throw 'error')
//
+ (NSString*)formatJSException:(JSValueRef)exception inContext:(JSContextRef)context
{
	if (!exception)
		return @"formatJSException:(null)";
	// Convert exception to string
	JSStringRef resultStringJS = JSValueToStringCopy(context, exception, NULL);
	NSString* b = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
	JSStringRelease(resultStringJS);
	[NSMakeCollectable(b) autorelease];

	// Only objects contain line and source URL
	if (JSValueGetType(context, exception) != kJSTypeObject)	return	b;

	// Iterate over all properties of the exception
	JSObjectRef jsObject = JSValueToObject(context, exception, NULL);
	JSPropertyNameArrayRef jsNames = JSObjectCopyPropertyNames(context, jsObject);
	size_t i, nameCount = JSPropertyNameArrayGetCount(jsNames);
	id line = nil, sourceURL = nil;
	for (i=0; i<nameCount; i++)
	{
		JSStringRef jsName = JSPropertyNameArrayGetNameAtIndex(jsNames, i);
		id name = (id)JSStringCopyCFString(kCFAllocatorDefault, jsName);

		JSValueRef	jsValueRef = JSObjectGetProperty(context, jsObject, jsName, NULL);
		JSStringRef	valueJS = JSValueToStringCopy(context, jsValueRef, NULL);
		NSString* value = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, valueJS);
		JSStringRelease(valueJS);
		
		if ([name isEqualToString:@"line"])			line = value;
		if ([name isEqualToString:@"sourceURL"])	sourceURL = value;
		[NSMakeCollectable(name) release];
		// Autorelease because we assigned it to line / sourceURL
		[NSMakeCollectable(value) autorelease];
	}
	JSPropertyNameArrayRelease(jsNames);
	return [NSString stringWithFormat:@"%@ on line %@ of %@", b, line, sourceURL];
}

- (NSString*)formatJSException:(JSValueRef)exception
{
	return [JSCocoaController formatJSException:exception inContext:ctx];
}


//
// Error reporting
//
- (void)callDelegateForException:(JSValueRef)exception {
    if (!_delegate || ![_delegate respondsToSelector:@selector(JSCocoa:hadError:onLineNumber:atSourceURL:)]) {
		NSLog(@"JSException: %@", [self formatJSException:exception]);
        return;
    }
    
    JSStringRef resultStringJS = JSValueToStringCopy(ctx, exception, NULL);
	NSString* b = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
	JSStringRelease(resultStringJS);
	[NSMakeCollectable(b) autorelease];
    
	if (JSValueGetType(ctx, exception) != kJSTypeObject) {
        [_delegate JSCocoa:self hadError:b onLineNumber:0 atSourceURL:nil];
    }
    
	// Iterate over all properties of the exception
	JSObjectRef jsObject = JSValueToObject(ctx, exception, NULL);
	JSPropertyNameArrayRef jsNames = JSObjectCopyPropertyNames(ctx, jsObject);
	size_t i, nameCount = JSPropertyNameArrayGetCount(jsNames);
	id line = nil, sourceURL = nil;
	for (i=0; i<nameCount; i++)
	{
		JSStringRef jsName = JSPropertyNameArrayGetNameAtIndex(jsNames, i);
		id name = (id)JSStringCopyCFString(kCFAllocatorDefault, jsName);
        
		JSValueRef	jsValueRef = JSObjectGetProperty(ctx, jsObject, jsName, NULL);
		JSStringRef	valueJS = JSValueToStringCopy(ctx, jsValueRef, NULL);
		NSString* value = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, valueJS);
		JSStringRelease(valueJS);
		
		if ([name isEqualToString:@"line"])			line = value;
		if ([name isEqualToString:@"sourceURL"])	sourceURL = value;
		[NSMakeCollectable(name) release];
		// Autorelease because we assigned it to line / sourceURL
		[NSMakeCollectable(value) autorelease];
	}
	JSPropertyNameArrayRelease(jsNames);
    [_delegate JSCocoa:self hadError:b onLineNumber:[line intValue] atSourceURL:sourceURL];
}


//
//
#pragma mark Tests
//
// Tests stay here so that any app might run them, not just TestsRunner
//
- (int)runTests:(NSString*)path withSelector:(SEL)sel {
	int count = 0;
#if TARGET_OS_IPHONE
#elif TARGET_IPHONE_SIMULATOR
#else
	id files	= [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
	id predicate= [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] '.js'"];
	files		= [files filteredArrayUsingPredicate:predicate]; 
	if ([files count] == 0)
		return	[JSCocoaController log:@"no test files found"], 0;
	
	// Execute in test order, not finder order
	files		= [files sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
	for (id file in files) {
		id filePath	= [NSString stringWithFormat:@"%@/%@", path, file];
//		NSLog(@">>>evaling %@", filePath);
		
		id evaled	= nil;
		@try {
			evaled	= [self performSelector:sel withObject:filePath];
//			NSLog(@">>>EVALED %d, %@", evaled, filePath);
		} @catch (id e) {
			NSLog(@"(Test exception from %@) %@", file, e);
			evaled	= nil;
		}
		if (!evaled) {
			id error	= [NSString stringWithFormat:@"test %@ failed (Ran %d out of %d tests)", file, count+1, [files count]];
			[JSCocoaController log:error];
			return NO;
		}
		count ++;
		[self garbageCollect];
	}
#endif	
	return	count;
}
- (int)runTests:(NSString*)path {
	return [self runTests:path withSelector:@selector(evalJSFile:)];
}

#pragma mark Autorelease pool
static id autoreleasePool;
+ (void)allocAutoreleasePool {
	autoreleasePool = [[NSAutoreleasePool alloc] init];
}

+ (void)deallocAutoreleasePool {
	[autoreleasePool release];
}


#pragma mark Garbage Collection
//
// Collect on top of the run loop, not in some JS function
//
+ (void)garbageCollect	{	
	NSLog(@"*** Deprecated — call garbageCollect on an instance ***"); /*JSGarbageCollect(NULL);*/ 
}
- (void)garbageCollect	{	
	JSGarbageCollect(ctx); 
}

//
// Make all root Javascript variables point to null
//
- (void)unlinkAllReferences
{
	// Null and delete every reference to every live object
//	[self evalJSString:@"for (var i in this) { log('DELETE ' + i); this[i] = null; delete this[i]; }"];
//	[self evalJSString:@"for (var i in this) { this[i] = null; delete this[i]; }"];

//	id del = @"var keys = Object.keys(this); var c = keys.length; for (var i=0; i<c; i++) { try { this[keys[i]] = null } catch(e) {} }";
	id del = @"for (var i in this) { this[i] = null; delete this[i]; }";
	[self evalJSString:del];
	// Everything is now collectable !
}

//
// Custom dealloc code for objects will be executed here
//
- (void)safeDeallocInstance:(id)sender
{
	// This code might re-box the instance ...
	[sender safeDealloc];
	// So, clean it up
	[boxedObjects removeObjectForKey:[NSString stringWithFormat:@"%p", sender]];
	// sender is retained by performSelector, object will be destroyed upon function exit
}

#pragma mark Garbage Collection debug

// Boxing object, set as a Javascript object's private data
static int JSCocoaPrivateObjectCount = 0; 
+ (void)upJSCocoaPrivateObjectCount		{	JSCocoaPrivateObjectCount++;		}
+ (void)downJSCocoaPrivateObjectCount	{	JSCocoaPrivateObjectCount--;		}
+ (int)JSCocoaPrivateObjectCount		{	return	JSCocoaPrivateObjectCount;	}

// Javascript hash, set on classes created with JSCocoaController.createClass
// - used to store js values on instances ( someClassDerivedInJS['someValue'] = 'hello !' )
static int JSCocoaHashCount = 0; 
+ (void)upJSCocoaHashCount				{	JSCocoaHashCount++;					}
+ (void)downJSCocoaHashCount			{	JSCocoaHashCount--;					}
+ (int)JSCocoaHashCount					{	return	JSCocoaHashCount;			}


// Value protect
static int JSValueProtectCount = 0;
+ (void)upJSValueProtectCount			{	JSValueProtectCount++;				}
+ (void)downJSValueProtectCount			{	JSValueProtectCount--;				}
+ (int)JSValueProtectCount				{	return	JSValueProtectCount;		}

// Instance count
int	fullInstanceCount	= 0;
int	liveInstanceCount	= 0;
+ (void)upInstanceCount:(id)o
{
	fullInstanceCount++;
	liveInstanceCount++;

	id key = [NSMutableString stringWithFormat:@"%@", [o class]];
	
	id existingCount = [sharedInstanceStats objectForKey:key];
	int count = 0;
	if (existingCount)	count = [existingCount intValue];
	
	count++;
	[sharedInstanceStats setObject:[NSNumber numberWithInt:count] forKey:key];
}
+ (void)downInstanceCount:(id)o
{
	liveInstanceCount--;

	id key = [NSMutableString stringWithFormat:@"%@", [o class]];
	
	id existingCount = [sharedInstanceStats objectForKey:key];
	if (!existingCount)
	{
		NSLog(@"downInstanceCount on %@ without an up", o);
		return;
	}
	int count = [existingCount intValue];
	count--;
	
	if (count)	[sharedInstanceStats setObject:[NSNumber numberWithInt:count] forKey:key];
	else		[sharedInstanceStats removeObjectForKey:key];
}
+ (int)liveInstanceCount:(Class)c
{
	id key = [NSMutableString stringWithFormat:@"%@", c];
	
	id existingCount = [sharedInstanceStats objectForKey:key];
	if (!existingCount)	return	0;
	return	[existingCount intValue];
}
+ (id)liveInstanceHash
{
	return	sharedInstanceStats;
}


+ (void)logInstanceStats
{
	id allKeys = [sharedInstanceStats allKeys];
	NSLog(@"====instanceStats : %ld classes spawned %d instances since launch, %d dead, %d alive====", (long)[allKeys count], fullInstanceCount, fullInstanceCount-liveInstanceCount, liveInstanceCount);
	for (id key in allKeys)		
		NSLog(@"%@=%d", key, [[sharedInstanceStats objectForKey:key] intValue]);
	if ([allKeys count])	NSLog(@"====");
}

- (void)logBoxedObjects
{
	NSLog(@"====%ld boxedObjects====", (long)[[boxedObjects allKeys] count]);
	for (NSString* key in boxedObjects) {
		BoxedJSObject* box = [boxedObjects valueForKey:key];
		id o = [(JSCocoaPrivateObject*)JSObjectGetPrivate([box jsObject]) object];
		if ([o retainCount] == -1) {
			if ([o class] == o)
				NSLog(@"%p (class) %@", o, o);
			else
				NSLog(@"%p (%@) %@", o, [o class], o);
		} else {
			NSLog(@"%p (%@)", o, [o class]);
		}
		
/*
	id boxedObject = [(JSCocoaPrivateObject*)JSObjectGetPrivate(jsObject) object];
	id retainCount = [NSString stringWithFormat:@"%d", [boxedObject retainCount]];
#if !TARGET_OS_IPHONE
	retainCount = [NSGarbageCollector defaultCollector] ? @"Running GC" : [NSString stringWithFormat:@"%d", [boxedObject retainCount]];
#endif
	return [NSString stringWithFormat:@"<%@: %p holding %@ %@: %p (retainCount=%@)>",
				[self class], 
				self, 
				((id)self == (id)[self class]) ? @"Class" : @"",
				[boxedObject class],
				boxedObject,
				retainCount];
*/

	}
//	NSLog(@"%@", boxedObjects);
}

#pragma mark Class inspection
+ (id)rootclasses
{
	return [JSCocoaLib rootclasses];
}
+ (id)classes
{
	return [JSCocoaLib classes];
}
+ (id)protocols
{
	return [JSCocoaLib protocols];
}
+ (id)imageNames
{
	return [JSCocoaLib imageNames];
}
+ (id)methods
{
	return [JSCocoaLib methods];
}
+ (id)runtimeReport
{
	return [JSCocoaLib runtimeReport];
}
+ (id)explainMethodEncoding:(id)encoding
{
	id argumentEncodings	= [JSCocoaController parseObjCMethodEncoding:[encoding UTF8String]];
	id explication			= [NSMutableArray array];
	for (id arg in argumentEncodings)
		[explication addObject:[arg typeDescription]
		];
	
	return	explication;
}




// JSCocoa : handle setting with callMethod
//	object.width = 100
//	-> 
//	[object setWidth:100]
//
- (BOOL)JSCocoa:(JSCocoaController*)controller setProperty:(NSString*)propertyName ofObject:(id)object toValue:(JSValueRef)value inContext:(JSContextRef)localCtx exception:(JSValueRef*)exception
{
    // FIXME: this doesn't actually work with objc properties, and we can't always rely that this method will exist either...
    // it should probably be moved up into the JSCocoa layer.
    
	NSString*	setterName = [NSString stringWithFormat:@"set%@%@:", 
										[[propertyName substringWithRange:NSMakeRange(0,1)] capitalizedString], 
										[propertyName substringWithRange:NSMakeRange(1, [propertyName length]-1)]];
	
    if ([self JSCocoa:controller callMethod:setterName ofObject:object privateObject:nil argumentCount:1 arguments:&value inContext:localCtx exception:exception]) {
        return YES;
    }
	
    return	NO;
}
#pragma mark Distant Object Handling (DO)
//
// NSDistantObject call using NSInvocation
//
- (JSValueRef)JSCocoa:(JSCocoaController*)controller callMethod:(NSString*)methodName ofObject:(id)callee privateObject:(JSCocoaPrivateObject*)thisPrivateObject argumentCount:(size_t)argumentCount arguments:(JSValueRef*)arguments inContext:(JSContextRef)localCtx exception:(JSValueRef*)exception
{
    SEL selector = NSSelectorFromString(methodName);
	if (class_getInstanceMethod([callee class], selector) || class_getClassMethod([callee class], selector)) {
        return nil;
    }
    
    NSMethodSignature *signature = [callee methodSignatureForSelector:selector];
    
    if (!signature) {
        return nil;
    }
    
    // we need to do all this for NSDistantObject , since JSCocoa doesn't handle it natively.
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    NSUInteger argIndex = 0;
    while (argIndex < argumentCount) {
        
        id arg = 0x00;
        
        [JSCocoaFFIArgument unboxJSValueRef:arguments[argIndex] toObject:&arg inContext:localCtx];
        
        const char *type = [signature getArgumentTypeAtIndex:argIndex + 2];
		// Structure argument
		if (type && type[0] == '{')
		{
			id structureType = [NSString stringWithUTF8String:type];
			id fullStructureType = [JSCocoaFFIArgument structureFullTypeEncodingFromStructureTypeEncoding:structureType];
		
			int size = [JSCocoaFFIArgument sizeOfStructure:structureType];
			JSObjectRef jsObject = JSValueToObject(ctx, arguments[argIndex], NULL);
			if (size && fullStructureType && jsObject)
			{
				// Alloc structure size and let NSData deallocate it
				void* source = malloc(size);
				memset(source, 0, size);
				[NSData dataWithBytesNoCopy:source length:size freeWhenDone:YES];
				
				void* p = source;
				NSInteger numParsed =	[JSCocoaFFIArgument structureFromJSObjectRef:jsObject inContext:ctx inParentJSValueRef:NULL fromCString:(char*)[fullStructureType UTF8String] fromStorage:&p];
				if (numParsed)	[invocation setArgument:source atIndex:argIndex+2];
			}
		}
		else
        if ([arg isKindOfClass:[NSNumber class]]) {
            
//            const char *type = [signature getArgumentTypeAtIndex:argIndex + 2];
            if (strcmp(type, @encode(BOOL)) == 0) {
                BOOL b = [arg boolValue];
                [invocation setArgument:&b atIndex:argIndex + 2];
            }
            else if (strcmp(type, @encode(unsigned int)) == 0) {
                unsigned int i = [arg unsignedIntValue];
                [invocation setArgument:&i atIndex:argIndex + 2];
            }
            else if (strcmp(type, @encode(int)) == 0) {
                int i = [arg intValue];
                [invocation setArgument:&i atIndex:argIndex + 2];
            }
            else if (strcmp(type, @encode(unsigned long)) == 0) {
                unsigned long l = [arg unsignedLongValue];
                [invocation setArgument:&l atIndex:argIndex + 2];
            }
            else if (strcmp(type, @encode(long)) == 0) {
                long l = [arg longValue];
                [invocation setArgument:&l atIndex:argIndex + 2];
            }
            else if (strcmp(type, @encode(float)) == 0) {
                float f = [arg floatValue];
                [invocation setArgument:&f atIndex:argIndex + 2];
            }
            else if (strcmp(type, @encode(double)) == 0) {
                double d = [arg doubleValue];
                [invocation setArgument:&d atIndex:argIndex + 2];
            }
            else { // just do int for all else.
                int i = [arg intValue];
                [invocation setArgument:&i atIndex:argIndex + 2];
            }
            
        }
        else {
            [invocation setArgument:&arg atIndex:argIndex + 2];
        }
        
        argIndex++;
    }
    
    @try {
        [invocation invokeWithTarget:callee];
    }
    @catch (NSException * e) {
        NSLog(@"Exception while calling %@. %@", methodName, [e reason]);
        
        if ([[e reason] isEqualToString:@"connection went invalid while waiting for a reply"]) {
            // whoops?
            // also, how do we not look for some funky localized string here?
            // also also, can we now make whatever is pointing to this value, nil?
            
            if (thisPrivateObject) {
                NSLog(@"Connection terminated, removing reference to object");
                thisPrivateObject.object = [NSNull null];
                [thisPrivateObject setJSValueRef:JSValueMakeNull(localCtx) ctx:localCtx];
            }
        }
    }

    JSValueRef	jsReturnValue = NULL;
    const char *type = [signature methodReturnType];
    if (strcmp(type, @encode(id)) == 0 || strcmp(type, @encode(Class)) == 0) {
        id result = 0x00;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument boxObject:result toJSValueRef:&jsReturnValue inContext:localCtx];
    }
/*
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
*/	
    else if (strcmp(type, @encode(char)) == 0) {
        char result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(char)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(unsigned char)) == 0) {
        unsigned char result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(unsigned char)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(short)) == 0) {
        short result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(short)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(unsigned short)) == 0) {
        unsigned short result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(unsigned short)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(int)) == 0) {
        int result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(int)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(unsigned int)) == 0) {
        unsigned int result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(unsigned int)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(long)) == 0) {
        long result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(long)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(unsigned long)) == 0) {
        unsigned long result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(unsigned long)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(float)) == 0) {
        float result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(float)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
    else if (strcmp(type, @encode(double)) == 0) {
        double result;
        [invocation getReturnValue:&result];
		if (!result)		return JSValueMakeNull(localCtx);
        [JSCocoaFFIArgument toJSValueRef:&jsReturnValue inContext:localCtx typeEncoding:@encode(double)[0] fullTypeEncoding:NULL fromStorage:&result];
    }
	// Structure return
	else if (type && type[0] == '{')
	{
		id structureType = [NSString stringWithUTF8String:type];
		id fullStructureType = [JSCocoaFFIArgument structureFullTypeEncodingFromStructureTypeEncoding:structureType];
		
		int size = [JSCocoaFFIArgument sizeOfStructure:structureType];
		if (size)
		{
			void* result = malloc(size);
			[invocation getReturnValue:result];			

			// structureToJSValueRef will advance the pointer in place, overwriting its original value
			void* ptr = result;
			NSInteger numParsed =	[JSCocoaFFIArgument structureToJSValueRef:&jsReturnValue inContext:localCtx fromCString:(char*)[fullStructureType UTF8String] fromStorage:&ptr];
			if (!numParsed) jsReturnValue = NULL;
			free(result);
		}
	}
	if (!jsReturnValue)	return JSValueMakeNull(localCtx);
    return	jsReturnValue;
}

@end







#pragma mark Javascript setter functions
// Give ObjC classes written in Javascript extra abilities like storing extra javascript variables in an internal __jsHash.
//	The following methods handle that. JSCocoaMethodHolder is a dummy class to hold them.
@interface	JSCocoaMethodHolder : NSObject
@end
@implementation JSCocoaMethodHolder
- (BOOL)setJSValue:(JSValueRefAndContextRef)valueAndContext forJSName:(JSValueRefAndContextRef)nameAndContext
{
	if (class_getInstanceVariable([self class], "__jsHash"))
	{
		JSContextRef c = valueAndContext.ctx;
		JSStringRef name = JSValueToStringCopy(c, nameAndContext.value, NULL);

		JSObjectRef hash = NULL;
		object_getInstanceVariable(self, "__jsHash", (void**)&hash);
		if (!hash)
		{
			// Retrieve controller
			id jsc = [JSCocoaController controllerFromContext:c];
			c = [jsc ctx];

			hash = JSObjectMake(c, hashObjectClass, NULL);
			// Same as copyWithZone:
			object_setInstanceVariable(self, "__jsHash", (void*)hash);
			object_setInstanceVariable(self, "__jsCocoaController", (void*)jsc);
			JSValueProtect(c, hash);
			[JSCocoaController upJSValueProtectCount];
			[JSCocoaController upJSCocoaHashCount];
		}
	
		JSObjectSetProperty(c, hash, name, valueAndContext.value, kJSPropertyAttributeNone, NULL);
		JSStringRelease(name);
		return	YES;
	}
	return	NO;
}
- (JSValueRefAndContextRef)JSValueForJSName:(JSValueRefAndContextRef)nameAndContext
{
	JSValueRefAndContextRef valueAndContext = { JSValueMakeNull(nameAndContext.ctx), NULL };
	if (class_getInstanceVariable([self class], "__jsHash"))
	{
		JSContextRef c = nameAndContext.ctx;
		JSStringRef name = JSValueToStringCopy(c, nameAndContext.value, NULL);
	
		JSObjectRef hash = NULL;
		object_getInstanceVariable(self, "__jsHash", (void**)&hash);
		if (!hash || !JSObjectHasProperty(c, hash, name))	
		{
			JSStringRelease(name);
			return	valueAndContext;
		}
		valueAndContext.ctx		= c;
		valueAndContext.value	= JSObjectGetProperty(c, hash, name, NULL);

		JSStringRelease(name);
		return	valueAndContext;
	}
	return	valueAndContext;
}

- (BOOL)deleteJSValueForJSName:(JSValueRefAndContextRef)nameAndContext
{
	if (class_getInstanceVariable([self class], "__jsHash"))
	{
		JSContextRef c = nameAndContext.ctx;
		JSStringRef name = JSValueToStringCopy(c, nameAndContext.value, NULL);
	
		JSObjectRef hash = NULL;
		object_getInstanceVariable(self, "__jsHash", (void**)&hash);
		if (!hash || !JSObjectHasProperty(c, hash, name))	
		{
			JSStringRelease(name);
			return	NO;
		}
		bool r =	JSObjectDeleteProperty(c, hash, name, NULL);
		JSStringRelease(name);
		return	r;
	}
	return	NO;
}


// Instance count debug
+ (id)allocWithZone:(NSZone*)zone
{
	// Dynamic super call
	id parentClass = [JSCocoaController parentObjCClassOfClassName:[NSString stringWithUTF8String:class_getName(self)]];
	id supermetaclass = objc_getMetaClass(class_getName(parentClass));
	struct objc_super superData = { self, supermetaclass };
	id o = objc_msgSendSuper(&superData, @selector(allocWithZone:), zone);

	[JSCocoaController upInstanceCount:o];
	return	o;
}

// Called by -(id)copy
- (id)copyWithZone:(NSZone *)zone
{
	// Dynamic super call
	id parentClass = [JSCocoaController parentObjCClassOfClassName:[NSString stringWithUTF8String:class_getName([self class])]];
	struct objc_super superData = { self, parentClass };
	id o = objc_msgSendSuper(&superData, @selector(copyWithZone:), zone);
	
	//
	// Copy hash by making a new copy
	//
	
	// Return if var has no controller
	id	jsc = nil;
	object_getInstanceVariable(self, "__jsCocoaController", (void**)&jsc);
	if (!jsc)	return	o;
	
	
	JSContextRef ctx = [jsc ctx];
	

	JSObjectRef hash1 = NULL;
	JSObjectRef hash2 = NULL;
	object_getInstanceVariable(self, "__jsHash", (void**)&hash1);
	object_getInstanceVariable(o, "__jsHash", (void**)&hash2);
	
	// Return if hash does not exist
	if (!hash1)	return	o;


	// Copy hash
	JSStringRef scriptJS = JSStringCreateWithUTF8CString("var hash1 = arguments[0]; var hash2 = {}; for (var i in hash1) hash2[i] = hash1[i]; return hash2");
	JSObjectRef fn = JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
	JSValueRef result = JSObjectCallAsFunction(ctx, fn, NULL, 1, (JSValueRef*)&hash1, NULL);
	JSStringRelease(scriptJS);
	
	// Convert hash to object
	JSObjectRef hashCopy = JSValueToObject(ctx, result, NULL);
	object_getInstanceVariable(o, "__jsHash", (void**)&hash2);

	// Same as setJSValue:forJSName:
	// Set new hash
	object_setInstanceVariable(o, "__jsHash", (void*)hashCopy);
	object_setInstanceVariable(o, "__jsCocoaController", (void*)jsc);
	JSValueProtect(ctx, hashCopy);
	[JSCocoaController upJSValueProtectCount];
	[JSCocoaController upJSCocoaHashCount];
	
	[JSCocoaController upInstanceCount:o];
	return	o;
}


// Dealloc : unprotect js hash
- (void)deallocAndCleanupJS
{
	JSObjectRef hash = NULL;
	object_getInstanceVariable(self, "__jsHash", (void**)&hash);
	if (hash)
	{
		id jsc = NULL;
		object_getInstanceVariable(self, "__jsCocoaController", (void**)&jsc);
		JSValueUnprotect([jsc ctx], hash);
		[JSCocoaController downJSCocoaHashCount];
	}
	[JSCocoaController downInstanceCount:self];

	// Dynamic super call
	id parentClass = [JSCocoaController parentObjCClassOfClassName:[NSString stringWithUTF8String:class_getName([self class])]];
	struct objc_super superData = { self, parentClass };
	objc_msgSendSuper(&superData, @selector(dealloc));
}

// Finalize - same as dealloc
static BOOL __warningSuppressorAsFinalizeIsCalledBy_objc_msgSendSuper = NO;
- (void)finalize
{
	JSObjectRef hash = NULL;
	object_getInstanceVariable(self, "__jsHash", (void**)&hash);
	if (hash)	
	{
		id jsc = NULL;
		object_getInstanceVariable(self, "__jsCocoaController", (void**)&jsc);
		JSValueUnprotect([jsc ctx], hash);
		[JSCocoaController downJSCocoaHashCount];
	}
	[JSCocoaController downInstanceCount:self];

	// Dynamic super call
	id parentClass = [JSCocoaController parentObjCClassOfClassName:[NSString stringWithUTF8String:class_getName([self class])]];
	struct objc_super superData = { self, parentClass };
	objc_msgSendSuper(&superData, @selector(finalize));
	
	// Ignore warning about missing [super finalize] as the call IS made via objc_msgSendSuper
	if (__warningSuppressorAsFinalizeIsCalledBy_objc_msgSendSuper)	[super finalize];
}



@end






#pragma mark Common instance method
// Class.instance == class.alloc.init + release (jsObject retains object)
// Class.instance( { withA : ... andB : ... } ) == class.alloc.initWithA:... andB:... + release
@implementation NSObject(CommonInstance)
+ (JSValueRef)instanceWithContext:(JSContextRef)ctx argumentCount:(size_t)argumentCount arguments:(JSValueRef*)arguments exception:(JSValueRef*)exception
{
	id methodName  = @"init";
	JSValueRef*	argumentsToFree = NULL;
	// Recover init method
	if (argumentCount == 1)
	{
		id	splitMethodName				= @"init";
		BOOL isSplitCall = [JSCocoaController trySplitCall:&splitMethodName class:self argumentCount:&argumentCount arguments:&arguments ctx:ctx];
		if (isSplitCall)	
		{
			methodName		= splitMethodName;
			argumentsToFree	= arguments;
		}
		else				return	throwException(ctx, exception, @"Instance split call did not find an init method"), NULL;
	}
//	NSLog(@"=>Called instance on %@ with init=%@", self, methodName);

	// Allocate new instance
	id newInstance = [self alloc];
	
	// Set it as new object
//	JSObjectRef thisObject = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
	id jsc = [JSCocoa controllerFromContext:ctx];
	JSObjectRef thisObject = [jsc newPrivateObject];
	JSCocoaPrivateObject* private = JSObjectGetPrivate(thisObject);
	private.type = @"@";
	[private setObjectNoRetain:newInstance];
	// No — will retain allocated object and trigger "did you forget to call init" warning
	// Object will be automatically boxed when returned to Javascript by 
//	JSObjectRef thisObject = [JSCocoaController boxedJSObject:newInstance inContext:ctx];
	
	// Create function object boxing our init method
//	JSObjectRef function = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
	JSObjectRef function = [jsc newPrivateFunction];
	private = JSObjectGetPrivate(function);
	private.type = @"method";
	private.methodName = methodName;

	// Call callAsFunction on our new instance with our init method
	JSValueRef exceptionFromInitCall = NULL;
	JSValueRef returnValue = jsCocoaObject_callAsFunction(ctx, function, thisObject, argumentCount, arguments, &exceptionFromInitCall);
	free(argumentsToFree);
	if (exceptionFromInitCall)	return	*exception = exceptionFromInitCall, NULL;
	
	// Release object
	JSObjectRef returnObject = JSValueToObject(ctx, returnValue, NULL);
	// We can get nil when initWith... fails. (eg var image = NSImage.instance({withContentsOfFile:'DOESNOTEXIST'})
	// Return nil then.
	if (returnObject == nil)	return	JSValueMakeNull(ctx);
	private = JSObjectGetPrivate(returnObject);
	id boxedObject = [private object];
	[boxedObject release];
	
	// Register our context in there so that safeDealloc finds it.
	if ([boxedObject respondsToSelector:@selector(safeDealloc)])
	{
//		id jsc = [JSCocoaController controllerFromContext:ctx];
//		object_setInstanceVariable(boxedObject, "__jsCocoaController", (void*)jsc);
	}
	return	returnValue;
}


@end






#pragma mark -
#pragma mark JavascriptCore callbacks
#pragma mark -
#pragma mark JavascriptCore OSX object

//
//
//	Global resolver : main class used as 'this' in Javascript's global scope. Name requests go through here.
//
//
JSValueRef OSXObject_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef* exception)
{
	NSString*	propertyName = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS);
	[NSMakeCollectable(propertyName) autorelease];

	if ([propertyName isEqualToString:@"__jsc__"])	return	NULL;
	
//	NSLog(@"Asking for global property %@", propertyName);
	JSCocoaController* jsc = [JSCocoaController controllerFromContext:ctx];
	id delegate = jsc.delegate;
	//
	// Delegate canGetGlobalProperty, getGlobalProperty
	//
	if (delegate)
	{
		// Check if getting is allowed
		if ([delegate respondsToSelector:@selector(JSCocoa:canGetGlobalProperty:inContext:exception:)])
		{
			BOOL canGetGlobal = [delegate JSCocoa:jsc canGetGlobalProperty:propertyName inContext:ctx exception:exception];
			if (!canGetGlobal)
			{
				if (!*exception)	throwException(ctx, exception, [NSString stringWithFormat:@"Delegate does not allow getting global property %@", propertyName]);
				return	NULL;
			}
		}
		// Check if delegate handles getting
		if ([delegate respondsToSelector:@selector(JSCocoa:getGlobalProperty:inContext:exception:)])
		{
			JSValueRef delegateGetGlobal = [delegate JSCocoa:jsc getGlobalProperty:propertyName inContext:ctx exception:exception];
			if (delegateGetGlobal)		return	delegateGetGlobal;
		}
	}
	
	//
	// ObjC class
	//
	Class objCClass = NSClassFromString(propertyName);
	if (objCClass && ![propertyName isEqualToString:@"Object"])
	{
		JSValueRef ret = [jsc boxObject:objCClass];
		return	ret;
	}

	id xml;
	id type = nil;
	//
	// Query BridgeSupport for property
	//
	xml = [[BridgeSupportController sharedController] queryName:propertyName];
	if (xml)
	{
		id error = nil;
		id xmlDocument = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
		if (error)	return	NSLog(@"(OSX_getPropertyCallback) malformed xml while getting property %@ of type %@ : %@", propertyName, type, error), NULL;
		[xmlDocument autorelease];
		
		type = [[xmlDocument rootElement] name];

		//
		// Function
		//
		if ([type isEqualToString:@"function"])
		{
//			JSObjectRef o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
			JSObjectRef o = [jsc newPrivateFunction];
			JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
			private.type = @"function";
			private.xml = xml;
			return	o;
		}

		//
		// Struct
		//
		else
		if ([type isEqualToString:@"struct"])
		{
//			JSObjectRef o = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
			JSObjectRef o = [jsc newPrivateObject];
			JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
			private.type = @"struct";
			private.xml = xml;
			return	o;
		}
		
		//
		// Constant
		//
		else
		if ([type isEqualToString:@"constant"])
		{
			// ##fix : NSZeroPoint, NSZeroRect, NSZeroSize would need special (struct) + type64 handling
			// Check if constant's declared_type is NSString*
			id declared_type = [[xmlDocument rootElement] attributeForName:@"declared_type"];
			if (!declared_type)	declared_type = [[xmlDocument rootElement] attributeForName:@"type"];
			if (!declared_type || !([[declared_type stringValue] isEqualToString:@"NSString*"] 
									|| [[declared_type stringValue] isEqualToString:@"@"]
									|| [[declared_type stringValue] isEqualToString:@"^{__CFString=}"]
									))	
				return	NSLog(@"(OSX_getPropertyCallback) %@ not a NSString* constant : %@", propertyName, xml), NULL;

			// Grab symbol
			void* symbol = dlsym(RTLD_DEFAULT, [propertyName UTF8String]);
			if (!symbol)	return	NSLog(@"(OSX_getPropertyCallback) symbol %@ not found", propertyName), NULL;

			// ObjC objects, like NSApp : pointer to NSApplication.sharedApplication
			if ([[declared_type stringValue] isEqualToString:@"@"])
			{
				id o = *(id*)symbol;
				return [jsc boxObject:o];
			}

			// Return symbol as a Javascript string
			NSString* str		= *(NSString**)symbol;
			JSStringRef jsName	= JSStringCreateWithUTF8CString([str UTF8String]);
			JSValueRef jsString	= JSValueMakeString(ctx, jsName);
			JSStringRelease(jsName);
			return	jsString;
		}

		//
		// Enum
		//
		else
		if ([type isEqualToString:@"enum"])
		{
			// Check if constant's declared_type is NSString*
			id value = [[xmlDocument rootElement] attributeForName:@"value"];
			if (!value)	
			{
				value = [[xmlDocument rootElement] attributeForName:@"value64"];
				if (!value)
					return	NSLog(@"(OSX_getPropertyCallback) %@ enum has no value set", propertyName), NULL;
			}

			// Try parsing value
			double doubleValue = 0;
			value = [value stringValue];
			if (![[NSScanner scannerWithString:value] scanDouble:&doubleValue]) return	NSLog(@"(OSX_getPropertyCallback) scanning %@ enum failed", propertyName), NULL;
			return	JSValueMakeNumber(ctx, doubleValue);
		}
	}

	// Describe ourselves
	if ([propertyName isEqualToString:@"toString"] || [propertyName isEqualToString:@"valueOf"])
	{
		JSStringRef scriptJS = JSStringCreateWithUTF8CString("return '(JSCocoa global object)'");
		JSObjectRef fn = JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
		JSStringRelease(scriptJS);
		return	fn;
	}

	return	NULL;
}


static void OSXObject_getPropertyNames(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames)
{
	// Move to a definition object
/*
	NSArray* keys = [[BridgeSupportController sharedController] keys];
	for (id key in keys)
	{
		JSStringRef jsString = JSStringCreateWithUTF8CString([key UTF8String]);
		JSPropertyNameAccumulatorAddName(propertyNames, jsString);
		JSStringRelease(jsString);			
	}
*/	
}






#pragma mark JavascriptCore JSCocoa object

//
// Below lie the Javascript callbacks for all Javascript objects created by JSCocoa, used to pass ObjC data to and fro Javascript.
//


//
// From PyObjC : when to call objc_msgSend_stret, for structure return
//		Depending on structure size & architecture, structures are returned as function first argument (done transparently by ffi) or via registers
//
BOOL	isUsingStret(id argumentEncodings)
{
	int resultSize = 0;
	char returnEncoding = [[argumentEncodings objectAtIndex:0] typeEncoding];
	if (returnEncoding == _C_STRUCT_B) resultSize = [JSCocoaFFIArgument sizeOfStructure:[[argumentEncodings objectAtIndex:0] structureTypeEncoding]];
	if (returnEncoding == _C_STRUCT_B && 
	//#ifdef  __ppc64__
	//			ffi64_stret_needs_ptr(signature_to_ffi_return_type(rettype), NULL, NULL)
	//
	//#else /* !__ppc64__ */
				(resultSize > SMALL_STRUCT_LIMIT
	#ifdef __i386__
				 /* darwin/x86 ABI is slightly odd ;-) */
				 || (resultSize != 1 
					&& resultSize != 2 
					&& resultSize != 4 
					&& resultSize != 8)
	#endif
	#ifdef __x86_64__
				 /* darwin/x86-64 ABI is slightly odd ;-) */
				 || (resultSize != 1 
					&& resultSize != 2 
					&& resultSize != 4 
					&& resultSize != 8
					&& resultSize != 16
					)
	#endif
				)
	//#endif /* !__ppc64__ */
				) {
//					callAddress = objc_msgSend_stret;
//					usingStret = YES;
				return	YES;
			}
		return	NO;				
}

//
//	Return the correct objc_msgSend* variety according to encodings
//
void*	getObjCCallAddress(id argumentEncodings)
{
	BOOL	usingStret	= isUsingStret(argumentEncodings);
	void*	callAddress	= objc_msgSend;
	if (usingStret)	callAddress = objc_msgSend_stret;


#if __i386__ // || TARGET_OS_IPHONE no, iPhone uses objc_msgSend
	char returnEncoding = [[argumentEncodings objectAtIndex:0] typeEncoding];
	if (returnEncoding == 'f' || returnEncoding == 'd')
	{
		callAddress = objc_msgSend_fpret;
	}
#endif

	return	callAddress;
}

//
// Convert FROM a webView context to a local context (called by valueOf(), toString())
//
JSValueRef valueFromExternalContext(JSContextRef externalCtx, JSValueRef value, JSContextRef ctx)
{
	int type = JSValueGetType(externalCtx, value);
	switch (type)
	{
		case kJSTypeUndefined:
		{
			return JSValueMakeUndefined(ctx);
		}

		case kJSTypeNull:
		{
			return JSValueMakeNull(ctx);
		}

		case kJSTypeBoolean:
		{
			bool b = JSValueToBoolean(externalCtx, value);
			return JSValueMakeBoolean(ctx, b);
		}

		case kJSTypeNumber:
		{
			double d = JSValueToNumber(externalCtx, value, NULL);
			return JSValueMakeNumber(ctx, d);
		}

		// Make strings and objects show up only as strings
		case kJSTypeString:
		case kJSTypeObject:
		{
			// Add an (externalContext) suffix to distinguish boxed JSValues from a WebView
			JSStringRef jsString	= JSValueToStringCopy(externalCtx, value, NULL);

			NSString* string		= (NSString*)JSStringCopyCFString(kCFAllocatorDefault, jsString);
			NSString* idString;
			
			// Mark only objects as (externalContext), not raw strings
			if (type == kJSTypeObject)	idString = [NSString stringWithFormat:@"%@ (externalContext)", string];
			else						idString = [NSString stringWithFormat:@"%@", string];
			[string release];
			JSStringRelease(jsString);
			
			jsString				= JSStringCreateWithUTF8CString([idString UTF8String]);
			JSValueRef returnValue	= JSValueMakeString(ctx, jsString);
			JSStringRelease(jsString);
			
			return returnValue;
		}
	}
	return JSValueMakeNull(ctx);
}

//
// Convert TO a webView context from a local context
//
JSValueRef valueToExternalContext(JSContextRef ctx, JSValueRef value, JSContextRef externalCtx)
{
	int type = JSValueGetType(ctx, value);
	switch (type)
	{
		case kJSTypeUndefined:
		{
			return JSValueMakeUndefined(externalCtx);
		}

		case kJSTypeNull:
		{
			return JSValueMakeNull(externalCtx);
		}

		case kJSTypeBoolean:
		{
			bool b = JSValueToBoolean(ctx, value);
			return JSValueMakeBoolean(externalCtx, b);
		}

		case kJSTypeNumber:
		{
			double d = JSValueToNumber(ctx, value, NULL);
			return JSValueMakeNumber(externalCtx, d);
		}

		case kJSTypeString:
		{
			JSStringRef	jsString = JSValueToStringCopy(ctx, value, NULL);
			JSValueRef	returnValue = JSValueMakeString(externalCtx, jsString);
			JSStringRelease(jsString);
			return		returnValue;
		}
		case kJSTypeObject:
		{
			JSObjectRef o = JSValueToObject(ctx, value, NULL);
			if (!o)		return	JSValueMakeNull(externalCtx);
			JSCocoaPrivateObject* privateObject = JSObjectGetPrivate(o);
			if (![privateObject.type isEqualToString:@"externalJSValueRef"])	
			{
				id object = [privateObject object];
				if ([object isKindOfClass:[NSString class]])
				{
					JSStringRef jsName	= JSStringCreateWithUTF8CString([object UTF8String]);
					JSValueRef jsString	= JSValueMakeString(externalCtx, jsName);
					JSStringRelease(jsName);
					return		jsString;
				}
				if ([object isKindOfClass:[NSNumber class]])
				{
					return		JSValueMakeNumber(externalCtx, [object doubleValue]);
				}
//				NSLog(@"Object (%@) converted to undefined", o );
				return	JSValueMakeUndefined(externalCtx);
			}
			return	[privateObject jsValueRef];
		}
	}
	return JSValueMakeNull(externalCtx);
}

JSValueRef boxedValueFromExternalContext(JSContextRef externalCtx, JSValueRef value, JSContextRef ctx)
{
	if (JSValueGetType(externalCtx, value) < kJSTypeObject)	return valueFromExternalContext(externalCtx, value, ctx);

	// If value is function ...
	JSStringRef scriptJS= JSStringCreateWithUTF8CString("return (typeof arguments[0]) == 'function' ? true : null");
	JSObjectRef fn		= JSObjectMakeFunction(externalCtx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
	JSValueRef result	= JSObjectCallAsFunction(externalCtx, fn, NULL, 1, (JSValueRef*)&value, NULL);
	JSStringRelease(scriptJS);

	// ... use the function boxer
	JSObjectRef o; 
	if (JSValueIsBoolean(externalCtx, result))
//		o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
		o = [[JSCocoa controllerFromContext:ctx] newPrivateFunction];
	else
//		o = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
		o = [[JSCocoa controllerFromContext:ctx] newPrivateFunction];
		
	JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
	private.type = @"externalJSValueRef";
	[private setExternalJSValueRef:value ctx:externalCtx];
	return	o;	
}


//
// valueOf : from a boxed ObjC object, returns a primitive javascript value (number or string) 
//  that JavascriptCore can use in expressions (eg boxedObject + 'this', boxedObject < 4)
//
//  The returned value is temporary and does not affect the boxed object.
//
JSValueRef valueOfCallback(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception)
{
	// Holding a native JS value ? Return it
	JSCocoaPrivateObject* thisPrivateObject = JSObjectGetPrivate(thisObject);
	if ([thisPrivateObject.type isEqualToString:@"jsValueRef"])	
	{
		return [thisPrivateObject jsValueRef];
	}

	// External jsValueRef from WebView
	if ([thisPrivateObject.type isEqualToString:@"externalJSValueRef"])	
	{
		JSContextRef externalCtx		= [thisPrivateObject ctx];
		JSValueRef externalJSValueRef	= [thisPrivateObject jsValueRef];
		JSStringRef scriptJS= JSStringCreateWithUTF8CString("return arguments[0].valueOf()");
		JSObjectRef fn		= JSObjectMakeFunction(externalCtx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
		JSValueRef result	= JSObjectCallAsFunction(externalCtx, fn, NULL, 1, (JSValueRef*)&externalJSValueRef, NULL);
		JSStringRelease(scriptJS);

		return	valueFromExternalContext(externalCtx, result, ctx);
	}
	
	// NSNumber special case
	if ([thisPrivateObject.object isKindOfClass:[NSNumber class]])
		return	JSValueMakeNumber(ctx, [thisPrivateObject.object doubleValue]);

	// Convert to string
	id toString = [thisPrivateObject description];
	
	// Object
	if ([thisPrivateObject.type isEqualToString:@"@"])
	{
		// Holding an out value ?
		if ([thisPrivateObject.object isKindOfClass:[JSCocoaOutArgument class]])
		{
			JSValueRef outValue = [(JSCocoaOutArgument*)thisPrivateObject.object outJSValueRefInContext:ctx];
			if (!outValue)
			{
				JSStringRef	jsName = JSStringCreateWithUTF8CString("Unitialized outArgument");
				JSValueRef r = JSValueMakeString(ctx, jsName);
				JSStringRelease(jsName);
				return r;
			}
			// Holding an object ? Call valueOf on it
			if (JSValueGetType(ctx, outValue) == kJSTypeObject)
				return valueOfCallback(ctx, NULL, JSValueToObject(ctx, outValue, NULL), 0, NULL, NULL);
			// Return raw JSValueRef
			return outValue;
		}
		else
			toString = [NSString stringWithFormat:@"%@", [[thisPrivateObject object] description]];
	}

	// Struct
	if ([thisPrivateObject.type isEqualToString:@"struct"])
	{
		id structDescription = nil;
		id self = [JSCocoaController controllerFromContext:ctx];
		if ([self hasJSFunctionNamed:@"describeStruct"])
		{
			JSStringRef scriptJS = JSStringCreateWithUTF8CString("return describeStruct(arguments[0])");
			JSObjectRef fn = JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
			JSValueRef jsValue = JSObjectCallAsFunction(ctx, fn, NULL, 1, (JSValueRef*)&thisObject, NULL);
			JSStringRelease(scriptJS);

			[JSCocoaFFIArgument unboxJSValueRef:jsValue toObject:&structDescription inContext:ctx];
		}
		
		toString = [NSString stringWithFormat:@"<%@ %@>", thisPrivateObject.structureName, structDescription];
	}
	
	// Return a number is the whole string (no spaces, no others chars) is a number
	// This emulates the javascript behaviour '4'*2 -> 8 when '4' is a string or an NSString
	NSScanner* scan = [NSScanner scannerWithString:toString];
	[scan setCharactersToBeSkipped:nil];
	double v = 0;
	[scan scanDouble:&v];
	if ([scan isAtEnd])
		return JSValueMakeNumber(ctx, v);

	// Convert to string and return
	JSStringRef jsToString = JSStringCreateWithCFString((CFStringRef)toString);
	JSValueRef jsValueToString = JSValueMakeString(ctx, jsToString);
	JSStringRelease(jsToString);
	return	jsValueToString;
}

//
// initialize
//	retain boxed object
//
static void jsCocoaObject_initialize(JSContextRef ctx, JSObjectRef object)
{
	id o = JSObjectGetPrivate(object);
	[o retain];
}

//
// finalize
//	release boxed object
//
static void jsCocoaObject_finalize(JSObjectRef object)
{
//	NSLog(@"finalizing %p", object);

	// If dealloc is overloaded, releasing now will trigger JS code and fail
	// As we're being called by GC, KJS might assert() in operationInProgress == NoOperation
	JSCocoaPrivateObject* private = JSObjectGetPrivate(object);
	
	// Clean up the object now as WebKit calls us twice while cleaning __jsc__ (20110730)
	JSObjectSetPrivate(object, NULL);
	id jsc = nil;
	JSContextRef ctx = [private ctx];

	if (ctx)
		jsc = [JSCocoa controllerFromContext:ctx];
	// We will be called during garbage collection before dealloc occurs. 
	// The __jsc__ variable will be gone, therefore controllerFromContext will yield 0.
	// Not a problem since it's only used to remove the object from the boxedObjects hash,
	// and dealloc will occur soon after.

	//
	// If a boxed object is being destroyed, remove it from the cache
	//
	id boxedObject = [private object]; 
	if (boxedObject) {
		if ([jsc isObjectBoxed:boxedObject]) {
			// Safe dealloc ?
			if ([boxedObject retainCount] == 1) {
				if ([boxedObject respondsToSelector:@selector(safeDealloc)]) {
					jsc = NULL;
					object_getInstanceVariable(boxedObject, "__jsCocoaController", (void**)&jsc);
					// Call safeDealloc if enabled (will be disabled upon last JSCocoaController release, to make sure the )
					if (jsc) {
						if ([jsc useSafeDealloc])
							[jsc performSelector:@selector(safeDeallocInstance:) withObject:boxedObject afterDelay:0];
					} else
						NSLog(@"safeDealloc could not find the context attached to %@.%p - allocate this object with instance, or add a Javascript variable to it (obj.hello = 'world')", [boxedObject class], boxedObject);
				}
			}
			[jsc deleteBoxOfObject:boxedObject];
		}
	}
	
	// Immediate release if dealloc is not overloaded
	[private release];
	
#ifdef __OBJC_GC__
	// Mark internal object as collectable
	[[NSGarbageCollector defaultCollector] enableCollectorForPointer:private];
#endif
}

/*
//
// Not needed as getProperty can return NULL to indicate property inexistance.
//
//	log('doesNotExist' in object)
//		getProperty returning undefined would mean the key is defined and has an undefined value.
//		getProperty therefore returns NULL and the in operator returns false.
//		-> hasProperty not needed.
//
static bool jsCocoaObject_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS)
{
	NSString*	propertyName = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS);
	[NSMakeCollectable(propertyName) autorelease];
	NSLog(@"hasProperty %@", propertyName);
	return jsCocoaObject_getProperty(ctx, object, propertyNameJS, NULL);
	return YES;
}
*/

//
// getProperty
//	Return property in object's internal Javascript hash if its contains propertyName
//	else ...
//	Get objC method matching propertyName, autocall it
//	else ...
//	method may be a split call -> return a private object
//
//	At method start, handle special cases for arrays (integers, length) and dictionaries
//
static JSValueRef jsCocoaObject_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef* exception)
{
	NSString*	propertyName = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS);
	[NSMakeCollectable(propertyName) autorelease];
	
	JSCocoaPrivateObject* privateObject = JSObjectGetPrivate(object);
//	NSLog(@"Asking for property %@ %@(%@)", propertyName, privateObject, privateObject.type);

	// Get delegate
	JSCocoaController* jsc = [JSCocoaController controllerFromContext:ctx];
	id delegate = jsc.delegate;

	if ([privateObject.type isEqualToString:@"@"])
	{
call:		
		//
		// Delegate canGetProperty, getProperty
		//
		if (delegate)
		{
			// Check if getting is allowed
			if ([delegate respondsToSelector:@selector(JSCocoa:canGetProperty:ofObject:inContext:exception:)])
			{
				BOOL canGet = [delegate JSCocoa:jsc canGetProperty:propertyName ofObject:privateObject.object inContext:ctx exception:exception];
				if (!canGet)
				{
					if (!*exception)	throwException(ctx, exception, [NSString stringWithFormat:@"Delegate does not allow getting %@.%@", privateObject.object, propertyName]);
					return	NULL;
				}
			}
			// Check if delegate handles getting
			if ([delegate respondsToSelector:@selector(JSCocoa:getProperty:ofObject:inContext:exception:)])
			{
				JSValueRef delegateGet = [delegate JSCocoa:jsc getProperty:propertyName ofObject:privateObject.object inContext:ctx exception:exception];
				if (delegateGet)		return	delegateGet;
			}
		}

		// Special case for NSMutableArray get and Javascript array methods
//		if ([privateObject.object isKindOfClass:[NSArray class]])
		// Use respondsToSelector for custom indexed access
		if ([privateObject.object respondsToSelector:@selector(objectAtIndex:)])
		{
			id array	= privateObject.object;
			id scan		= [NSScanner scannerWithString:propertyName];
			NSInteger propertyIndex;
			// Is asked property an int ?
			BOOL convertedToInt =  ([scan scanInteger:&propertyIndex]);
			if (convertedToInt && [scan isAtEnd])
			{
				if (propertyIndex < 0 || propertyIndex >= [array count])	return	NULL;
				
				id o = [array objectAtIndex:propertyIndex];
				JSValueRef value = NULL;
				[JSCocoaFFIArgument boxObject:o toJSValueRef:&value inContext:ctx];
				return	value;
			}
			
			// If we have 'length', switch it to 'count'
			if ([propertyName isEqualToString:@"length"])	propertyName = @"count";
		
			// NSArray bridge
			id callee	= [privateObject object];
			SEL sel		= NSSelectorFromString(propertyName);
			if ([propertyName rangeOfString:@":"].location == NSNotFound && ![callee respondsToSelector:sel]
				&& ![propertyName isEqualToString:@"valueOf"] 
				&& ![propertyName isEqualToString:@"toString"] 
			)
			{
				id script				= [NSString stringWithFormat:@"return Array.prototype.%@", propertyName];
				JSStringRef scriptJS	= JSStringCreateWithUTF8CString([script UTF8String]);
				JSObjectRef fn			= JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
				JSValueRef result		= JSObjectCallAsFunction(ctx, fn, NULL, 0, NULL, NULL);
				JSStringRelease(scriptJS);
				BOOL isJavascriptArrayMethod =  result ? !JSValueIsUndefined(ctx, result) : NO;

				// Return the packaged Javascript function
				if (isJavascriptArrayMethod)
				{
//					NSLog(@"*** array method : %@", propertyName);
//					JSObjectRef o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
					JSObjectRef o = [jsc newPrivateFunction];
					JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
					private.type = @"jsFunction";
					[private setJSValueRef:result ctx:ctx];
					return	o;
				}
			}
		}
		
		
		// Special case for NSMutableDictionary get
//		if ([privateObject.object isKindOfClass:[NSDictionary class]])
		// Use respondsToSelector for custom indexed access
		if ([privateObject.object respondsToSelector:@selector(objectForKey:)])
		{
			id dictionary	= privateObject.object;
			id o = [dictionary objectForKey:propertyName];
			if (o)
			{
				JSValueRef value = NULL;
				[JSCocoaFFIArgument boxObject:o toJSValueRef:&value inContext:ctx];
				return	value;
			}
		}

		// Special case for JSCocoaMemoryBuffer get
		if ([privateObject.object isKindOfClass:[JSCocoaMemoryBuffer class]])
		{
			id buffer = privateObject.object;
			
			id scan		= [NSScanner scannerWithString:propertyName];
			NSInteger propertyIndex;
			// Is asked property an int ?
			BOOL convertedToInt =  ([scan scanInteger:&propertyIndex]);
			if (convertedToInt && [scan isAtEnd])
			{
				if (propertyIndex < 0 || propertyIndex >= [buffer typeCount])	return	NULL;
				return	[buffer valueAtIndex:propertyIndex inContext:ctx];
			}
		}
		
		// Check object's internal property in its jsHash
		id callee	= [privateObject object];
		if ([callee respondsToSelector:@selector(JSValueForJSName:)])
		{
			JSValueRefAndContextRef	name	= { JSValueMakeString(ctx, propertyNameJS), ctx } ;
			JSValueRef hashProperty			= [callee JSValueForJSName:name].value;
			if (hashProperty && !JSValueIsNull(ctx, hashProperty))
			{
				BOOL	returnHashValue = YES;
				// Make sure to not return hash value if it's native code (valueOf, toString)
				if ([propertyName isEqualToString:@"valueOf"] || [propertyName isEqualToString:@"toString"])
				{
					id script = [NSString stringWithFormat:@"return arguments[0].toString().indexOf('[native code]') != -1", propertyName];
					JSStringRef scriptJS = JSStringCreateWithUTF8CString([script UTF8String]);
					JSObjectRef fn = JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
					JSValueRef result = JSObjectCallAsFunction(ctx, fn, NULL, 1, (JSValueRef*)&hashProperty, NULL);
					JSStringRelease(scriptJS);
					BOOL isNativeCode =  result ? JSValueToBoolean(ctx, result) : NO;
					returnHashValue = !isNativeCode;
//					NSLog(@"isNative(%@)=%d rawJSResult=%p hashProperty=%p returnHashValue=%d", propertyName, isNativeCode, result, hashProperty, returnHashValue);
				}
				if (returnHashValue)	return	hashProperty;
			}
		}
/*
		// ## Use javascript override functions, only bridge side. Discarded for now as it doesn't give a way to call the original method
		// ## Plus : useful ? as it can be done by setting custom js functions on the boxed objects
		// Check if this is a Javascript override
		id script = [NSString stringWithFormat:@"__globalJSFunctionRepository__.%@.%@", [callee class], propertyName];
		JSStringRef	jsScript = JSStringCreateWithUTF8CString([script UTF8String]);
		JSValueRef result = JSEvaluateScript(ctx, jsScript, NULL, NULL, 1, NULL);
		JSStringRelease(jsScript);
		if (result && JSValueGetType(ctx, result) == kJSTypeObject)
		{
			NSLog(@"GOT IT %@", propertyName);
			JSObjectRef o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
			JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
			private.type = @"jsFunction";
			[private setJSValueRef:result ctx:ctx];
			return	o;
		}
*/		
		//
		// Attempt Zero arg autocall
		// Object.alloc().init() -> Object.alloc.init
		//
		if ([jsc useAutoCall])
		{
			callee	= [privateObject object];
			SEL sel		= NSSelectorFromString(propertyName);
			
			BOOL isInstanceCall = [propertyName isEqualToString:@"instance"];
			// Go for zero arg call
			if ([propertyName rangeOfString:@":"].location == NSNotFound && ([callee respondsToSelector:sel] || isInstanceCall))
			{
				//
				// Delegate canCallMethod, callMethod
				//
				if (delegate)
				{
					// Check if calling is allowed
					if ([delegate respondsToSelector:@selector(JSCocoa:canCallMethod:ofObject:argumentCount:arguments:inContext:exception:)])
					{
						BOOL canCall = [delegate JSCocoa:jsc canCallMethod:propertyName ofObject:callee argumentCount:0 arguments:NULL inContext:ctx exception:exception];
						if (!canCall)
						{
							if (!*exception)	throwException(ctx, exception, [NSString stringWithFormat:@"Delegate does not allow calling [%@ %@]", callee, propertyName]);
							return	NULL;
						}
					}
					// Check if delegate handles calling
					if ([delegate respondsToSelector:@selector(JSCocoa:callMethod:ofObject:privateObject:argumentCount:arguments:inContext:exception:)])
					{
						JSValueRef delegateCall = [delegate JSCocoa:jsc callMethod:propertyName ofObject:callee privateObject:privateObject argumentCount:0 arguments:NULL inContext:ctx exception:exception];
						if (delegateCall)	
							return	delegateCall;
					}
				}

				// instance
				if (isInstanceCall)
				{
					// Manually call and box our object
					id class	= [callee class];
					id instance	= [[class alloc] init];
					JSValueRef	returnValue;
					[JSCocoaFFIArgument boxObject:instance toJSValueRef:&returnValue inContext:ctx];
					// Release it, making the javascript box the sole retainer
					// Nulling all references to this object will release the instance during Javascript GC					
					JSCocoaPrivateObject* private = JSObjectGetPrivate(JSValueToObject(ctx, returnValue, NULL));
					[private.object release];
					
					return	returnValue;
				}

				// Special case for alloc autocall — do not retain alloced result as it might crash (eg [[NSLocale alloc] retain] fails in ObjC)
				if ([propertyName isEqualToString:@"alloc"])
				{
					id allocatedObject = [callee alloc];
//					JSObjectRef jsObject = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
					JSObjectRef jsObject = [jsc newPrivateObject];
					JSCocoaPrivateObject* private = JSObjectGetPrivate(jsObject);
					private.type = @"@";
					[private setObjectNoRetain:allocatedObject];
					return	jsObject;
				}
				
				// Get method pointer
				Method method = class_getInstanceMethod([callee class], sel);
				if (!method)	method = class_getClassMethod([callee class], sel);
				
				// If we didn't find a method, try Distant Object
				if (!method)
				{
					JSValueRef res = [jsc JSCocoa:jsc callMethod:propertyName ofObject:callee privateObject:privateObject argumentCount:0 arguments:NULL inContext:ctx exception:exception];
					if (res)	return	res;
								
					throwException(ctx, exception, [NSString stringWithFormat:@"Could not get property[%@ %@]", callee, propertyName]);
					return	NULL;
				}
				
				// Extract arguments
				const char* typeEncoding	= method_getTypeEncoding(method);
				id argumentEncodings		= [JSCocoaController parseObjCMethodEncoding:typeEncoding];
				// Call address
				void* callAddress			= getObjCCallAddress(argumentEncodings);
				
				//
				// ffi data
				//
				ffi_cif		cif;
				ffi_type*	args[2];
				void*		values[2];
				char*		selector;
	
				selector	= (char*)NSSelectorFromString(propertyName);
				args[0]		= &ffi_type_pointer;
				args[1]		= &ffi_type_pointer;
				values[0]	= (void*)&callee;
				values[1]	= (void*)&selector;
				
				// Get return value holder
				id returnValue = [argumentEncodings objectAtIndex:0];
				
				// Allocate return value storage if it's a pointer
				if ([returnValue typeEncoding] == '^')
					[returnValue allocateStorage];

				// Setup ffi
				ffi_status prep_status	= ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, [returnValue ffi_type], args);
				//
				// Call !
				//
				if (prep_status == FFI_OK)
				{
					void* storage = [returnValue storage];
					if ([returnValue ffi_type] == &ffi_type_void)	storage = NULL;
					ffi_call(&cif, callAddress, storage, values);
				}

				// Return now if our function returns void
				// NO - box it
//				if ([returnValue ffi_type] == &ffi_type_void)	return	NULL;
				// Else, convert return value
				JSValueRef	jsReturnValue = NULL;
				BOOL converted = [returnValue toJSValueRef:&jsReturnValue inContext:ctx];
				if (!converted)	return	throwException(ctx, exception, [NSString stringWithFormat:@"Return value not converted in %@", propertyName]), NULL;

				return	jsReturnValue;
			}
		}
		
		// Check if we're holding an out value
		if ([privateObject.object isKindOfClass:[JSCocoaOutArgument class]])
		{
			JSValueRef outValue = [(JSCocoaOutArgument*)privateObject.object outJSValueRefInContext:ctx];
			if (outValue && JSValueGetType(ctx, outValue) == kJSTypeObject)
			{
				JSObjectRef outObject = JSValueToObject(ctx, outValue, NULL);
				JSValueRef possibleReturnValue = JSObjectGetProperty(ctx, outObject, propertyNameJS, NULL);
				return	possibleReturnValue;
			}
		}
		
		// Info object for instances and classes
		if ([propertyName isEqualToString:@RuntimeInformationPropertyName])
		{
			JSObjectRef o = JSObjectMake(ctx, jsCocoaInfoClass, NULL);

			JSStringRef	classNameProperty	= JSStringCreateWithUTF8CString("className");
			JSStringRef	className			= JSStringCreateWithUTF8CString([[[[privateObject object] class] description] UTF8String]);
			JSObjectSetProperty(ctx, o, classNameProperty, JSValueMakeString(ctx, className), 
							kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontEnum|kJSPropertyAttributeDontDelete, NULL);
			JSStringRelease(classNameProperty);
			JSStringRelease(className);
			return	o;
		}
		

		//
		//	We're asked a property name and at this point we've checked the class's jsarray, autocall. 
		//	If the property we're asked does not start a split call we'll return NULL.
		//
		//		Check if the property is actually a method.
		//		If NO, replace underscores with colons
		//				add a ':' suffix
		//
		//		If callee still fails to responds to that, check if propertyName starts a split call.
		//		If NO, return null
		//
		id methodName = [NSMutableString stringWithString:propertyName];
		// If responds to selector, OK
		if (![callee respondsToSelector:NSSelectorFromString(methodName)] 
			// non ObjC methods
			&& ![methodName isEqualToString:@"valueOf"] 
			&& ![methodName isEqualToString:@"Super"]
			&& ![methodName isEqualToString:@"Original"]
/*			&& ![methodName isEqualToString:@"instance"]*/)
		{
			// If setting on boxed objects is allowed, check existence of a property set on the js object - this is a reentrant call
			if ([jsc canSetOnBoxedObjects])
			{
				// We need to bypass our get handler to get the js value
				static int canSetCheck = 0;
				// Return NULL so the get handler will retrieve the js property stored in the js object
				if (canSetCheck > 0)
					return NULL;

				canSetCheck++;
				// Call default handler
				JSValueRef jsValueSetOnBoxedObject = JSObjectGetProperty(ctx, object, propertyNameJS, nil);
				canSetCheck--;

				// If we have something other than undefined, return it
				if (JSValueGetType(ctx, jsValueSetOnBoxedObject) != kJSTypeUndefined)
					return jsValueSetOnBoxedObject;
			}

			if ([methodName rangeOfString:@"_"].location != NSNotFound)
				[methodName replaceOccurrencesOfString:@"_" withString:@":" options:0 range:NSMakeRange(0, [methodName length])];

			if ([jsc callSelectorsMissingTrailingSemicolon] && ![methodName hasSuffix:@":"])	[methodName appendString:@":"];			

			if (![callee respondsToSelector:NSSelectorFromString(methodName)])
			{
				// Instance check
				if ([methodName hasPrefix:@"instance"])
				{
					id initMethodName = [NSString stringWithFormat:@"init%@", [methodName substringFromIndex:8]];
					if ([callee instancesRespondToSelector:NSSelectorFromString(initMethodName)])
					{
//						JSObjectRef o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
						JSObjectRef o = [jsc newPrivateFunction];
						JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
						private.type = @"method";
						private.methodName = methodName;
						return o;
					}
				}
			
				//
				// This may be a JS function
				//
				Class class = [callee class];
				JSValueRef result = NULL;
				while (class)
				{
					id script = [NSString stringWithFormat:@"__globalJSFunctionRepository__.%@.%@", class, propertyName];
					JSStringRef	jsScript = JSStringCreateWithUTF8CString([script UTF8String]);
					result = JSEvaluateScript(ctx, jsScript, NULL, NULL, 1, NULL);
					JSStringRelease(jsScript);
					// Found ? Break
					if (result && JSValueGetType(ctx, result) == kJSTypeObject)	break;
					
					// Go up parent class
					class = [class superclass];
				}
				// This is a pure JS function call — box it
				if (result && JSValueGetType(ctx, result) == kJSTypeObject)
				{
//					JSObjectRef o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
					JSObjectRef o = [jsc newPrivateFunction];
					JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
					private.type = @"jsFunction";
					[private setJSValueRef:result ctx:ctx];
					return	o;
				}

				methodName = propertyName;

				// Get the meta class if callee is a class
				class = [callee class];
				if (callee == class)
					class = objc_getMetaClass(object_getClassName(class));
				// Try split start
				BOOL isMaybeSplit = NO;
				if ([jsc useSplitCall])
					isMaybeSplit = [JSCocoaController isMaybeSplitCall:methodName forClass:class];
				// If not split and not NSString, return (if NSString, try to convert to JS string in callAsFunction and use native JS methods)
				if (!isMaybeSplit && ![callee isKindOfClass:[NSString class]])	
				{
					return	NULL;
				}
			}
		}
		
		// Get ready for method call
//		JSObjectRef o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
		JSObjectRef o = [jsc newPrivateFunction];
		JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
		private.type = @"method";
		private.methodName = methodName;

		return	o;
	}
	
	// Struct + rawPointer valueOf
	if (/*[privateObject.type isEqualToString:@"struct"] &&*/ ([propertyName isEqualToString:@"valueOf"] || [propertyName isEqualToString:@"toString"]))
	{
//		JSObjectRef o = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
		JSObjectRef o = [jsc newPrivateFunction];
		JSCocoaPrivateObject* private = JSObjectGetPrivate(o);
		private.type = @"method";
		private.methodName = propertyName;
		return	o;
	}


	// Pointer ops
	//	* If we have an external Javascript context, query it
	//	* Handle pointer reference / dereference with JSCocoaFFIArgument
	if ([privateObject.type isEqualToString:@"rawPointer"])
	{
		BOOL responds = NO;
		id methodName = propertyName;
		responds = [privateObject respondsToSelector:NSSelectorFromString(propertyName)];
		if (!responds) {
			methodName = [NSString stringWithFormat:@"%@:", methodName];
			responds = [privateObject respondsToSelector:NSSelectorFromString(methodName)];
		}
		if (responds)
		{
			// When calling a method with arguments, this will be used to get the instance on which to call
			id callee = privateObject;
			// Retaining the object leaks
			[privateObject setObjectNoRetain:privateObject];

			privateObject = [[JSCocoaPrivateObject new] autorelease];
			privateObject.object = callee;
			privateObject.type = @"@";
			goto call;
		}
	}

	// External WebView value
	if ([privateObject.type isEqualToString:@"externalJSValueRef"] || [[privateObject rawPointerEncoding] isEqualToString:@"^{OpaqueJSContext=}"])
	{
		JSValueRef externalValue = [privateObject jsValueRef];
		JSContextRef externalCtx = externalValue ? [privateObject ctx] : [privateObject rawPointer];
		JSObjectRef externalObject = externalValue ? JSValueToObject(externalCtx, externalValue, NULL) : JSContextGetGlobalObject(externalCtx);
		
		if (!JSObjectHasProperty(externalCtx, externalObject, propertyNameJS))	return NULL;
		JSValueRef r = JSObjectGetProperty(externalCtx, externalObject, propertyNameJS, exception);
		// If WebView had an exception, re-throw it in our context
		if (exception && *exception)	
		{
			id s = [JSCocoaController formatJSException:*exception inContext:externalCtx];
			throwException(ctx, exception, [NSString stringWithFormat:@"(WebView) %@", s]);
			return JSValueMakeNull(ctx);
		}
		JSValueRef r2 = boxedValueFromExternalContext(externalCtx, r, ctx);
		return r2;
	}


	// Structs will get here when being asked javascript attributes (eg 'x' in point.x)
//	NSLog(@"Asking for property %@ %@(%@)", propertyName, privateObject, privateObject.type);
	
	return	NULL;
}


//
// setProperty
//	call setter : propertyName -> setPropertyName
//
static bool jsCocoaObject_setProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef jsValue, JSValueRef* exception)
{
	JSCocoaPrivateObject* privateObject = JSObjectGetPrivate(object);
	NSString*	propertyName = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS);
	[NSMakeCollectable(propertyName) autorelease];
	
//	NSLog(@"****SET %@ in ctx %p on object %p (type=%@) method=%@", propertyName, ctx, object, privateObject.type, privateObject.methodName);

	// Get delegate
	JSCocoaController* jsc = [JSCocoaController controllerFromContext:ctx];
	id delegate = jsc.delegate;

	if ([privateObject.type isEqualToString:@"@"])
	{
		//
		// Delegate canSetProperty, setProperty
		//
		if (delegate)
		{
			// Check if setting is allowed
			if ([delegate respondsToSelector:@selector(JSCocoa:canSetProperty:ofObject:toValue:inContext:exception:)])
			{
				BOOL canSet = [delegate JSCocoa:jsc canSetProperty:propertyName ofObject:privateObject.object toValue:jsValue inContext:ctx exception:exception];
				if (!canSet)
				{
					if (!*exception)	throwException(ctx, exception, [NSString stringWithFormat:@"Delegate does not allow setting %@.%@", privateObject.object, propertyName]);
					return	NULL;
				}
			}
			// Check if delegate handles getting
			if ([delegate respondsToSelector:@selector(JSCocoa:setProperty:ofObject:toValue:inContext:exception:)])
			{
				BOOL delegateSet = [delegate JSCocoa:jsc setProperty:propertyName ofObject:privateObject.object toValue:jsValue inContext:ctx exception:exception];
				if (delegateSet)	return	true;
			}
		}

		// Special case for NSMutableArray set
//		if ([privateObject.object isKindOfClass:[NSArray class]])
		if ([privateObject.object respondsToSelector:@selector(replaceObjectAtIndex:withObject:)])
		{
			id array	= privateObject.object;
//			if (![array respondsToSelector:@selector(replaceObjectAtIndex:withObject:)])	return	throwException(ctx, exception, @"Calling set on a non mutable array"), false;
			id scan		= [NSScanner scannerWithString:propertyName];
			NSInteger propertyIndex;
			// Is asked property an int ?
			BOOL convertedToInt =  ([scan scanInteger:&propertyIndex]);
			if (convertedToInt && [scan isAtEnd])
			{
				if (propertyIndex < 0 || propertyIndex >= [array count])	return	false;

				id property = NULL;
				if ([JSCocoaFFIArgument unboxJSValueRef:jsValue toObject:&property inContext:ctx])
				{
					[array replaceObjectAtIndex:propertyIndex withObject:property];
					return	true;
				}
				else	return false;
			}
		}


		// Special case for NSMutableDictionary set
//		if ([privateObject.object isKindOfClass:[NSDictionary class]])
		if ([privateObject.object respondsToSelector:@selector(setObject:forKey:)])
		{
			id dictionary	= privateObject.object;
//			if (![dictionary respondsToSelector:@selector(setObject:forKey:)])	return	throwException(ctx, exception, @"Calling set on a non mutable dictionary"), false;

			id property = NULL;
			if ([JSCocoaFFIArgument unboxJSValueRef:jsValue toObject:&property inContext:ctx])
			{
				[dictionary setObject:property forKey:propertyName];
				return	true;
			}
			else	return false;
		}

		
		// Special case for JSCocoaMemoryBuffer get
		if ([privateObject.object isKindOfClass:[JSCocoaMemoryBuffer class]])
		{
			id buffer = privateObject.object;
			
			id scan		= [NSScanner scannerWithString:propertyName];
			NSInteger propertyIndex;
			// Is asked property an int ?
			BOOL convertedToInt =  ([scan scanInteger:&propertyIndex]);
			if (convertedToInt && [scan isAtEnd])
			{
				if (propertyIndex < 0 || propertyIndex >= [buffer typeCount])	return	NULL;
				return	[buffer setValue:jsValue atIndex:propertyIndex inContext:ctx];
			}
		}
		
		
		
		// Try shorthand overload : obc[selector] = function
		id callee	= [privateObject object];
		if ([propertyName rangeOfString:@":"].location != NSNotFound)
		{
			JSValueRefAndContextRef v = { jsValue, ctx };
			[JSCocoaController overloadInstanceMethod:propertyName class:[callee class] jsFunction:v];
			return	true;
		}
		
		
		// Can't use capitalizedString on the whole string as it will transform 
		//			myValue 
		// to		Myvalue (thereby destroying camel letters)
		// we want	MyValue

		// Capitalize only first letter
		NSString*	setterName = [NSString stringWithFormat:@"set%@%@:", 
											[[propertyName substringWithRange:NSMakeRange(0,1)] capitalizedString], 
											[propertyName substringWithRange:NSMakeRange(1, [propertyName length]-1)]];

		//
		// Attempt Zero arg autocall for setter
		// Object.alloc().init() -> Object.alloc.init
		//
		SEL sel		= NSSelectorFromString(setterName);
		if ([callee respondsToSelector:sel])
		{
			//
			// Delegate canCallMethod, callMethod
			//
			if (delegate)
			{
				// Check if calling is allowed
				if ([delegate respondsToSelector:@selector(JSCocoa:canCallMethod:ofObject:argumentCount:arguments:inContext:exception:)])
				{
					BOOL canCall = [delegate JSCocoa:jsc canCallMethod:setterName ofObject:callee argumentCount:0 arguments:NULL inContext:ctx exception:exception];
					if (!canCall)
					{
						if (!*exception)	throwException(ctx, exception, [NSString stringWithFormat:@"Delegate does not allow calling [%@ %@]", callee, setterName]);
						return	NULL;
					}
				}
				// Check if delegate handles calling
				if ([delegate respondsToSelector:@selector(JSCocoa:callMethod:ofObject:privateObject:argumentCount:arguments:inContext:exception:)])
				{
					JSValueRef delegateCall = [delegate JSCocoa:jsc callMethod:setterName ofObject:callee privateObject:privateObject argumentCount:0 arguments:NULL inContext:ctx exception:exception];
					if (delegateCall)	return	!!delegateCall;
				}
			}

			// Get method pointer
			Method method = class_getInstanceMethod([callee class], sel);
			if (!method)	method = class_getClassMethod([callee class], sel);
			
			// If we didn't find a method, try Distant Object
			if (!method)
			{
				// Last chance before exception : try calling DO
				BOOL b = [jsc JSCocoa:jsc setProperty:propertyName ofObject:callee toValue:jsValue inContext:ctx exception:exception];
				if (b)	return	YES;
				
				throwException(ctx, exception, [NSString stringWithFormat:@"Could not set property[%@ %@]", callee, propertyName]);
				return	NULL;
			}
			
			// Extract arguments
			const char* typeEncoding = method_getTypeEncoding(method);
			id argumentEncodings = [JSCocoaController parseObjCMethodEncoding:typeEncoding];
			if ([[argumentEncodings objectAtIndex:0] typeEncoding] != 'v')	return	throwException(ctx, exception, [NSString stringWithFormat:@"(in setter) %@ must return void", setterName]), false;

			// Call address
			void* callAddress = getObjCCallAddress(argumentEncodings);
			
			//
			// ffi data
			//
			ffi_cif		cif;
			ffi_type*	args[3];
			void*		values[3];
			char*		selector;

			selector	= (char*)NSSelectorFromString(setterName);
			args[0]		= &ffi_type_pointer;
			args[1]		= &ffi_type_pointer;
			values[0]	= (void*)&callee;
			values[1]	= (void*)&selector;

			// Get arg (skip return value, instance, selector)
			JSCocoaFFIArgument*	arg		= [argumentEncodings objectAtIndex:3];
			BOOL	converted = [arg fromJSValueRef:jsValue inContext:ctx];
			if (!converted)		return	throwException(ctx, exception, [NSString stringWithFormat:@"(in setter) Argument %c not converted", [arg typeEncoding]]), false;
			args[2]		= [arg ffi_type];
			values[2]	= [arg storage];
			
			// Setup ffi
			ffi_status prep_status	= ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 3, &ffi_type_void, args);
			//
			// Call !
			//
			if (prep_status == FFI_OK)
			{
				ffi_call(&cif, callAddress, NULL, values);
			}
			return	true;
		}
		
		if ([callee respondsToSelector:@selector(setJSValue:forJSName:)])
		{
			// Set as instance variable
//			BOOL set = [callee setJSValue:jsValue forJSName:propertyNameJS];
			JSValueRefAndContextRef value = { JSValueMakeNull(ctx), ctx };
			value.value = jsValue;

			JSValueRefAndContextRef	name = { JSValueMakeNull(ctx), ctx } ;
			name.value = JSValueMakeString(ctx, propertyNameJS);
			BOOL set = [callee setJSValue:value forJSName:name];
			if (set)	return	true;
		}
	}

	// External WebView value
	if ([privateObject.type isEqualToString:@"externalJSValueRef"] || [[privateObject rawPointerEncoding] isEqualToString:@"^{OpaqueJSContext=}"])
	{
		JSValueRef externalValue = [privateObject jsValueRef];
		JSContextRef externalCtx = externalValue ? [privateObject ctx] : [privateObject rawPointer];
		JSObjectRef externalObject = externalValue ? JSValueToObject(externalCtx, externalValue, NULL) : JSContextGetGlobalObject(externalCtx);
		if (!externalObject)	return	false;

		JSValueRef convertedValue = valueToExternalContext(ctx, jsValue, externalCtx);
		JSObjectSetProperty(externalCtx, externalObject, propertyNameJS, convertedValue, kJSPropertyAttributeNone, exception);

		// If WebView had an exception, re-throw it in our context
		if (exception && *exception)	
		{
			id s = [JSCocoaController formatJSException:*exception inContext:externalCtx];
			throwException(ctx, exception, [NSString stringWithFormat:@"(WebView) %@", s]);
			return false;
		}
		
		return	true;
	}

	//
	// From here we return false to have Javascript set values on Javascript objects : valueOf, thisObject, structures
	//

	// Special case for autocall : allow current js object to receive a custom valueOf method that will handle autocall
	// And a thisObject property holding class for instance autocall
	if ([propertyName isEqualToString:@"valueOf"])			return	false;
	// An out argument allocates pointer storage when calling stuff like gl version.
	// JSCocoa needs to set a custom javascript property to recognize out arguments.
	if ([propertyName isEqualToString:@"isOutArgument"])	return	false;
	// Allow general setting on structs
	if ([privateObject.type isEqualToString:@"struct"])		return	false;
	
	// Don't throw an exception if setting is allowed
	if ([jsc canSetOnBoxedObjects])							return	false;

	// Setter fails AND WARNS if propertyName can't be set
	// This happens of non-JSCocoa ObjC objects, eg NSWorkspace.sharedWorspace.someVariable = value
	return	throwException(ctx, exception, [NSString stringWithFormat:@"(in setter) object %@ does not support setting — Derive from that class to make it able to host any Javascript object ", privateObject.object]), false;
}


//
// deleteProperty
//	delete property in hash
//
static bool jsCocoaObject_deleteProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef* exception)
{
	NSString*	propertyName = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS);
	[NSMakeCollectable(propertyName) autorelease];
	
	JSCocoaPrivateObject* privateObject = JSObjectGetPrivate(object);

	if (![privateObject.type isEqualToString:@"@"])	return false;

	id callee	= [privateObject object];
	if (![callee respondsToSelector:@selector(setJSValue:forJSName:)])	return	false;
	JSValueRefAndContextRef	name = { JSValueMakeNull(ctx), ctx } ;
	name.value = JSValueMakeString(ctx, propertyNameJS);
	return [callee deleteJSValueForJSName:name];
}


//
// getPropertyNames
//	enumerate dictionary keys
//
static void jsCocoaObject_getPropertyNames(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames)
{
	JSCocoaPrivateObject* privateObject = JSObjectGetPrivate(object);

	// If we have a dictionary, add keys from allKeys
	if ([privateObject.type isEqualToString:@"@"])
	{
		id o = privateObject.object;
		// Vend property only for classes
		if (o == [o class])
		{
			JSStringRef jsString = JSStringCreateWithUTF8CString(RuntimeInformationPropertyName);
			JSPropertyNameAccumulatorAddName(propertyNames, jsString);
			JSStringRelease(jsString);			
		}
		if ([o isKindOfClass:[NSDictionary class]])
		{
			id dictionary	= privateObject.object;
			id keys			= [dictionary allKeys];
			
			for (id key in keys)
			{
				JSStringRef jsString = JSStringCreateWithUTF8CString([key UTF8String]);
				JSPropertyNameAccumulatorAddName(propertyNames, jsString);
				JSStringRelease(jsString);			
			}
		}
	}
}



//
// callAsFunction 
//	done in two methods. 
//	jsCocoaObject_callAsFunction is called first and handles 
//		* C and ObjC calls : calls jsCocoaObject_callAsFunction_ffi
//		* Super call : in a derived ObjC class method, call this.Super(arguments) to call the parent method with jsCocoaObject_callAsFunction_ffi
//		* js function calls : on an ObjC class, use of pure js functions as methods
//		* toString, valueOf
//
//	jsCocoaObject_callAsFunction_ffi calls a C function or an ObjC method with provided arguments.
//

// This uses libffi to call C and ObjC.
static JSValueRef jsCocoaObject_callAsFunction_ffi(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, JSValueRef arguments[], JSValueRef* exception, NSString* superSelector, Class superSelectorClass, BOOL isVariadic, JSValueRef** argumentsToFree)
{
	JSCocoaPrivateObject* privateObject		= JSObjectGetPrivate(function);
	JSCocoaPrivateObject* thisPrivateObject = JSObjectGetPrivate(thisObject);

	// Return an exception if calling on NULL
	if (thisPrivateObject.object == NULL && !privateObject.xml)
		return	throwException(ctx, exception, @"jsCocoaObject_callAsFunction : call with null object"), NULL;

	// Function address
	void* callAddress = NULL;

	// Number of arguments of called method or function
	NSUInteger callAddressArgumentCount = 0;

	// Arguments encoding
	// Holds return value encoding as first element
	NSMutableArray*	argumentEncodings = nil;

	// Calling ObjC ? If NO, we're calling C
	BOOL	callingObjC = NO;
	// Structure return (objc_msgSend_stret)
	BOOL	usingStret	= NO;
	// Calling instance... , replaced with init... and released, making the js object sole owner
	BOOL	callingInstance	= NO;


	// Get delegate
	JSCocoaController* jsc = [JSCocoaController controllerFromContext:ctx];
	id delegate = jsc.delegate;

	//
	// ObjC setup
	//
	id callee = NULL, methodName = NULL, functionName = NULL;
	
	// Calls can be made on boxed ObjC objects AND JSCocoaPrivateObjects
	if ([privateObject.type isEqualToString:@"method"] && ([thisPrivateObject.type isEqualToString:@"@"] || [thisPrivateObject.object class] == [JSCocoaPrivateObject class]))
	{
		callingObjC	= YES;
		callee		= [thisPrivateObject object];
		methodName	= superSelector ? superSelector : [NSMutableString stringWithString:privateObject.methodName];
//		NSLog(@"calling %@.%@", callee, methodName);

		//
		// Delegate canCallMethod, callMethod
		//	Called first so it gets a chance to do handle custom messages
		//
		if (delegate)
		{
			// Check if calling is allowed
			if ([delegate respondsToSelector:@selector(JSCocoa:canCallMethod:ofObject:argumentCount:arguments:inContext:exception:)])
			{
				BOOL canCall = [delegate JSCocoa:jsc canCallMethod:methodName ofObject:callee argumentCount:argumentCount arguments:arguments inContext:ctx exception:exception];
				if (!canCall)
				{
					if (!*exception)	throwException(ctx, exception, [NSString stringWithFormat:@"Delegate does not allow calling [%@ %@]", callee, methodName]);
					return	NULL;
				}
			}
			// Check if delegate handles calling
			if ([delegate respondsToSelector:@selector(JSCocoa:callMethod:ofObject:privateObject:argumentCount:arguments:inContext:exception:)])
			{
				JSValueRef delegateCall = [delegate JSCocoa:jsc callMethod:methodName ofObject:callee privateObject:thisPrivateObject argumentCount:argumentCount arguments:arguments inContext:ctx exception:exception];
				if (delegateCall)	return	delegateCall;
			}
		}
		// Special case for alloc autocall — do not retain alloced result as it might crash (eg [[NSLocale alloc] retain] fails in ObjC)
		if (![jsc useAutoCall] && argumentCount == 0 && [methodName isEqualToString:@"alloc"])
		{
			id allocatedObject = [callee alloc];
//			JSObjectRef jsObject = [JSCocoaController jsCocoaPrivateObjectInContext:ctx];
			JSObjectRef jsObject = [jsc newPrivateObject];
			JSCocoaPrivateObject* private = JSObjectGetPrivate(jsObject);
			private.type = @"@";
			[private setObjectNoRetain:allocatedObject];
			return	jsObject;		
		}
		

		// Instance call
/*
		if ([callee class] == callee && [methodName isEqualToString:@"instance"])
		{
			if (argumentCount > 1)	return	throwException(ctx, exception, @"Invalid argument count in instance call : must be 0 or 1"), NULL;
			return	[callee instanceWithContext:ctx argumentCount:argumentCount arguments:arguments exception:exception];
		}
*/
		// Check selector
		if (![callee respondsToSelector:NSSelectorFromString(methodName)])
		{
			//
			// Split call
			//	set( { value : '5', forKey : 'hello' } )
			//	-> setValue:forKey:
			//
			if ([jsc useSplitCall])
			{
				id			splitMethodName		= privateObject.methodName;
				id class = [callee class];
				if (callee == class)
					class = objc_getMetaClass(object_getClassName(class));
				BOOL isSplitCall = [JSCocoaController trySplitCall:&splitMethodName class:class argumentCount:&argumentCount arguments:&arguments ctx:ctx];
				if (isSplitCall)		
				{
					methodName = splitMethodName;
					// trySplitCall returned new arguments that we'll need to free later on
					*argumentsToFree = arguments;
				}
			}
		}

		// Get method pointer
		Method method = class_getInstanceMethod([callee class], NSSelectorFromString(methodName));
		if (!method)	method = class_getClassMethod([callee class], NSSelectorFromString(methodName));

		// If we didn't find a method, try an instance call, then try treating object as Javascript string, then try Distant Object
		if (!method)
		{
			// Instance Check
			if ([methodName hasPrefix:@"instance"])
			{
				id initMethodName = [NSString stringWithFormat:@"init%@", [methodName substringFromIndex:8]];
				id class		= [callee class];
				method			= class_getInstanceMethod(class, NSSelectorFromString(initMethodName));
				methodName		= initMethodName;
				callee			= [class alloc];
				callingInstance	= YES;
			}
			
			if (!method)
			{
				// (First) Last chance before exception : try treating callee as a Javascript string
				if ([callee isKindOfClass:[NSString class]])
				{
					id script = [NSString stringWithFormat:@"String.prototype.%@", methodName];
					JSStringRef	jsScript = JSStringCreateWithUTF8CString([script UTF8String]);
					JSValueRef result = JSEvaluateScript(ctx, jsScript, NULL, NULL, 1, NULL);
					JSStringRelease(jsScript);
					if (result && JSValueGetType(ctx, result) == kJSTypeObject)
					{
						JSStringRef string = JSStringCreateWithCFString((CFStringRef)callee);
						JSValueRef stringValue = JSValueMakeString(ctx, string);
						JSStringRelease(string);

						JSObjectRef functionObject = JSValueToObject(ctx, result, NULL);
						JSObjectRef jsThisObject = JSValueToObject(ctx, stringValue, NULL);
						JSValueRef r =	JSObjectCallAsFunction(ctx, functionObject, jsThisObject, argumentCount, arguments, NULL);
						return	r;
					}
				}
				
				// Last chance before exception : try calling DO
				JSValueRef res = [jsc JSCocoa:jsc callMethod:methodName ofObject:callee privateObject:thisPrivateObject argumentCount:argumentCount arguments:arguments inContext:ctx exception:exception];
				if (res)	return	res;
				
				return	throwException(ctx, exception, [NSString stringWithFormat:@"jsCocoaObject_callAsFunction : method %@ of object %@ not found — remnant of a split call ?", methodName, [callee class]]), NULL;
			}
		}
		
		// Extract arguments
		const char* typeEncoding = method_getTypeEncoding(method);
//		NSLog(@"method %@ encoding=%s", methodName, typeEncoding);
		argumentEncodings = [JSCocoaController parseObjCMethodEncoding:typeEncoding];
		if (!argumentEncodings) {
			return	throwException(ctx, exception, [NSString stringWithFormat:@"jsCocoaObject_callAsFunction could not parse type encodings %s of [%@ %@]", [JSCocoa typeEncodingOfMethod:methodName class:[[callee class] description]], methodName, [callee class]]), NULL;
		}
		// Function arguments is all arguments minus return value and [instance, selector] params to objc_send
		callAddressArgumentCount = [argumentEncodings count]-3;

		// Get call address
		callAddress = getObjCCallAddress(argumentEncodings);
	}

	//
	// C setup
	//
	if (!callingObjC)
	{
		if (!privateObject.xml)	return	throwException(ctx, exception, @"jsCocoaObject_callAsFunction : no xml in object = nothing to call (Autocall problem ? To call argless objCobject.method(), remove the parens if autocall is ON)") , NULL;
//		NSLog(@"C encoding=%@", privateObject.xml);
		argumentEncodings = [JSCocoaController parseCFunctionEncoding:privateObject.xml functionName:&functionName];
		// Grab symbol
		callAddress = dlsym(RTLD_DEFAULT, [functionName UTF8String]);
		if (!callAddress)	return	throwException(ctx, exception, [NSString stringWithFormat:@"Function %@ not found", functionName]), NULL;
		// Function arguments is all arguments minus return value
		callAddressArgumentCount = [argumentEncodings count]-1;

		//
		// Delegate canCallFunction
		//
		if (delegate)
		{
			// Check if calling is allowed
			if ([delegate respondsToSelector:@selector(JSCocoa:canCallFunction:argumentCount:arguments:inContext:exception:)])
			{
				BOOL canCall = [delegate JSCocoa:jsc canCallFunction:functionName argumentCount:argumentCount arguments:arguments inContext:ctx exception:exception];
				if (!canCall)
				{
					if (!*exception)	throwException(ctx, exception, [NSString stringWithFormat:@"Delegate does not allow calling function %@", functionName]);
					return	NULL;
				}
			}
		}
	}
	
	//
	// Variadic call ?
	//	If argument count doesn't match descripted argument count, 
	//	we may have a variadic call
	//
	// Possibly account for a missing terminating NULL in ObjC variadic method
	//		-> allows calling 
	//			[NSArray arrayWithObjects:'hello', 'world']
	//		instead of
	//			[NSArray arrayWithObjects:'hello', 'world', null]
	//
	BOOL sugarCheckVariadic = NO;
	// Check if selector or method names matches a known variadic method. This may be a false positive ...
	if (isVariadic)	
	{
		// ... so we check further.
		if (methodName)		isVariadic = [[JSCocoaController controllerFromContext:ctx] isMethodVariadic:methodName class:[callee class]];
		else				isVariadic = [[JSCocoaController controllerFromContext:ctx] isFunctionVariadic:functionName];
		
		// Bail if not variadic
		if (!isVariadic)
		{
			return	throwException(ctx, exception, [NSString stringWithFormat:@"Bad argument count in %@ : expected %d, got %d", functionName ? functionName : methodName,	callAddressArgumentCount, argumentCount]), NULL;
		}
		// Sugar check : if last object is not NULL, account for it
		if (isVariadic && callingObjC && argumentCount && !JSValueIsNull(ctx, arguments[argumentCount-1]))
		{
			// Will be tested during argument conversion
			sugarCheckVariadic = YES;
			argumentCount++;
		}
	}
	else
	{
		if (callAddressArgumentCount != argumentCount)
		{
			return	throwException(ctx, exception, [NSString stringWithFormat:@"Bad argument count in %@ : expected %d, got %d", functionName ? functionName : methodName,	callAddressArgumentCount, argumentCount]), NULL;
		}
	}

	//
	// ffi data
	//
	ffi_cif		cif;
	ffi_type**	args	= NULL;
	void**		values	= NULL;
	char*		selector;
	// super call
	struct		objc_super _super;
	void*		superPointer;
	
	// Total number of arguments to ffi_call
	NSUInteger	effectiveArgumentCount = argumentCount + (callingObjC ? 2 : 0);
	if (effectiveArgumentCount > 0)
	{
		args = malloc(sizeof(ffi_type*)*effectiveArgumentCount);
		values = malloc(sizeof(void*)*effectiveArgumentCount);

		// If calling ObjC, setup instance and selector
		int		i, idx = 0;
		if (callingObjC)
		{
			selector	= (char*)NSSelectorFromString(methodName);
			args[0]		= &ffi_type_pointer;
			args[1]		= &ffi_type_pointer;
			values[0]	= (void*)&callee;
			values[1]	= (void*)&selector;
			idx = 2;
			
			// Super handling
			if (superSelector)
			{
				if (superSelectorClass == nil)	return	throwException(ctx, exception, [NSString stringWithFormat:@"Null superclass in %@", callee]), NULL;
				callAddress = objc_msgSendSuper;
				if (usingStret)	callAddress = objc_msgSendSuper_stret;
				_super.receiver = callee;
#if __LP64__
				_super.super_class	= superSelectorClass;
//#elif TARGET_IPHONE_SIMULATOR || !TARGET_OS_IPHONE
//				_super.class	= superSelectorClass;
#else			
				_super.super_class	= superSelectorClass;
#endif			
				superPointer	= &_super;
				values[0]		= &superPointer;
//				NSLog(@"superClass=%@ (old=%@) (%@) function=%p", superSelectorClass, [callee superclass], [callee class], function);
			}
		}

		// Setup arguments, unboxing or converting data
		for (i=0; i<argumentCount; i++, idx++)
		{
			// All variadic arguments are treated as ObjC objects (@)
			JSCocoaFFIArgument*	arg;
			if (isVariadic && i >= callAddressArgumentCount)
			{
				arg = [[JSCocoaFFIArgument alloc] init];
				[arg setTypeEncoding:'@'];
				[arg autorelease];
			}
			else
				arg		= [argumentEncodings objectAtIndex:idx+1];

			// Convert argument
			JSValueRef			jsValue	= sugarCheckVariadic && i == argumentCount-1 ? JSValueMakeNull(ctx) : arguments[i];
			BOOL	shouldConvert = YES;
			// Check type o modifiers
			if ([arg typeEncoding] == '^')
			{
				// If holding a JSCocoaOutArgument, allocate custom storage
				if (JSValueGetType(ctx, jsValue) == kJSTypeObject)
				{
					JSStringRef	jsName = JSStringCreateWithUTF8CString("isOutArgument");
					BOOL isOutArgument = JSValueToBoolean(ctx, JSObjectGetProperty(ctx, JSValueToObject(ctx, jsValue, NULL), jsName, NULL));
					JSStringRelease(jsName);
					if (isOutArgument)
					{
						id unboxed = nil;
						[JSCocoaFFIArgument unboxJSValueRef:jsValue toObject:&unboxed inContext:ctx];
						if (unboxed && [unboxed isKindOfClass:[JSCocoaOutArgument class]])
						{
							if (![(JSCocoaOutArgument*)unboxed mateWithJSCocoaFFIArgument:arg])	return	throwException(ctx, exception, [NSString stringWithFormat:@"Pointer argument %@ not handled", [arg pointerTypeEncoding]]), NULL;
							shouldConvert = NO;
							[arg setIsOutArgument:YES];
						}
						if (unboxed && [unboxed isKindOfClass:[JSCocoaMemoryBuffer class]])
						{
							JSCocoaMemoryBuffer* buffer = unboxed;
							[arg setTypeEncoding:[arg typeEncoding] withCustomStorage:[buffer pointerForIndex:0]];
							shouldConvert = NO;
							[arg setIsOutArgument:YES];
						}
					}
				}

				if (shouldConvert)
				{
					// Allocate default storage
					[arg allocateStorage];
				}
					
			}

			args[idx]		= [arg ffi_type];
			if (shouldConvert)
			{
				BOOL	converted = [arg fromJSValueRef:jsValue inContext:ctx];
				if (!converted)		
					return	throwException(ctx, exception, [NSString stringWithFormat:@"Argument %c not converted", [arg typeEncoding]]), NULL;
			}
			values[idx]		= [arg storage];
		}
	}
	
	// Get return value holder
	id returnValue = [argumentEncodings objectAtIndex:0];
	
	// Allocate return value storage if it's a pointer
	if ([returnValue typeEncoding] == '^')
		[returnValue allocateStorage];

	// Setup ffi
	ffi_status prep_status	= ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)effectiveArgumentCount, [returnValue ffi_type], args);

	//
	// Call !
	//
	if (prep_status == FFI_OK)
	{
		void* storage = [returnValue storage];
		if ([returnValue ffi_type] == &ffi_type_void)	storage = NULL;

		// Catch exceptions when calling ObjC
		if (callingObjC)
		{
			@try 
			{
				ffi_call(&cif, callAddress, storage, values);
			}
			@catch (NSException* e) 
			{
				if (effectiveArgumentCount > 0)	
				{
					free(args);
					free(values);
				}
				[JSCocoaFFIArgument boxObject:e toJSValueRef:exception inContext:ctx];
				return	NULL;
			}
		}
		else
			ffi_call(&cif, callAddress, storage, values);
	}
	
	if (effectiveArgumentCount > 0)	
	{
		free(args);
		free(values);
	}
	if (prep_status != FFI_OK)	return	throwException(ctx, exception, @"ffi_prep_cif failed"), NULL;
	
	// Return now if our function returns void
	// Return null as a JSValueRef to avoid crashing
	if ([returnValue ffi_type] == &ffi_type_void)	return	JSValueMakeNull(ctx);

	// Else, convert return value
	JSValueRef	jsReturnValue = NULL;
	BOOL converted = [returnValue toJSValueRef:&jsReturnValue inContext:ctx];
	if (!converted)	return	throwException(ctx, exception, [NSString stringWithFormat:@"Return value not converted in %@", methodName?methodName:functionName]), NULL;
	
	// Instance call : release object to make js object sole owner
	if (callingInstance)
	{
		JSCocoaPrivateObject* private = JSObjectGetPrivate(JSValueToObject(ctx, jsReturnValue, NULL));
		[private.object release];
	}

	return	jsReturnValue;
}

//
// This method handles
//		* C and ObjC calls
//		* Super call : retrieves the method name to call, thereby giving new arguments to jsCocoaObject_callAsFunction_ffi
//		* js function calls : on an ObjC class, use of pure js functions as methods
//		* toString, valueOf
//
static JSValueRef jsCocoaObject_callAsFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
	JSCocoaPrivateObject* privateObject		= JSObjectGetPrivate(function);
	JSValueRef*	superArguments	= NULL;
	id	superSelector			= NULL;
	id	superSelectorClass		= NULL;

	// Pure JS functions for derived ObjC classes
	if ([privateObject jsValueRef])
	{
		if ([privateObject.type isEqualToString:@"jsFunction"])
		{
			JSObjectRef jsFunction = JSValueToObject(ctx, [privateObject jsValueRef], NULL);
			JSValueRef ret = JSObjectCallAsFunction(ctx, jsFunction, thisObject, argumentCount, arguments, exception);
			return	ret;
		}
		else
		if ([privateObject.type isEqualToString:@"externalJSValueRef"])
		{
			JSContextRef externalCtx = [privateObject ctx];
			JSObjectRef jsFunction = JSValueToObject(externalCtx, [privateObject jsValueRef], NULL);
			if (!jsFunction)
			{
				throwException(ctx, exception, [NSString stringWithFormat:@"WebView call : value not a function"]);
				return JSValueMakeNull(ctx);
			}

			// Retrieve 'this' : either the global external object (window), or a result from previous calll
			JSObjectRef externalThisObject;
			JSCocoaPrivateObject* privateThis		= JSObjectGetPrivate(thisObject);
			if ([privateThis jsValueRef])	externalThisObject = JSValueToObject(externalCtx, [privateThis jsValueRef], NULL);
			else							externalThisObject = JSContextGetGlobalObject(externalCtx);

			if (!externalThisObject)
			{
				throwException(ctx, exception, [NSString stringWithFormat:@"WebView call : externalThisObject not found"]);
				return JSValueMakeNull(ctx);
			}
			
			// Convert arguments to WebView context
			JSValueRef* convertedArguments = NULL;
			if (argumentCount) convertedArguments = malloc(sizeof(JSValueRef)*argumentCount);
			for (int i=0; i<argumentCount; i++)
				convertedArguments[i] = valueToExternalContext(ctx, arguments[i], externalCtx);

			// Call
			JSValueRef ret = JSObjectCallAsFunction(externalCtx, jsFunction, externalThisObject, argumentCount, convertedArguments, exception);
			if (convertedArguments) free(convertedArguments);

			// If WebView had an exception, re-throw it in our context
			if (exception && *exception)	
			{
				id s = [JSCocoaController formatJSException:*exception inContext:externalCtx];
				throwException(ctx, exception, [NSString stringWithFormat:@"(WebView) %@", s]);
				return JSValueMakeNull(ctx);
			}

			// Box result from WebView
			return boxedValueFromExternalContext(externalCtx, ret, ctx);
		}
	}

	// Javascript custom methods
	id methodName = privateObject.methodName;
	
	BOOL isVariadic = NO;
	// Possible optimization if more custom methods are handled
	if ([customCallPaths valueForKey:methodName])
	{
		if ([methodName isEqualToString:@"toString"] || [methodName isEqualToString:@"valueOf"])
		{
			JSValueRef jsValue = valueOfCallback(ctx, function, thisObject, 0, NULL, NULL);
			if ([privateObject.methodName isEqualToString:@"toString"])	
			{
				JSStringRef str = JSValueToStringCopy(ctx, jsValue, NULL);
				JSValueRef ret = JSValueMakeString(ctx, str);
				JSStringRelease(str);
				return ret;
			}
			return	jsValue;
		}
		
		//
		// Super/Swizzled handling : get method name and move js arguments to C array
		//
		//	call this.Super(arguments) to call parent method
		//	call this.Original(arguments) to call swizzled method
		//
		if ([methodName isEqualToString:@"Super"] || [methodName isEqualToString:@"Original"])
		{
			methodName = privateObject.methodName;
			BOOL callingSwizzled = [methodName isEqualToString:@"Original"];
			if (argumentCount != 1 && argumentCount != 3)	return	throwException(ctx, exception, [NSString stringWithFormat:@"%@ wants (arguments) or (arguments, selector, argarray)", methodName]), NULL;
			size_t originalArgumentCount = argumentCount;

			// Get argument object
			JSObjectRef argumentObject = JSValueToObject(ctx, arguments[argumentCount == 3 ? 2 : 0], NULL);
			
			// Get argument count
			JSStringRef	jsLengthName = JSStringCreateWithUTF8CString("length");
			JSValueRef	jsLength = JSObjectGetProperty(ctx, argumentObject, jsLengthName, NULL);
			JSStringRelease(jsLengthName);
			if (JSValueGetType(ctx, jsLength) != kJSTypeNumber)	return	throwException(ctx, exception, [NSString stringWithFormat:@"%@ has no arguments", methodName]), NULL;
			
			int i, superArgumentCount = (int)JSValueToNumber(ctx, jsLength, NULL);
			if (superArgumentCount)
			{
				superArguments = malloc(sizeof(JSValueRef)*superArgumentCount);
				for (i=0; i<superArgumentCount; i++)
					superArguments[i] = JSObjectGetPropertyAtIndex(ctx, argumentObject, i, NULL);
			}

			argumentCount = superArgumentCount;
			
			// Get method name and associated class (need class for obj_msgSendSuper)
			if (originalArgumentCount == 3)
				argumentObject = JSValueToObject(ctx, arguments[0], NULL);

			JSStringRef	jsCalleeName = JSStringCreateWithUTF8CString("callee");
			JSValueRef	jsCalleeValue = JSObjectGetProperty(ctx, argumentObject, jsCalleeName, NULL);
			JSStringRelease(jsCalleeName);
			JSObjectRef jsCallee = JSValueToObject(ctx, jsCalleeValue, NULL);
			superSelector = [[JSCocoaController controllerFromContext:ctx] selectorForJSFunction:jsCallee];
			if (!superSelector)	
			{
				if (superArguments)		free(superArguments);
				if (callingSwizzled)	return	throwException(ctx, exception, @"Original couldn't find swizzled method"), NULL;
				return	throwException(ctx, exception, @"Super couldn't find parent method"), NULL;
			}
			superSelectorClass = [[[JSCocoaController controllerFromContext:ctx] classForJSFunction:jsCallee] superclass];

			// Retrieve selector for [super someMethod:...] call
			if (originalArgumentCount == 3)
			{
				JSStringRef resultStringJS = JSValueToStringCopy(ctx, arguments[1], NULL);
				superSelector = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
				[superSelector autorelease];
				JSStringRelease(resultStringJS);
				if (callingSwizzled)
					superSelector = [NSString stringWithFormat:@"%@%@", OriginalMethodPrefix, superSelector];
			}			
			
			// Swizzled handling : we're just changing the selector
			if (callingSwizzled)
			{
				if (![superSelector hasPrefix:OriginalMethodPrefix])
				{
					if (superArguments)		free(superArguments);
					return	throwException(ctx, exception, [NSString stringWithFormat:@"Original called on a non swizzled method (%@)", superSelector]), NULL;
				}
//				function = [JSCocoaController jsCocoaPrivateFunctionInContext:ctx];
				function = [[JSCocoa controllerFromContext:ctx] newPrivateFunction];
				JSCocoaPrivateObject* private = JSObjectGetPrivate(function);
				private.type		= @"method";
				private.methodName	= superSelector;
				
				superSelector		= NULL;
				superSelectorClass	= NULL;
			}
			
			// Don't call NSObject's safeDealloc as it doesn't exist
			if ([superSelector isEqualToString:@"safeDealloc"] && superSelectorClass == [NSObject class])
				return	JSValueMakeUndefined(ctx);
		}
		else
			isVariadic = YES;
	}

	JSValueRef* functionArguments	= superArguments ? superArguments : (JSValueRef*)arguments;
	JSValueRef*	argumentsToFree		= NULL;
	JSValueRef jsReturnValue = jsCocoaObject_callAsFunction_ffi(ctx, function, thisObject, argumentCount, functionArguments, exception, superSelector, superSelectorClass, isVariadic, &argumentsToFree);
	
	if (superArguments)		free(superArguments);
	if (argumentsToFree)	free(argumentsToFree);
	
	return	jsReturnValue;
}


//
// Creating new structures with Javascript's new operator
//
//	// Zero argument call : fill with undefined
//	var p = new NSRect					returns { origin : { x : undefined, y : undefined }, size : { width : undefined, height : undefined } }
//
//	// Initial values argument call : fills structure with arguments[] contents — THROWS exception if arguments.length != structure.elementCount 
//	var p = new NSRect(1, 2, 3, 4)		returns { origin : { x : 1, y : 2 }, size : { width : 3, height : 4 } }
//
static JSObjectRef jsCocoaObject_callAsConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception)
{
	JSCocoaPrivateObject* privateObject = JSObjectGetPrivate(constructor);
	if (!privateObject)		return throwException(ctx, exception, @"Calling set on a non mutable dictionary"), NULL;
	if (![[privateObject type] isEqualToString:@"struct"] || !privateObject.xml)		return throwException(ctx, exception, @"Calling constructor on a non struct"), NULL;

	// Get structure type
	id xmlDocument = [[NSXMLDocument alloc] initWithXMLString:privateObject.xml options:0 error:nil];
	id rootElement = [xmlDocument rootElement];
//	id structureType = [[rootElement attributeForName:@"type"] stringValue];
#if __LP64__	
	id structureType = [[rootElement attributeForName:@"type64"] stringValue];
	if (!structureType)	structureType = [[rootElement attributeForName:@"type"] stringValue];
#else
	id structureType = [[rootElement attributeForName:@"type"] stringValue];
#endif			
	// Retain the string as releasing xmlDocument deallocs it
	[[structureType retain] autorelease];

	[xmlDocument release];
	id fullStructureType = [JSCocoaFFIArgument structureFullTypeEncodingFromStructureTypeEncoding:structureType];
	if (!fullStructureType)	return throwException(ctx, exception, @"Calling constructor on a non struct"), NULL;

//	NSLog(@"Call as constructor structure %@ with %d arguments", fullStructureType, argumentCount);

	// Create Javascript object out of structure type
	JSValueRef	convertedStruct = NULL;
	NSInteger	convertedValueCount = 0;
	[JSCocoaFFIArgument structureToJSValueRef:&convertedStruct inContext:ctx fromCString:(char*)[fullStructureType UTF8String] fromStorage:nil initialValues:(JSValueRef*)arguments initialValueCount:argumentCount convertedValueCount:&convertedValueCount];

	// If constructor is called with arguments, make sure they are the correct amount to fill all structure slots
	if (argumentCount)
	{
		if (convertedValueCount != argumentCount)
		{
			return throwException(ctx, exception, [NSString stringWithFormat:@"Bad argument count when calling constructor on a struct : expected %d, got %d", convertedValueCount, argumentCount]), NULL;
		}
	}
	
	if (!convertedStruct)	return throwException(ctx, exception, @"Cound not instance structure"), NULL;
	return	JSValueToObject(ctx, convertedStruct, NULL);
}



//
// convertToType
//
static JSValueRef jsCocoaObject_convertToType(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception)
{
	// Only invoked when converting to strings and numbers.
	// Would have been useful to be called on BOOLs too, to avoid false positives of ('varname' in object) when varname may start a split call.
	
	// toString and valueOf conversions go through getProperty, at the end of the function.
	
	// Used on string conversions, eg jsHash[objcNSString] to convert objcNSString to a js string
	return	valueOfCallback(ctx, NULL, object, 0, NULL, NULL);
//	return	NULL;
}

static bool jsCocoaObject_hasInstance(JSContextRef ctx, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef* exception)
{
	return NO;
}








//
//
#pragma mark JavascriptCore __info object (ObjCInstanceOrClass._info returns runtime info)
//
//
static JSValueRef jsCocoaInfo_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef* exception)
{
	NSString*	propertyName = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS);
	[NSMakeCollectable(propertyName) autorelease];
	
	// Let default handler fetch this one
	if ([propertyName isEqualToString:@"className"])
		return NULL;

	JSStringRef classNameProperty = JSStringCreateWithUTF8CString("className");
	JSValueRef classNameJS = JSObjectGetProperty(ctx, object, classNameProperty, NULL);
	JSStringRelease(classNameProperty);
	
	id className = NSStringFromJSValue(ctx, classNameJS);
//	NSLog(@"className=%@", className);
	
	id class = objc_getClass([className UTF8String]);
	if (!class)
		return JSValueMakeUndefined(ctx);

/*
			JSObjectRef o = JSObjectMake(ctx, jsCocoaInfoClass, NULL);

			JSStringRef	classNameProperty	= JSStringCreateWithUTF8CString("className");
			JSStringRef	className			= JSStringCreateWithUTF8CString([[[[privateObject object] class] description] UTF8String]);
			JSObjectSetProperty(ctx, o, classNameProperty, JSValueMakeString(ctx, className), 
							kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontDelete, NULL);
			JSStringRelease(classNameProperty);
			JSStringRelease(className);
			return	o;

*/	
	if ([propertyName isEqualToString:@"own"])
	{

/*		
		JSObjectRef o = JSObjectMake(ctx, jsCocoaInfoClass, NULL);
		JSStringRef	classNameProperty	= JSStringCreateWithUTF8CString("className");
		JSStringRef	classNameJS			= JSStringCreateWithUTF8CString([className UTF8String]);
		JSObjectSetProperty(ctx, o, classNameProperty, JSValueMakeString(ctx, classNameJS), 
						kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontEnum|kJSPropertyAttributeDontDelete, NULL);
		JSStringRelease(classNameProperty);
		JSStringRelease(classNameJS);
*/
//		return	o;
	}
	id r = nil;
	if ([propertyName isEqualToString:@"image"])			r = [class __classImage];
	if ([propertyName isEqualToString:@"superclass"])		r = [class superclass];
	if ([propertyName isEqualToString:@"subclasses"])		r = [class __subclasses];
	if ([propertyName isEqualToString:@"methods"])			r = [class __methods];
	if ([propertyName isEqualToString:@"ancestry"])			r = [class __derivationPath];
	if ([propertyName isEqualToString:@"ivars"])			r = [class __ivars];
	if ([propertyName isEqualToString:@"properties"])		r = [class __properties];
	if ([propertyName isEqualToString:@"protocols"])		r = [class __protocols];

	if (r)
		return [[JSCocoa controllerFromContext:ctx] boxObject:r];
	return JSValueMakeUndefined(ctx);
}

static void jsCocoaInfo_getPropertyNames(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames)
{
	id names = [NSMutableArray arrayWithObjects:@"methods", @"ivars", @"properties", @"protocols", nil];
	
	JSStringRef scriptJS= JSStringCreateWithUTF8CString("return !!arguments[0].own  ? true : null");
	JSObjectRef fn		= JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
	JSValueRef result	= JSObjectCallAsFunction(ctx, fn, NULL, 1, (JSValueRef*)&object, NULL);
	JSStringRelease(scriptJS);
/*
	// ... use the function boxer
	JSObjectRef o; 
	if (JSValueIsBoolean(ctx, result))
		NSLog(@"isOwn");
	else
		NSLog(@"NOPE");
*/
	if (JSValueIsNull(ctx, result))
	{
		[names addObjectsFromArray:[NSArray arrayWithObjects:@"own", @"image", @"superclass", @"subclasses", @"ancestry", nil]];
	}

	
	for (id name in names)
	{
		JSStringRef jsString = JSStringCreateWithUTF8CString([name UTF8String]);
		JSPropertyNameAccumulatorAddName(propertyNames, jsString);
		JSStringRelease(jsString);			
	}
}


//
//
#pragma mark Global helpers
//
//

id	NSStringFromJSValue(JSContextRef ctx, JSValueRef value)
{
	if (JSValueIsNull(ctx, value))	return	nil;
	JSStringRef resultStringJS = JSValueToStringCopy(ctx, value, NULL);
	NSString* resultString = (NSString*)JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
	JSStringRelease(resultStringJS);
	return	[NSMakeCollectable(resultString) autorelease];
}

static void throwException(JSContextRef ctx, JSValueRef* exception, NSString* reason)
{
	// Don't speak and log here as the exception may be caught
	if ([[JSCocoa controllerFromContext:ctx] logAllExceptions]) {
		NSLog(@"JSCocoa exception : %@", reason);
//		if (isSpeaking)	system([[NSString stringWithFormat:@"say \"%@\" &", reason] UTF8String]);
	}

	// Gather call stack
	JSValueRef	callStackException	= NULL;
	JSStringRef scriptJS	= JSStringCreateWithUTF8CString("return dumpCallStack()");
	JSObjectRef fn			= JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 0, NULL);
	JSValueRef result		= JSObjectCallAsFunction(ctx, fn, NULL, 0, NULL, &callStackException);
	JSStringRelease(scriptJS);
	if (!callStackException) {
		// Convert call stack to string
		JSStringRef resultStringJS	= JSValueToStringCopy(ctx, result, NULL);
		NSString* callStack			= (NSString*)JSStringCopyCFString(kCFAllocatorDefault, resultStringJS);
		JSStringRelease(resultStringJS);
		[NSMakeCollectable(callStack) autorelease];

		// Append call stack to exception
		if ([callStack length])
			reason = [NSString stringWithFormat:@"%@\n%@", reason, callStack];
	}

	// Convert exception to string
	JSStringRef jsName	= JSStringCreateWithUTF8CString([reason UTF8String]);
	JSValueRef jsString	= JSValueMakeString(ctx, jsName);
	JSStringRelease(jsName);

	// Convert to object to allow JavascriptCore to add line and sourceURL
	*exception	= JSValueToObject(ctx, jsString, NULL);
}
/*
// Can't use in GC as data does not live until the end of the current run loop cycle
void* malloc_autorelease(size_t size)
{
	void*	p = malloc(size);
	[NSData dataWithBytesNoCopy:p length:size freeWhenDone:YES];
	return	p;
}
*/



//
// JSCocoa shorthand
//
@implementation JSCocoa
@end


//
// Boxed object cache
//
@implementation BoxedJSObject

- (void)setJSObject:(JSObjectRef)o {
	jsObject = o;
}
- (JSObjectRef)jsObject {
	return	jsObject;
}

- (id)description {
	id boxedObject = [(JSCocoaPrivateObject*)JSObjectGetPrivate(jsObject) object];
	id retainCount = [NSString stringWithFormat:@"%d", [boxedObject retainCount]];
#if !TARGET_OS_IPHONE
	retainCount = [NSGarbageCollector defaultCollector] ? @"Running GC" : [NSString stringWithFormat:@"%d", [boxedObject retainCount]];
#endif
	return [NSString stringWithFormat:@"<%@: %p holding %@ %@: %p (retainCount=%@)>",
				[self class], 
				self, 
				((id)self == (id)[self class]) ? @"Class" : @"",
				[boxedObject class],
				boxedObject,
				retainCount];
}

@end

