/*
 * Copyright (C) 2006, 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Samuel Weinig <sam.weinig@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#if defined(HAVE_CONFIG_H) && HAVE_CONFIG_H
#ifdef BUILDING_WITH_CMAKE
#include "cmakeconfig.h"
#else
#include "autotoolsconfig.h"
#endif
#endif

#include <wtf/Platform.h>
#include <wtf/ExportMacros.h>
// WTF cannot depend on JSC even if USE(JSC).
#if USE(JSC) && !defined(BUILDING_WTF)
#include "JSExportMacros.h"
#elif PLATFORM(CHROMIUM)
// Chromium doesn't have runtime/ in its include paths.
#include "runtime/JSExportMacros.h"
#endif

#if OS(WINDOWS)

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0500
#endif

#ifndef WINVER
#define WINVER 0x0500
#endif

// If we don't define these, they get defined in windef.h. 
// We want to use std::min and std::max
#define max max
#define min min

#if !COMPILER(MSVC7_OR_LOWER) && !OS(WINCE)
// We need to define this before the first #include of stdlib.h or it won't contain rand_s.
#ifndef _CRT_RAND_S
#define _CRT_RAND_S
#endif
#endif

#endif

#if OS(UNIX) || OS(WINDOWS)
#define WTF_USE_OS_RANDOMNESS 1
#endif

#if (OS(FREEBSD) || OS(OPENBSD)) && !defined(__GLIBC__)
#define HAVE_PTHREAD_NP_H 1
#endif

/* FIXME: if all platforms have these, do they really need #defines? */
#define HAVE_STDINT_H 1

#define WTF_CHANGES 1

#ifdef __cplusplus
#undef new
#undef delete
#include <wtf/FastMalloc.h>
#endif

// this breaks compilation of <QFontDatabase>, at least, so turn it off for now
// Also generates errors on wx on Windows and QNX, because these functions
// are used from wx and QNX headers. 
#if !PLATFORM(QT) && !PLATFORM(WX) && !OS(QNX)
#include <wtf/DisallowCType.h>
#endif

#if COMPILER(MSVC)
#define SKIP_STATIC_CONSTRUCTORS_ON_MSVC 1
#else
#define SKIP_STATIC_CONSTRUCTORS_ON_GCC 1
#endif
