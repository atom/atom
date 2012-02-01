/*
 * Copyright (C) 2003, 2006, 2007 Apple Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef WTF_Assertions_h
#define WTF_Assertions_h

/*
   no namespaces because this file has to be includable from C and Objective-C

   Note, this file uses many GCC extensions, but it should be compatible with
   C, Objective C, C++, and Objective C++.

   For non-debug builds, everything is disabled by default.
   Defining any of the symbols explicitly prevents this from having any effect.
   
   MSVC7 note: variadic macro support was added in MSVC8, so for now we disable
   those macros in MSVC7. For more info, see the MSDN document on variadic 
   macros here:
   
   http://msdn2.microsoft.com/en-us/library/ms177415(VS.80).aspx
*/

#include "Platform.h"

#include <stddef.h>

#if !COMPILER(MSVC)
#include <inttypes.h>
#endif

#ifdef NDEBUG
/* Disable ASSERT* macros in release mode. */
#define ASSERTIONS_DISABLED_DEFAULT 1
#else
#define ASSERTIONS_DISABLED_DEFAULT 0
#endif

#if COMPILER(MSVC7_OR_LOWER)
#define HAVE_VARIADIC_MACRO 0
#else
#define HAVE_VARIADIC_MACRO 1
#endif

#ifndef BACKTRACE_DISABLED
#define BACKTRACE_DISABLED ASSERTIONS_DISABLED_DEFAULT
#endif

#ifndef ASSERT_DISABLED
#define ASSERT_DISABLED ASSERTIONS_DISABLED_DEFAULT
#endif

#ifndef ASSERT_MSG_DISABLED
#if HAVE(VARIADIC_MACRO)
#define ASSERT_MSG_DISABLED ASSERTIONS_DISABLED_DEFAULT
#else
#define ASSERT_MSG_DISABLED 1
#endif
#endif

#ifndef ASSERT_ARG_DISABLED
#define ASSERT_ARG_DISABLED ASSERTIONS_DISABLED_DEFAULT
#endif

#ifndef FATAL_DISABLED
#if HAVE(VARIADIC_MACRO)
#define FATAL_DISABLED ASSERTIONS_DISABLED_DEFAULT
#else
#define FATAL_DISABLED 1
#endif
#endif

#ifndef ERROR_DISABLED
#if HAVE(VARIADIC_MACRO)
#define ERROR_DISABLED ASSERTIONS_DISABLED_DEFAULT
#else
#define ERROR_DISABLED 1
#endif
#endif

#ifndef LOG_DISABLED
#if HAVE(VARIADIC_MACRO)
#define LOG_DISABLED ASSERTIONS_DISABLED_DEFAULT
#else
#define LOG_DISABLED 1
#endif
#endif

#if COMPILER(GCC)
#define WTF_PRETTY_FUNCTION __PRETTY_FUNCTION__
#else
#define WTF_PRETTY_FUNCTION __FUNCTION__
#endif

/* WTF logging functions can process %@ in the format string to log a NSObject* but the printf format attribute
   emits a warning when %@ is used in the format string.  Until <rdar://problem/5195437> is resolved we can't include
   the attribute when being used from Objective-C code in case it decides to use %@. */
#if COMPILER(GCC) && !defined(__OBJC__)
#define WTF_ATTRIBUTE_PRINTF(formatStringArgument, extraArguments) __attribute__((__format__(printf, formatStringArgument, extraArguments)))
#else
#define WTF_ATTRIBUTE_PRINTF(formatStringArgument, extraArguments) 
#endif

/* These helper functions are always declared, but not necessarily always defined if the corresponding function is disabled. */

#ifdef __cplusplus
extern "C" {
#endif

typedef enum { WTFLogChannelOff, WTFLogChannelOn } WTFLogChannelState;

typedef struct {
    unsigned mask;
    const char *defaultName;
    WTFLogChannelState state;
} WTFLogChannel;

WTF_EXPORT_PRIVATE void WTFReportAssertionFailure(const char* file, int line, const char* function, const char* assertion);
WTF_EXPORT_PRIVATE void WTFReportAssertionFailureWithMessage(const char* file, int line, const char* function, const char* assertion, const char* format, ...) WTF_ATTRIBUTE_PRINTF(5, 6);
WTF_EXPORT_PRIVATE void WTFReportArgumentAssertionFailure(const char* file, int line, const char* function, const char* argName, const char* assertion);
WTF_EXPORT_PRIVATE void WTFReportFatalError(const char* file, int line, const char* function, const char* format, ...) WTF_ATTRIBUTE_PRINTF(4, 5);
WTF_EXPORT_PRIVATE void WTFReportError(const char* file, int line, const char* function, const char* format, ...) WTF_ATTRIBUTE_PRINTF(4, 5);
WTF_EXPORT_PRIVATE void WTFLog(WTFLogChannel*, const char* format, ...) WTF_ATTRIBUTE_PRINTF(2, 3);
WTF_EXPORT_PRIVATE void WTFLogVerbose(const char* file, int line, const char* function, WTFLogChannel*, const char* format, ...) WTF_ATTRIBUTE_PRINTF(5, 6);

WTF_EXPORT_PRIVATE void WTFGetBacktrace(void** stack, int* size);
WTF_EXPORT_PRIVATE void WTFReportBacktrace();

typedef void (*WTFCrashHookFunction)();
WTF_EXPORT_PRIVATE void WTFSetCrashHook(WTFCrashHookFunction);
WTF_EXPORT_PRIVATE void WTFInvokeCrashHook();

#ifdef __cplusplus
}
#endif

