/*
 *  Copyright (C) 2004, 2006, 2007 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JSBase.h>
#import <JavaScriptCore/WebKitAvailability.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_1_3

// NSObject (WebScripting) -----------------------------------------------------

/*
    Classes may implement one or more methods in WebScripting to export interfaces 
    to WebKit's JavaScript environment.

    By default, no properties or functions are exported. A class must implement 
    +isKeyExcludedFromWebScript: and/or +isSelectorExcludedFromWebScript: to 
    expose selected properties and methods, respectively, to JavaScript.

    Access to exported properties is done using KVC -- specifically, the following
    KVC methods:

        - (void)setValue:(id)value forKey:(NSString *)key
        - (id)valueForKey:(NSString *)key

    Clients may also intercept property set/get operations that are made by the 
    scripting environment for properties that are not exported. This is done using 
    the KVC methods:

        - (void)setValue:(id)value forUndefinedKey:(NSString *)key
        - (id)valueForUndefinedKey:(NSString *)key
    
    Similarly, clients may intercept method invocations that are made by the
    scripting environment for methods that are not exported. This is done using
    the method:

        - (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)args;

    If clients need to raise an exception in the script environment
    they can call [WebScriptObject throwException:]. Note that throwing an
    exception using this method will only succeed if the method that throws the exception
    is being called within the scope of a script invocation.

    Not all methods are exposed. Only those methods whose parameters and return
    type meets the export criteria are exposed. Valid types are Objective-C instances
    and scalars. Other types are not allowed.

    Types will be converted automatically between JavaScript and Objective-C in 
    the following manner:

    JavaScript              ObjC
    ----------              ----------
    null            =>      nil
    undefined       =>      WebUndefined
    number          =>      NSNumber
    boolean         =>      CFBoolean
    string          =>      NSString
    object          =>      id
    
    The object => id conversion occurs as follows: if the object wraps an underlying
    Objective-C object (i.e., if it was created by a previous ObjC => JavaScript conversion),
    then the underlying Objective-C object is returned. Otherwise, a new WebScriptObject
    is created and returned.
    
    The above conversions occur only if the declared ObjC type is an object type. 
    For primitive types like int and char, a numeric cast is performed.

    ObjC                    JavaScript
    ----                    ----------
    NSNull          =>      null
    nil             =>      undefined
    WebUndefined    =>      undefined
    CFBoolean       =>      boolean
    NSNumber        =>      number
    NSString        =>      string
    NSArray         =>      array object
    WebScriptObject =>      object

    The above conversions occur only if the declared ObjC type is an object type. 
    For primitive type like int and char, a numeric cast is performed.
*/
@interface NSObject (WebScripting)

/*!
    @method webScriptNameForSelector:
    @param selector The selector that will be exposed to the script environment.
    @discussion Use the returned string as the exported name for the selector
    in the script environment. It is the responsibility of the class to ensure
    uniqueness of the returned name. If nil is returned or this
    method is not implemented the default name for the selector will
    be used. The default name concatenates the components of the
    Objective-C selector name and replaces ':' with '_'.  '_' characters
    are escaped with an additional '$', i.e. '_' becomes "$_". '$' are
    also escaped, i.e.
        Objective-C name        Default script name
        moveTo::                move__
        moveTo_                 moveTo$_
        moveTo$_                moveTo$$$_
    @result Returns the name to be used to represent the specified selector in the
    scripting environment.
*/
+ (NSString *)webScriptNameForSelector:(SEL)selector;

/*!
    @method isSelectorExcludedFromWebScript:
    @param selector The selector the will be exposed to the script environment.
    @discussion Return NO to export the selector to the script environment.
    Return YES to prevent the selector from being exported to the script environment. 
    If this method is not implemented on the class no selectors will be exported.
    @result Returns YES to hide the selector, NO to export the selector.
*/
+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector;

/*!
    @method webScriptNameForKey:
    @param name The name of the instance variable that will be exposed to the
    script environment. Only instance variables that meet the export criteria will
    be exposed.
    @discussion Provide an alternate name for a property.
    @result Returns the name to be used to represent the specified property in the
    scripting environment.
*/
+ (NSString *)webScriptNameForKey:(const char *)name;

/*!
    @method isKeyExcludedFromWebScript:
    @param name The name of the instance variable that will be exposed to the
    script environment.
    @discussion Return NO to export the property to the script environment.
    Return YES to prevent the property from being exported to the script environment.
    @result Returns YES to hide the property, NO to export the property.
*/
+ (BOOL)isKeyExcludedFromWebScript:(const char *)name;

