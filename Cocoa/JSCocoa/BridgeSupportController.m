//
//  BridgeSupportController.m
//  JSCocoa
//
//  Created by Patrick Geiller on 08/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "BridgeSupportController.h"


@implementation BridgeSupportController


+ (id)sharedController
{
	static id singleton;
	@synchronized(self)
	{
		if (!singleton)
			singleton = [[BridgeSupportController alloc] init];
		return singleton;
	}
	return singleton;
}

- (id)init
{
	self = [super init];
	
	paths				= [[NSMutableArray alloc] init];
	xmlDocuments		= [[NSMutableArray alloc] init];
	hash				= [[NSMutableDictionary alloc] init];
	variadicSelectors	= [[NSMutableDictionary alloc] init];
	variadicFunctions	= [[NSMutableDictionary alloc] init];
	
	return	self;
}

- (void)dealloc
{
	[variadicFunctions release];
	[variadicSelectors release];
	[hash release];
	[paths release];
	[xmlDocuments release];

	[super dealloc];
}

//
// Load a bridgeSupport file into a hash as { name : xmlTagString } 
//
- (BOOL)loadBridgeSupport:(NSString*)path
{
	NSError*	error = nil;
	/*
		Adhoc parser
			NSXMLDocument is too slow
			loading xml document as string then querying on-demand is too slow
			can't get CFXMLParserRef to work
			don't wan't to delve into expat
			-> ad hoc : load file, build a hash of { name : xmlTagString }
	*/
	NSString* xmlDocument = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if (error)	return	NSLog(@"loadBridgeSupport : %@", error), NO;

	char* c = (char*)[xmlDocument UTF8String];
#ifdef __OBJC_GC__
	char* originalC = c;
	[[NSGarbageCollector defaultCollector] disableCollectorForPointer:originalC];
#endif

//	double t0 = CFAbsoluteTimeGetCurrent();
	// Start parsing
	for (; *c; c++)
	{
		if (*c == '<')
		{
			char startTagChar = c[1];
			if (startTagChar == 0)	return	NO;

			// 'co'	constant
			// 'cl'	class
			// 'e'	enum
			// 'fu'	function
			// 'st'	struct
			if ((c[1] == 'c' && (c[2] == 'o' || c[2] == 'l')) || c[1] == 'e' || (c[1] == 'f' && c[2] == 'u') || (c[1] == 's' && c[2] == 't'))
			{
				// Extract name
				char* tagStart = c;
				for (; *c && *c != '\''; c++);
				c++;
				char* c0 = c;
				for (; *c && *c != '\''; c++);
				
				id name = [[NSString alloc] initWithBytes:c0 length:c-c0 encoding:NSUTF8StringEncoding];
				
				// Move to tag end
				BOOL foundEndTag = NO;
				BOOL foundOpenTag = NO;
				c++;
				for (; *c && !foundEndTag; c++)
				{
					if (*c == '<')			foundOpenTag = YES;
					else	
					if (*c == '/')
					{
						if (!foundOpenTag)
						{
							if(c[1] == '>')	foundEndTag = YES, c++;
						}
						else
						{
							if (startTagChar == c[1])	
							{
								foundEndTag = YES;
								// Skip to end of tag
								for (; *c && *c != '>'; c++);
							}
						}
					}
					else
					// Variadic parsing
					if (c[0] == 'v' && c[1] == 'a' && c[2] == 'r')
					{
						if (strncmp(c, "variadic", 8) == 0)
						{
							// Skip back to tag start
							c0 = c;
							for (; *c0 != '<'; c0--);

							// Tag name starts with 'm' : variadic method
							// <method variadic='true' selector='alertWithMessageText:defaultButton:alternateButton:otherButton:informativeTextWithFormat:' class_method='true'>
							if (c0[1] == 'm')
							{
								c = c0;
								id variadicMethodName = nil;
								// Extract selector name
								for (; *c != '>'; c++)
								{
									if (c[0] == ' ' && c[1] == 's' && c[2] == 'e' && c[3] == 'l')
									{
										for (; *c && *c != '\''; c++);
										c++;
										c0 = c;
										for (; *c && *c != '\''; c++);
										variadicMethodName = [[[NSString alloc] initWithBytes:c0 length:c-c0 encoding:NSUTF8StringEncoding] autorelease];
									}
								}
								[variadicSelectors setValue:@"true" forKey:variadicMethodName];
//								NSLog(@"SELECTOR %@", name);
							}
							else
							// Variadic function
							// <function name='NSBeginAlertSheet' variadic='true'>
							{
								[variadicFunctions setValue:@"true" forKey:name];
//								NSLog(@"function %@", name);
							}
						}
					}
				}
				
				c0 = tagStart;
				id value = [[NSString alloc] initWithBytes:c0 length:c-c0 encoding:NSUTF8StringEncoding];
	
				[hash setValue:value forKey:name];
				[value release];
				[name release];
			}
		}
	}
//	double t1 = CFAbsoluteTimeGetCurrent();
//	NSLog(@"BridgeSupport %@ parsed in %f", [[path lastPathComponent] stringByDeletingPathExtension], t1-t0);
#ifdef __OBJC_GC__
	[[NSGarbageCollector defaultCollector] enableCollectorForPointer:originalC];
#endif
	[paths addObject:path];
	[xmlDocuments addObject:xmlDocument];

	return	YES;
}


- (BOOL)isBridgeSupportLoaded:(NSString*)path
{
	NSUInteger idx = [self bridgeSupportIndexForString:path];
	return	idx == NSNotFound ? NO : YES;
}

//
// bridgeSupportIndexForString
//	given 'AppKit', return index of '/System/Library/Frameworks/AppKit.framework/Versions/C/Resources/BridgeSupport/AppKitFull.bridgesupport'
//
- (NSUInteger)bridgeSupportIndexForString:(NSString*)string
{
	NSUInteger i, l = [paths count];
	for (i=0; i<l; i++)
	{
		NSString* path = [paths objectAtIndex:i];
		NSRange range = [path rangeOfString:string];

		if (range.location != NSNotFound)	return	range.location;		
	}
	return	NSNotFound;
}

- (NSMutableDictionary*)variadicSelectors
{
	return variadicSelectors;
}

- (NSMutableDictionary*)variadicFunctions
{
	return variadicFunctions;
}

- (NSArray*)keys
{
	[hash removeObjectForKey:@"NSProxy"];
	[hash removeObjectForKey:@"NSProtocolChecker"];
	[hash removeObjectForKey:@"NSDistantObject"];
	
	return [hash allKeys];
}


- (NSString*)queryName:(NSString*)name
{
	return [hash valueForKey:name];
}
- (NSString*)queryName:(NSString*)name type:(NSString*)type
{
	id v = [self queryName:name];
	if (!v)	return	nil;
	
	char* c = (char*)[v UTF8String];
	// Skip tag start
	c++;
	char* c0 = c;
	for (; *c && *c != ' '; c++);
	id extractedType = [[NSString alloc] initWithBytes:c0 length:c-c0 encoding:NSUTF8StringEncoding];
	[extractedType autorelease];
//	NSLog(@"extractedType=%@", extractedType);
	
	if (![extractedType isEqualToString:type])	return	nil;
	return	v;
}

@end



