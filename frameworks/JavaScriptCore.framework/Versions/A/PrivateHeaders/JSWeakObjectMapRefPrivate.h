/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef JSWeakObjectMapRefPrivate_h
#define JSWeakObjectMapRefPrivate_h

#include <JavaScriptCore/JSContextRef.h>
#include <JavaScriptCore/JSValueRef.h>

#ifdef __cplusplus
extern "C" {
#endif
    
/*! @typedef JSWeakObjectMapRef A weak map for storing JSObjectRefs */
typedef struct OpaqueJSWeakObjectMap* JSWeakObjectMapRef;

/*! 
 @typedef JSWeakMapDestroyedCallback
 @abstract The callback invoked when a JSWeakObjectMapRef is being destroyed.
 @param map The map that is being destroyed.
 @param data The private data (if any) that was associated with the map instance.
 */
typedef void (*JSWeakMapDestroyedCallback)(JSWeakObjectMapRef map, void* data);

/*!
 @function
 @abstract Creates a weak value map that can be used to reference user defined objects without preventing them from being collected.
 @param ctx The execution context to use.
 @param data A void* to set as the map's private data. Pass NULL to specify no private data.
 @param destructor A function to call when the weak map is destroyed.
 @result A JSWeakObjectMapRef bound to the given context, data and destructor.
 @discussion The JSWeakObjectMapRef can be used as a storage mechanism to hold custom JS objects without forcing those objects to
 remain live as JSValueProtect would.
 */
JS_EXPORT JSWeakObjectMapRef JSWeakObjectMapCreate(JSContextRef ctx, void* data, JSWeakMapDestroyedCallback destructor);

/*!
 @function
 @abstract Associates a JSObjectRef with the given key in a JSWeakObjectMap.
 @param ctx The execution context to use.
 @param map The map to operate on.
 @param key The key to associate a weak reference with.
 @param object The user defined object to associate with the key.
 */
JS_EXPORT void JSWeakObjectMapSet(JSContextRef ctx, JSWeakObjectMapRef map, void* key, JSObjectRef);

/*!
 @function
 @abstract Retrieves the JSObjectRef associated with a key.
 @param ctx The execution context to use.
 @param map The map to query.
 @param key The key to search for.
 @result Either the live object associated with the provided key, or NULL.
 */
JS_EXPORT JSObjectRef JSWeakObjectMapGet(JSContextRef ctx, JSWeakObjectMapRef map, void* key);

/*!
 @function
 @abstract Removes the entry for the given key if the key is present, otherwise it has no effect.
 @param ctx The execution context to use.
 @param map The map to use.
 @param key The key to remove.
 */
JS_EXPORT void JSWeakObjectMapRemove(JSContextRef ctx, JSWeakObjectMapRef map, void* key);

#ifdef __cplusplus
}
#endif

#endif // JSWeakObjectMapPrivate_h
