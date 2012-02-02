/*
 * Copyright (C) 2011 Apple Inc.  All rights reserved.
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
 *
 * This file handles shared library symbol export decorations. It is recommended
 * that all WebKit projects use these definitions so that symbol exports work
 * properly on all platforms and compilers that WebKit builds under.
 */
#ifndef PlatformExportMacros_h
#define PlatformExportMacros_h

#include <wtf/Platform.h>
#include <wtf/ExportMacros.h>

// See note in wtf/Platform.h for more info on EXPORT_MACROS.
#if USE(EXPORT_MACROS)

#if defined(BUILDING_WebCore) || defined(BUILDING_WebKit)
#define WEBKIT_EXPORTDATA WTF_EXPORT
#else
#define WEBKIT_EXPORTDATA WTF_IMPORT
#endif

#else // !USE(EXPORT_MACROS)

#if !PLATFORM(CHROMIUM) && OS(WINDOWS) && !defined(BUILDING_WX__) && !COMPILER(GCC)

#if defined(BUILDING_WebCore) || defined(BUILDING_WebKit)
#define WEBKIT_EXPORTDATA __declspec(dllexport)
#else
#define WEBKIT_EXPORTDATA __declspec(dllimport)
#endif

#else // !PLATFORM...

#define WEBKIT_EXPORTDATA

#endif // !PLATFORM...

#endif // USE(EXPORT_MACROS)

#endif // PlatformExportMacros_h