/*!
    @method invokeUndefinedMethodFromWebScript:withArguments:
    @param name The name of the method to invoke.
    @param arguments The arguments to pass the method.
    @discussion If a script attempts to invoke a method that is not exported, 
    invokeUndefinedMethodFromWebScript:withArguments: will be called.
    @result The return value of the invocation. The value will be converted as appropriate
    for the script environment.
*/
- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)arguments;

/*!
    @method invokeDefaultMethodWithArguments:
    @param arguments The arguments to pass the method.
    @discussion If a script attempts to call an exposed object as a function, 
    this method will be called.
    @result The return value of the call. The value will be converted as appropriate
    for the script environment.
*/
- (id)invokeDefaultMethodWithArguments:(NSArray *)arguments;

/*!
    @method finalizeForWebScript
    @discussion finalizeForScript is called on objects exposed to the script
    environment just before the script environment garbage collects the object.
    Subsequently, any references to WebScriptObjects made by the exposed object will
    be invalid and have undefined consequences.
*/
- (void)finalizeForWebScript;

@end


// WebScriptObject --------------------------------------------------

@class WebScriptObjectPrivate;
@class WebFrame;

/*!
    @class WebScriptObject
    @discussion WebScriptObjects are used to wrap script objects passed from
    script environments to Objective-C. WebScriptObjects cannot be created
    directly. In normal uses of WebKit, you gain access to the script
    environment using the "windowScriptObject" method on WebView.

    The following KVC methods are commonly used to access properties of the
    WebScriptObject:

        - (void)setValue:(id)value forKey:(NSString *)key
        - (id)valueForKey:(NSString *)key

    As it possible to remove attributes from web script objects, the following
    additional method augments the basic KVC methods:

        - (void)removeWebScriptKey:(NSString *)name;

    Also, since the sparse array access allowed in script objects doesn't map well
    to NSArray, the following methods can be used to access index based properties:

        - (id)webScriptValueAtIndex:(unsigned)index;
        - (void)setWebScriptValueAtIndex:(unsigned)index value:(id)value;
*/
@interface WebScriptObject : NSObject
{
    WebScriptObjectPrivate *_private;
}

/*!
    @method throwException:
    @discussion Throws an exception in the current script execution context.
    @result Either NO if an exception could not be raised, YES otherwise.
*/
+ (BOOL)throwException:(NSString *)exceptionMessage;

/*!
    @method JSObject
    @result The equivalent JSObjectRef for this WebScriptObject.
    @discussion Use this method to bridge between the WebScriptObject and 
    JavaScriptCore APIs.
*/
- (JSObjectRef)JSObject WEBKIT_OBJC_METHOD_ANNOTATION(AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER);

/*!
    @method callWebScriptMethod:withArguments:
    @param name The name of the method to call in the script environment.
    @param arguments The arguments to pass to the script environment.
    @discussion Calls the specified method in the script environment using the
    specified arguments.
    @result Returns the result of calling the script method.
    Returns WebUndefined when an exception is thrown in the script environment.
*/
- (id)callWebScriptMethod:(NSString *)name withArguments:(NSArray *)arguments;

/*!
    @method evaluateWebScript:
    @param script The script to execute in the target script environment.
    @discussion The script will be executed in the target script environment. The format
    of the script is dependent of the target script environment.
    @result Returns the result of evaluating the script in the script environment.
    Returns WebUndefined when an exception is thrown in the script environment.
*/
- (id)evaluateWebScript:(NSString *)script;

/*!
    @method removeWebScriptKey:
    @param name The name of the property to remove.
    @discussion Removes the property from the object in the script environment.
*/
- (void)removeWebScriptKey:(NSString *)name;

/*!
    @method stringRepresentation
    @discussion Converts the target object to a string representation. The coercion
    of non string objects type is dependent on the script environment.
    @result Returns the string representation of the object.
*/
- (NSString *)stringRepresentation;

/*!
    @method webScriptValueAtIndex:
    @param index The index of the property to return.
    @discussion Gets the value of the property at the specified index.
    @result The value of the property. Returns WebUndefined when an exception is
    thrown in the script environment.
*/
- (id)webScriptValueAtIndex:(unsigned)index;

/*!
    @method setWebScriptValueAtIndex:value:
    @param index The index of the property to set.
    @param value The value of the property to set.
    @discussion Sets the property value at the specified index.
*/
- (void)setWebScriptValueAtIndex:(unsigned)index value:(id)value;

/*!
    @method setException:
    @param description The description of the exception.
    @discussion Raises an exception in the script environment in the context of the
    current object.
*/
- (void)setException:(NSString *)description;

@end


// WebUndefined --------------------------------------------------------------

/*!
    @class WebUndefined
*/
@interface WebUndefined : NSObject <NSCoding, NSCopying>

/*!
    @method undefined
    @result The WebUndefined shared instance.
*/
+ (WebUndefined *)undefined;

@end

#endif
