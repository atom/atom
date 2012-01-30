/*
 * Copyright (C) 2004 Apple Computer, Inc.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <JavaVM/jni.h>

/*!
    The Java plug-in adds the following additional methods to facilitate JNI
    access to Java VM via the plug-in.
*/

typedef enum {
    WebJNIReturnTypeInvalid = 0,
    WebJNIReturnTypeVoid,
    WebJNIReturnTypeObject,
    WebJNIReturnTypeBoolean,
    WebJNIReturnTypeByte,
    WebJNIReturnTypeChar,
    WebJNIReturnTypeShort,
    WebJNIReturnTypeInt,
    WebJNIReturnTypeLong,
    WebJNIReturnTypeFloat,
    WebJNIReturnTypeDouble
} WebJNIReturnType;

@interface NSObject (WebJavaPlugIn)

/*!
    @method webPlugInGetApplet
    @discusssion This returns the jobject representing the java applet to the
    WebPlugInContainer.  It should always be called from the AppKit Main Thread.
    This method is only implemented by the Java plug-in.
*/
- (jobject)webPlugInGetApplet;

/*!
    @method webPlugInCallJava:isStatic:returnType:method:arguments:callingURL:exceptionDescription:
    @param object The Java instance that will receive the method call.
    @param isStatic A flag that indicated whether the method is a class method.
    @param returnType The return type of the Java method.
    @param method The ID of the Java method to call.
    @param args The arguments to use with the method invocation.
    @param callingURL The URL of the page that contains the JavaScript that is calling Java.
    @param exceptionDescription Pass in nil or the address of pointer to a string object.  If any exception
    is thrown by Java the return value will be a description of the exception, otherwise nil.
    @discussion Calls to Java from native code should not make direct
    use of JNI.  Instead they should use this method to dispatch calls to the 
    Java VM.  This is required to guarantee that the correct thread will receive
    the call.  webPlugInCallJava:isStatic:returnType:method:arguments:callingURL:exceptionDescription: must 
    always be called from the AppKit main thread.  This method is only implemented by the Java plug-in.
    @result The result of the method invocation.
*/
- (jvalue)webPlugInCallJava:(jobject)object
                   isStatic:(BOOL)isStatic
                 returnType:(WebJNIReturnType)returnType
                     method:(jmethodID)method
                  arguments:(jvalue*)args
                 callingURL:(NSURL *)url
       exceptionDescription:(NSString **)exceptionString;

@end
