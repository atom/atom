/*
 * Copyright (C) 2007 Apple Inc. All rights reserved.
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

#import <wtf/Assertions.h>
#import <dlfcn.h>

#define SOFT_LINK_LIBRARY(lib) \
    static void* lib##Library() \
    { \
        static void* dylib = dlopen("/usr/lib/" #lib ".dylib", RTLD_NOW); \
        ASSERT_WITH_MESSAGE(dylib, "%s", dlerror()); \
        return dylib; \
    }

#define SOFT_LINK_FRAMEWORK(framework) \
    static void* framework##Library() \
    { \
        static void* frameworkLibrary = dlopen("/System/Library/Frameworks/" #framework ".framework/" #framework, RTLD_NOW); \
        ASSERT_WITH_MESSAGE(frameworkLibrary, "%s", dlerror()); \
        return frameworkLibrary; \
    }

#define SOFT_LINK_FRAMEWORK_OPTIONAL(framework) \
    static void* framework##Library() \
    { \
        static void* frameworkLibrary = dlopen("/System/Library/Frameworks/" #framework ".framework/" #framework, RTLD_NOW); \
        return frameworkLibrary; \
    }

#define SOFT_LINK_FRAMEWORK_IN_CORESERVICES_UMBRELLA(framework) \
    static void* framework##Library() \
    { \
        static void* frameworkLibrary = dlopen("/System/Library/Frameworks/CoreServices.framework/Frameworks/" #framework ".framework/" #framework, RTLD_NOW); \
        ASSERT_WITH_MESSAGE(frameworkLibrary, "%s", dlerror()); \
        return frameworkLibrary; \
    }

#define SOFT_LINK(framework, functionName, resultType, parameterDeclarations, parameterNames) \
    static resultType init##functionName parameterDeclarations; \
    static resultType (*softLink##functionName) parameterDeclarations = init##functionName; \
    \
    static resultType init##functionName parameterDeclarations \
    { \
        softLink##functionName = (resultType (*) parameterDeclarations) dlsym(framework##Library(), #functionName); \
        ASSERT_WITH_MESSAGE(softLink##functionName, "%s", dlerror()); \
        return softLink##functionName parameterNames; \
    }\
    \
    inline resultType functionName parameterDeclarations \
    {\
        return softLink##functionName parameterNames; \
    }

/* callingConvention is unused on Mac but is here to keep the macro prototype the same between Mac and Windows. */
#define SOFT_LINK_OPTIONAL(framework, functionName, resultType, callingConvention, parameterDeclarations) \
    typedef resultType (*functionName##PtrType) parameterDeclarations; \
    \
    static functionName##PtrType functionName##Ptr() \
    { \
        static functionName##PtrType ptr = reinterpret_cast<functionName##PtrType>(dlsym(framework##Library(), #functionName)); \
        return ptr; \
    }

#define SOFT_LINK_CLASS(framework, className) \
    static Class init##className(); \
    static Class (*get##className##Class)() = init##className; \
    static Class class##className; \
    \
    static Class className##Function() \
    { \
        return class##className; \
    }\
    \
    static Class init##className() \
    { \
        framework##Library(); \
        class##className = objc_getClass(#className); \
        ASSERT(class##className); \
        get##className##Class = className##Function; \
        return class##className; \
    }

#define SOFT_LINK_POINTER(framework, name, type) \
    static type init##name(); \
    static type (*get##name)() = init##name; \
    static type pointer##name; \
    \
    static type name##Function() \
    { \
        return pointer##name; \
    }\
    \
    static type init##name() \
    { \
        void** pointer = static_cast<void**>(dlsym(framework##Library(), #name)); \
        ASSERT_WITH_MESSAGE(pointer, "%s", dlerror()); \
        pointer##name = static_cast<type>(*pointer); \
        get##name = name##Function; \
        return pointer##name; \
    }

#define SOFT_LINK_POINTER_OPTIONAL(framework, name, type) \
    static type init##name(); \
    static type (*get##name)() = init##name; \
    static type pointer##name; \
    \
    static type name##Function() \
    { \
        return pointer##name; \
    }\
    \
    static type init##name() \
    { \
        void** pointer = static_cast<void**>(dlsym(framework##Library(), #name)); \
        if (pointer) \
            pointer##name = static_cast<type>(*pointer); \
        get##name = name##Function; \
        return pointer##name; \
    }

#define SOFT_LINK_CONSTANT(framework, name, type) \
    static type init##name(); \
    static type (*get##name)() = init##name; \
    static type constant##name; \
    \
    static type name##Function() \
    { \
        return constant##name; \
    }\
    \
    static type init##name() \
    { \
        void* constant = dlsym(framework##Library(), #name); \
        ASSERT_WITH_MESSAGE(constant, "%s", dlerror()); \
        constant##name = *static_cast<type*>(constant); \
        get##name = name##Function; \
        return constant##name; \
    }
