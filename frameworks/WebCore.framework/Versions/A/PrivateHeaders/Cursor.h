/*
 * Copyright (C) 2004, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef Cursor_h
#define Cursor_h

#include "Image.h"
#include "IntPoint.h"
#include <wtf/RefPtr.h>

#if PLATFORM(WIN)
typedef struct HICON__* HICON;
typedef HICON HCURSOR;
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#elif PLATFORM(MAC)
#include <wtf/RetainPtr.h>
#elif PLATFORM(GTK)
#include "GRefPtrGtk.h"
#elif PLATFORM(QT)
#include <QCursor>
#elif PLATFORM(CHROMIUM)
#include "PlatformCursor.h"
#endif

#if PLATFORM(MAC) && !PLATFORM(IOS)
OBJC_CLASS NSCursor;
#endif

#if PLATFORM(WX)
class wxCursor;
#endif

#if PLATFORM(WIN)
typedef struct HICON__ *HICON;
typedef HICON HCURSOR;
#endif

#if PLATFORM(WIN) || PLATFORM(MAC) || PLATFORM(GTK) || PLATFORM(QT) || PLATFORM(EFL)
#define WTF_USE_LAZY_NATIVE_CURSOR 1
#endif

namespace WebCore {

    class Image;

#if PLATFORM(WIN)
    class SharedCursor : public RefCounted<SharedCursor> {
    public:
        static PassRefPtr<SharedCursor> create(HCURSOR nativeCursor) { return adoptRef(new SharedCursor(nativeCursor)); }
        ~SharedCursor();
        HCURSOR nativeCursor() const { return m_nativeCursor; }
    private:
        SharedCursor(HCURSOR nativeCursor) : m_nativeCursor(nativeCursor) { }
        HCURSOR m_nativeCursor;
    };
    typedef RefPtr<SharedCursor> PlatformCursor;
#elif PLATFORM(MAC) && !PLATFORM(IOS)
    typedef NSCursor *PlatformCursor;
#elif PLATFORM(GTK)
    typedef GRefPtr<GdkCursor> PlatformCursor;
#elif PLATFORM(EFL)
    typedef const char* PlatformCursor;
#elif PLATFORM(QT) && !defined(QT_NO_CURSOR)
    // Do not need to be shared but need to be created dynamically via ensurePlatformCursor.
    typedef QCursor* PlatformCursor;
#elif PLATFORM(WX)
    typedef wxCursor* PlatformCursor;
#elif PLATFORM(CHROMIUM)
    // See PlatformCursor.h
#else
    typedef void* PlatformCursor;
#endif

    class Cursor {
    public:
        enum Type {
            Pointer,
            Cross,
            Hand,
            IBeam,
            Wait,
            Help,
            EastResize,
            NorthResize,
            NorthEastResize,
            NorthWestResize,
            SouthResize,
            SouthEastResize,
            SouthWestResize,
            WestResize,
            NorthSouthResize,
            EastWestResize,
            NorthEastSouthWestResize,
            NorthWestSouthEastResize,
            ColumnResize,
            RowResize,
            MiddlePanning,
            EastPanning,
            NorthPanning,
            NorthEastPanning,
            NorthWestPanning,
            SouthPanning,
            SouthEastPanning,
            SouthWestPanning,
            WestPanning,
            Move,
            VerticalText,
            Cell,
            ContextMenu,
            Alias,
            Progress,
            NoDrop,
            Copy,
            None,
            NotAllowed,
            ZoomIn,
            ZoomOut,
            Grab,
            Grabbing,
            Custom
        };

        static const Cursor& fromType(Cursor::Type);

        Cursor()
#if !PLATFORM(IOS)
            : m_platformCursor(0)
#endif
        {
        }

#if !PLATFORM(IOS)
        Cursor(Image*, const IntPoint& hotSpot);
        Cursor(const Cursor&);
        ~Cursor();
        Cursor& operator=(const Cursor&);

#if USE(LAZY_NATIVE_CURSOR)
        Cursor(Type);
        Type type() const { return m_type; }
        Image* image() const { return m_image.get(); }
        const IntPoint& hotSpot() const { return m_hotSpot; }
        PlatformCursor platformCursor() const;
#else
        Cursor(PlatformCursor);
        PlatformCursor impl() const { return m_platformCursor; }
#endif

     private:
#if USE(LAZY_NATIVE_CURSOR)
        void ensurePlatformCursor() const;

        Type m_type;
        RefPtr<Image> m_image;
        IntPoint m_hotSpot;
#endif

#if !PLATFORM(MAC)
        mutable PlatformCursor m_platformCursor;
#else
        mutable RetainPtr<NSCursor> m_platformCursor;
#endif
#endif // !PLATFORM(IOS)
    };

    IntPoint determineHotSpot(Image*, const IntPoint& specifiedHotSpot);
    
    const Cursor& pointerCursor();
    const Cursor& crossCursor();
    const Cursor& handCursor();
    const Cursor& moveCursor();
    const Cursor& iBeamCursor();
    const Cursor& waitCursor();
    const Cursor& helpCursor();
    const Cursor& eastResizeCursor();
    const Cursor& northResizeCursor();
    const Cursor& northEastResizeCursor();
    const Cursor& northWestResizeCursor();
    const Cursor& southResizeCursor();
    const Cursor& southEastResizeCursor();
    const Cursor& southWestResizeCursor();
    const Cursor& westResizeCursor();
    const Cursor& northSouthResizeCursor();
    const Cursor& eastWestResizeCursor();
    const Cursor& northEastSouthWestResizeCursor();
    const Cursor& northWestSouthEastResizeCursor();
    const Cursor& columnResizeCursor();
    const Cursor& rowResizeCursor();
    const Cursor& middlePanningCursor();
    const Cursor& eastPanningCursor();
    const Cursor& northPanningCursor();
    const Cursor& northEastPanningCursor();
    const Cursor& northWestPanningCursor();
    const Cursor& southPanningCursor();
    const Cursor& southEastPanningCursor();
    const Cursor& southWestPanningCursor();
    const Cursor& westPanningCursor();
    const Cursor& verticalTextCursor();
    const Cursor& cellCursor();
    const Cursor& contextMenuCursor();
    const Cursor& noDropCursor();
    const Cursor& notAllowedCursor();
    const Cursor& progressCursor();
    const Cursor& aliasCursor();
    const Cursor& zoomInCursor();
    const Cursor& zoomOutCursor();
    const Cursor& copyCursor();
    const Cursor& noneCursor();
    const Cursor& grabCursor();
    const Cursor& grabbingCursor();

} // namespace WebCore

#endif // Cursor_h