/* CRASH() - Raises a fatal error resulting in program termination and triggering either the debugger or the crash reporter.

   Use CRASH() in response to known, unrecoverable errors like out-of-memory.
   Macro is enabled in both debug and release mode.
   To test for unknown errors and verify assumptions, use ASSERT instead, to avoid impacting performance in release builds.

   Signals are ignored by the crash reporter on OS X so we must do better.
*/
#ifndef CRASH
#if COMPILER(CLANG)
#define CRASH() do { \
    WTFReportBacktrace(); \
    WTFInvokeCrashHook(); \
    *(int *)(uintptr_t)0xbbadbeef = 0; \
    __builtin_trap(); \
} while (false)
#else
#define CRASH() do { \
    WTFReportBacktrace(); \
    WTFInvokeCrashHook(); \
    *(int *)(uintptr_t)0xbbadbeef = 0; \
    ((void(*)())0)(); /* More reliable, but doesn't say BBADBEEF */ \
} while (false)
#endif
#endif

#if COMPILER(CLANG)
#define NO_RETURN_DUE_TO_CRASH NO_RETURN
#else
#define NO_RETURN_DUE_TO_CRASH
#endif


/* BACKTRACE

  Print a backtrace to the same location as ASSERT messages.
*/

#if BACKTRACE_DISABLED

#define BACKTRACE() ((void)0)

#else

#define BACKTRACE() do { \
    WTFReportBacktrace(); \
} while(false)

#endif

/* ASSERT, ASSERT_NOT_REACHED, ASSERT_UNUSED

  These macros are compiled out of release builds.
  Expressions inside them are evaluated in debug builds only.
*/

#if OS(WINCE) && !PLATFORM(TORCHMOBILE)
/* FIXME: We include this here only to avoid a conflict with the ASSERT macro. */
#include <windows.h>
#undef min
#undef max
#undef ERROR
#endif

#if OS(WINDOWS)
/* FIXME: Change to use something other than ASSERT to avoid this conflict with the underlying platform */
#undef ASSERT
#endif

#if ASSERT_DISABLED

#define ASSERT(assertion) ((void)0)
#define ASSERT_AT(assertion, file, line, function) ((void)0)
#define ASSERT_NOT_REACHED() ((void)0)
#define NO_RETURN_DUE_TO_ASSERT

#if COMPILER(INTEL) && !OS(WINDOWS) || COMPILER(RVCT)
template<typename T>
inline void assertUnused(T& x) { (void)x; }
#define ASSERT_UNUSED(variable, assertion) (assertUnused(variable))
#else
#define ASSERT_UNUSED(variable, assertion) ((void)variable)
#endif

#else

