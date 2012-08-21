// Copyright (c) 2011 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#ifndef CEF_INCLUDE_INTERNAL_CEF_BUILD_H_
#define CEF_INCLUDE_INTERNAL_CEF_BUILD_H_
#pragma once

#if defined(BUILDING_CEF_SHARED)

#include "base/compiler_specific.h"

#else  // !BUILDING_CEF_SHARED

#if defined(_WIN32)
#ifndef OS_WIN
#define OS_WIN 1
#endif
#elif defined(__APPLE__)
#ifndef OS_MACOSX
#define OS_MACOSX 1
#endif
#elif defined(__linux__)
#ifndef OS_LINUX
#define OS_LINUX 1
#endif
#else
#error Please add support for your platform in cef_build.h
#endif

// For access to standard POSIXish features, use OS_POSIX instead of a
// more specific macro.
#if defined(OS_MACOSX) || defined(OS_LINUX)
#ifndef OS_POSIX
#define OS_POSIX 1
#endif
#endif

// Compiler detection.
#if defined(__GNUC__)
#ifndef COMPILER_GCC
#define COMPILER_GCC 1
#endif
#elif defined(_MSC_VER)
#ifndef COMPILER_MSVC
#define COMPILER_MSVC 1
#endif
#else
#error Please add support for your compiler in cef_build.h
#endif

// Annotate a virtual method indicating it must be overriding a virtual
// method in the parent class.
// Use like:
//   virtual void foo() OVERRIDE;
#ifndef OVERRIDE
#if defined(COMPILER_MSVC)
#define OVERRIDE override
#elif defined(__clang__)
#define OVERRIDE override
#else
#define OVERRIDE
#endif
#endif

#ifndef ALLOW_THIS_IN_INITIALIZER_LIST
#if defined(COMPILER_MSVC)

// MSVC_PUSH_DISABLE_WARNING pushes |n| onto a stack of warnings to be disabled.
// The warning remains disabled until popped by MSVC_POP_WARNING.
#define MSVC_PUSH_DISABLE_WARNING(n) __pragma(warning(push)) \
                                     __pragma(warning(disable:n))

// MSVC_PUSH_WARNING_LEVEL pushes |n| as the global warning level.  The level
// remains in effect until popped by MSVC_POP_WARNING().  Use 0 to disable all
// warnings.
#define MSVC_PUSH_WARNING_LEVEL(n) __pragma(warning(push, n))

// Pop effects of innermost MSVC_PUSH_* macro.
#define MSVC_POP_WARNING() __pragma(warning(pop))

// Allows |this| to be passed as an argument in constructor initializer lists.
// This uses push/pop instead of the seemingly simpler suppress feature to avoid
// having the warning be disabled for more than just |code|.
//
// Example usage:
// Foo::Foo() : x(NULL), ALLOW_THIS_IN_INITIALIZER_LIST(y(this)), z(3) {}
//
// Compiler warning C4355: 'this': used in base member initializer list:
// http://msdn.microsoft.com/en-us/library/3c594ae3(VS.80).aspx
#define ALLOW_THIS_IN_INITIALIZER_LIST(code) MSVC_PUSH_DISABLE_WARNING(4355) \
                                             code \
                                             MSVC_POP_WARNING()
#else  // !COMPILER_MSVC

#define ALLOW_THIS_IN_INITIALIZER_LIST(code) code

#endif  // !COMPILER_MSVC
#endif

#endif  // !BUILDING_CEF_SHARED

#endif  // CEF_INCLUDE_INTERNAL_CEF_BUILD_H_
