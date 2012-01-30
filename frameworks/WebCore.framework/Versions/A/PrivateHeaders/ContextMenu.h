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

#ifndef ContextMenu_h
#define ContextMenu_h

#include <wtf/Noncopyable.h>

#include "ContextMenuItem.h"
#include "PlatformMenuDescription.h"
#include "PlatformString.h"
#if PLATFORM(MAC)
#include <wtf/RetainPtr.h>
#elif PLATFORM(QT)
#include <QMenu>
#elif PLATFORM(WIN)
#include <windows.h>
#endif

namespace WebCore {

    class ContextMenuController;

    class ContextMenu {
        WTF_MAKE_NONCOPYABLE(ContextMenu); WTF_MAKE_FAST_ALLOCATED;
    public:
        ContextMenu();

        ContextMenuItem* itemWithAction(unsigned);

#if USE(CROSS_PLATFORM_CONTEXT_MENUS)
#if PLATFORM(WIN)
        typedef HMENU NativeMenu;
#elif PLATFORM(EFL)
        typedef void* NativeMenu;
#endif
        explicit ContextMenu(NativeMenu);

        NativeMenu nativeMenu() const;

        static NativeMenu createNativeMenuFromItems(const Vector<ContextMenuItem>&);
        static void getContextMenuItems(NativeMenu, Vector<ContextMenuItem>&);

        // FIXME: When more platforms switch over, this should return const ContextMenuItem*'s.
        ContextMenuItem* itemAtIndex(unsigned index) { return &m_items[index]; }

        void setItems(const Vector<ContextMenuItem>& items) { m_items = items; }
        const Vector<ContextMenuItem>& items() const { return m_items; }

        void appendItem(const ContextMenuItem& item) { m_items.append(item); } 
#else
        ContextMenu(const PlatformMenuDescription);
        ~ContextMenu();

        void insertItem(unsigned position, ContextMenuItem&);
        void appendItem(ContextMenuItem&);

        ContextMenuItem* itemAtIndex(unsigned, const PlatformMenuDescription);

        unsigned itemCount() const;

        PlatformMenuDescription platformDescription() const;
        void setPlatformDescription(PlatformMenuDescription);

        PlatformMenuDescription releasePlatformDescription();

#if PLATFORM(WX)
        static ContextMenuItem* itemWithId(int);
#endif

#endif // USE(CROSS_PLATFORM_CONTEXT_MENUS)

    private:
#if USE(CROSS_PLATFORM_CONTEXT_MENUS)
        Vector<ContextMenuItem> m_items;
#else
#if PLATFORM(MAC)
        // Keep this in sync with the PlatformMenuDescription typedef
        RetainPtr<NSMutableArray> m_platformDescription;
#elif PLATFORM(QT)
        QList<ContextMenuItem> m_items;
#elif PLATFORM(CHROMIUM) || PLATFORM(EFL)
        Vector<ContextMenuItem> m_items;
#else
        PlatformMenuDescription m_platformDescription;
#if OS(WINCE)
        unsigned m_itemCount;
#endif
#endif

#endif // USE(CROSS_PLATFORM_CONTEXT_MENUS)
    };

#if !USE(CROSS_PLATFORM_CONTEXT_MENUS)
Vector<ContextMenuItem> contextMenuItemVector(PlatformMenuDescription);
PlatformMenuDescription platformMenuDescription(Vector<ContextMenuItem>&);
#endif

}

#endif // ContextMenu_h
