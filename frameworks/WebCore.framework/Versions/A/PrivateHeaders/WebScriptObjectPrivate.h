/*
 *  Copyright (C) 2004, 2005, 2006, 2007 Apple Inc. All rights reserved.
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

#ifndef _WEB_SCRIPT_OBJECT_PRIVATE_H_
#define _WEB_SCRIPT_OBJECT_PRIVATE_H_

#import "WebScriptObject.h"
#import <runtime/JSValue.h>
#import <wtf/PassRefPtr.h>

namespace JSC {
    
    class JSObject;
    
    namespace Bindings {
        class RootObject;
    }
}
namespace WebCore {
    NSObject* getJSWrapper(JSC::JSObject*);
    void addJSWrapper(NSObject* wrapper, JSC::JSObject*);
    void removeJSWrapper(JSC::JSObject*);
    id createJSWrapper(JSC::JSObject*, PassRefPtr<JSC::Bindings::RootObject> origin, PassRefPtr<JSC::Bindings::RootObject> root);
}

@interface WebScriptObject (Private)
+ (id)_convertValueToObjcValue:(JSC::JSValue)value originRootObject:(JSC::Bindings::RootObject*)originRootObject rootObject:(JSC::Bindings::RootObject*)rootObject;
+ (id)scriptObjectForJSObject:(JSObjectRef)jsObject originRootObject:(JSC::Bindings::RootObject*)originRootObject rootObject:(JSC::Bindings::RootObject*)rootObject;
- (id)_init;
- (id)_initWithJSObject:(JSC::JSObject*)imp originRootObject:(PassRefPtr<JSC::Bindings::RootObject>)originRootObject rootObject:(PassRefPtr<JSC::Bindings::RootObject>)rootObject;
- (void)_setImp:(JSC::JSObject*)imp originRootObject:(PassRefPtr<JSC::Bindings::RootObject>)originRootObject rootObject:(PassRefPtr<JSC::Bindings::RootObject>)rootObject;
- (void)_setOriginRootObject:(PassRefPtr<JSC::Bindings::RootObject>)originRootObject andRootObject:(PassRefPtr<JSC::Bindings::RootObject>)rootObject;
- (void)_initializeScriptDOMNodeImp;
- (JSC::JSObject *)_imp;
- (BOOL)_hasImp;
- (JSC::Bindings::RootObject*)_rootObject;
- (JSC::Bindings::RootObject*)_originRootObject;
@end

@interface WebScriptObject (StagedForPublic)
/*!
 @method hasWebScriptKey:
 @param name The name of the property to check for.
 @discussion Checks for the existence of the property on the object in the script environment.
 @result Returns YES if the property exists, NO otherwise.
 */
- (BOOL)hasWebScriptKey:(NSString *)name;
@end

@interface WebScriptObjectPrivate : NSObject
{
@public
    JSC::JSObject *imp;
    JSC::Bindings::RootObject* rootObject;
    JSC::Bindings::RootObject* originRootObject;
    BOOL isCreatedByDOMWrapper;
}
@end


#endif