#define ASSERT(assertion) do \
    if (!(assertion)) { \
        WTFReportAssertionFailure(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, #assertion); \
        CRASH(); \
    } \
while (0)

#define ASSERT_AT(assertion, file, line, function) do  \
    if (!(assertion)) { \
        WTFReportAssertionFailure(file, line, function, #assertion); \
        CRASH(); \
    } \
while (0)

#define ASSERT_NOT_REACHED() do { \
    WTFReportAssertionFailure(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, 0); \
    CRASH(); \
} while (0)

#define ASSERT_UNUSED(variable, assertion) ASSERT(assertion)

#define NO_RETURN_DUE_TO_ASSERT NO_RETURN_DUE_TO_CRASH

#endif

/* ASSERT_WITH_MESSAGE */

#if COMPILER(MSVC7_OR_LOWER)
#define ASSERT_WITH_MESSAGE(assertion) ((void)0)
#elif ASSERT_MSG_DISABLED
#define ASSERT_WITH_MESSAGE(assertion, ...) ((void)0)
#else
#define ASSERT_WITH_MESSAGE(assertion, ...) do \
    if (!(assertion)) { \
        WTFReportAssertionFailureWithMessage(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, #assertion, __VA_ARGS__); \
        CRASH(); \
    } \
while (0)
#endif

/* ASSERT_WITH_MESSAGE_UNUSED */

#if COMPILER(MSVC7_OR_LOWER)
#define ASSERT_WITH_MESSAGE_UNUSED(variable, assertion) ((void)0)
#elif ASSERT_MSG_DISABLED
#if COMPILER(INTEL) && !OS(WINDOWS) || COMPILER(RVCT)
template<typename T>
inline void assertWithMessageUnused(T& x) { (void)x; }
#define ASSERT_WITH_MESSAGE_UNUSED(variable, assertion, ...) (assertWithMessageUnused(variable))
#else
#define ASSERT_WITH_MESSAGE_UNUSED(variable, assertion, ...) ((void)variable)
#endif
#else
#define ASSERT_WITH_MESSAGE_UNUSED(variable, assertion, ...) do \
    if (!(assertion)) { \
        WTFReportAssertionFailureWithMessage(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, #assertion, __VA_ARGS__); \
        CRASH(); \
    } \
while (0)
#endif
                        
                        
/* ASSERT_ARG */

#if ASSERT_ARG_DISABLED

#define ASSERT_ARG(argName, assertion) ((void)0)

#else

#define ASSERT_ARG(argName, assertion) do \
    if (!(assertion)) { \
        WTFReportArgumentAssertionFailure(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, #argName, #assertion); \
        CRASH(); \
    } \
while (0)

#endif

/* COMPILE_ASSERT */
#ifndef COMPILE_ASSERT
#define COMPILE_ASSERT(exp, name) typedef int dummy##name [(exp) ? 1 : -1]
#endif

/* FATAL */

#if COMPILER(MSVC7_OR_LOWER)
#define FATAL() ((void)0)
#elif FATAL_DISABLED
#define FATAL(...) ((void)0)
#else
#define FATAL(...) do { \
    WTFReportFatalError(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, __VA_ARGS__); \
    CRASH(); \
} while (0)
#endif

/* LOG_ERROR */

#if COMPILER(MSVC7_OR_LOWER)
#define LOG_ERROR() ((void)0)
#elif ERROR_DISABLED
#define LOG_ERROR(...) ((void)0)
#else
#define LOG_ERROR(...) WTFReportError(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, __VA_ARGS__)
#endif

/* LOG */

#if COMPILER(MSVC7_OR_LOWER)
#define LOG() ((void)0)
#elif LOG_DISABLED
#define LOG(channel, ...) ((void)0)
#else
#define LOG(channel, ...) WTFLog(&JOIN_LOG_CHANNEL_WITH_PREFIX(LOG_CHANNEL_PREFIX, channel), __VA_ARGS__)
#define JOIN_LOG_CHANNEL_WITH_PREFIX(prefix, channel) JOIN_LOG_CHANNEL_WITH_PREFIX_LEVEL_2(prefix, channel)
#define JOIN_LOG_CHANNEL_WITH_PREFIX_LEVEL_2(prefix, channel) prefix ## channel
#endif

/* LOG_VERBOSE */

#if COMPILER(MSVC7_OR_LOWER)
#define LOG_VERBOSE(channel) ((void)0)
#elif LOG_DISABLED
#define LOG_VERBOSE(channel, ...) ((void)0)
#else
#define LOG_VERBOSE(channel, ...) WTFLogVerbose(__FILE__, __LINE__, WTF_PRETTY_FUNCTION, &JOIN_LOG_CHANNEL_WITH_PREFIX(LOG_CHANNEL_PREFIX, channel), __VA_ARGS__)
#endif

#if ENABLE(GC_VALIDATION)
#define ASSERT_GC_OBJECT_LOOKS_VALID(cell) do { \
    if (!(cell))\
        CRASH();\
    if (cell->unvalidatedStructure()->unvalidatedStructure() != cell->unvalidatedStructure()->unvalidatedStructure()->unvalidatedStructure())\
        CRASH();\
} while (0)

#define ASSERT_GC_OBJECT_INHERITS(object, classInfo) do {\
    ASSERT_GC_OBJECT_LOOKS_VALID(object); \
    if (!object->inherits(classInfo)) \
        CRASH();\
} while (0)

#else
#define ASSERT_GC_OBJECT_LOOKS_VALID(cell) do { (void)cell; } while (0)
#define ASSERT_GC_OBJECT_INHERITS(object, classInfo) do { (void)object; (void)classInfo; } while (0)
#endif

#if COMPILER(CLANG)
#define ASSERT_HAS_TRIVIAL_DESTRUCTOR(klass) COMPILE_ASSERT(__has_trivial_destructor(klass), klass##_has_trivial_destructor_check)
#else
#define ASSERT_HAS_TRIVIAL_DESTRUCTOR(klass)
#endif

#endif /* WTF_Assertions_h */
