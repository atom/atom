/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef PlatformMenuDescription_h
#define PlatformMenuDescription_h

#if PLATFORM(MAC)
OBJC_CLASS NSMutableArray;
#elif PLATFORM(QT)
#include <qlist.h>
#elif PLATFORM(GTK)
typedef struct _GtkMenu GtkMenu;
#elif PLATFORM(WX)
class wxMenu;
#elif PLATFORM(EFL)
#include <wtf/Vector.h>
#endif

namespace WebCore {

#if !USE(CROSS_PLATFORM_CONTEXT_MENUS)
#if PLATFORM(MAC)
    typedef NSMutableArray* PlatformMenuDescription;
#elif PLATFORM(QT)
    class ContextMenuItem;
    typedef const QList<ContextMenuItem>* PlatformMenuDescription;
#elif PLATFORM(GTK)
    typedef GtkMenu* PlatformMenuDescription;
#elif PLATFORM(WX)
    typedef wxMenu* PlatformMenuDescription;
#elif PLATFORM(EFL)
    class ContextMenuItem;
    typedef Vector<ContextMenuItem>* PlatformMenuDescription;
#else
    typedef void* PlatformMenuDescription;
#endif
#endif // !USE(CROSS_PLATFORM_CONTEXT_MENUS)

} // namespace

#endif // PlatformMenuDescription_h
