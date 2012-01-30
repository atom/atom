/*
 * Copyright (C) 1998, 1999 Torben Weis <weis@kde.org>
 *                     1999-2001 Lars Knoll <knoll@kde.org>
 *                     1999-2001 Antti Koivisto <koivisto@kde.org>
 *                     2000-2001 Simon Hausmann <hausmann@kde.org>
 *                     2000-2001 Dirk Mueller <mueller@kde.org>
 *                     2000 Stefan Schimanski <1Stein@gmx.de>
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2008 Nokia Corporation and/or its subsidiary(-ies)
 * Copyright (C) 2008 Eric Seidel <eric@webkit.org>
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
 */

#ifndef Frame_h
#define Frame_h

#include "AdjustViewSizeOrNot.h"
#include "AnimationController.h"
#include "DragImage.h"
#include "Editor.h"
#include "EventHandler.h"
#include "FrameLoader.h"
#include "FrameSelection.h"
#include "FrameTree.h"
#include "NavigationScheduler.h"
#include "ScriptController.h"
#include "UserScriptTypes.h"

#if PLATFORM(WIN)
#include "FrameWin.h"
#endif

#if USE(TILED_BACKING_STORE)
#include "TiledBackingStoreClient.h"
#endif

#if PLATFORM(MAC)
#ifndef __OBJC__
class NSArray;
class NSMutableDictionary;
class NSString;
#endif
#endif

#if PLATFORM(WIN)
typedef struct HBITMAP__* HBITMAP;
#endif

namespace WebCore {

    class Document;
    class FrameDestructionObserver;
    class FrameView;
    class HTMLTableCellElement;
    class RegularExpression;
    class RenderPart;
    class TiledBackingStore;

#if !USE(TILED_BACKING_STORE)
    class TiledBackingStoreClient { };
#endif

    class Frame : public RefCounted<Frame>, public TiledBackingStoreClient {
    public:
        static PassRefPtr<Frame> create(Page*, HTMLFrameOwnerElement*, FrameLoaderClient*);

        void init();
        void setView(PassRefPtr<FrameView>);
        void createView(const IntSize&, const Color&, bool, const IntSize&, bool,
            ScrollbarMode = ScrollbarAuto, bool horizontalLock = false,
            ScrollbarMode = ScrollbarAuto, bool verticalLock = false);

        ~Frame();

        void addDestructionObserver(FrameDestructionObserver*);
        void removeDestructionObserver(FrameDestructionObserver*);

        void detachFromPage();
        void pageDestroyed();
        void disconnectOwnerElement();

        Page* page() const;
        HTMLFrameOwnerElement* ownerElement() const;

        Document* document() const;
        FrameView* view() const;

        Editor* editor() const;
        EventHandler* eventHandler() const;
        FrameLoader* loader() const;
        NavigationScheduler* navigationScheduler() const;
        FrameSelection* selection() const;
        FrameTree* tree() const;
        AnimationController* animation() const;
        ScriptController* script();
        
        RenderView* contentRenderer() const; // Root of the render tree for the document contained in this frame.
        RenderPart* ownerRenderer() const; // Renderer for the element that contains this frame.

        void transferChildFrameToNewDocument();

#if ENABLE(PAGE_VISIBILITY_API)
        void dispatchVisibilityStateChangeEvent();
#endif

    // ======== All public functions below this point are candidates to move out of Frame into another class. ========

        bool isDisconnected() const;
        void setIsDisconnected(bool);
        bool excludeFromTextSearch() const;
        void setExcludeFromTextSearch(bool);

        void injectUserScripts(UserScriptInjectionTime);
        
        String layerTreeAsText(bool showDebugInfo = false) const;

        // Unlike most accessors in this class, domWindow() always creates a new DOMWindow if m_domWindow is null.
        // Callers that don't need a new DOMWindow to be created should use existingDOMWindow().
        DOMWindow* domWindow() const;
        DOMWindow* existingDOMWindow() { return m_domWindow.get(); }
        void setDOMWindow(DOMWindow*);
        void clearDOMWindow();

        static Frame* frameForWidget(const Widget*);

        Settings* settings() const; // can be NULL

        void setPrinting(bool printing, const FloatSize& pageSize, const FloatSize& originalPageSize, float maximumShrinkRatio, AdjustViewSizeOrNot);
        FloatSize resizePageRectsKeepingRatio(const FloatSize& originalSize, const FloatSize& expectedSize);

        bool inViewSourceMode() const;
        void setInViewSourceMode(bool = true);

        void setDocument(PassRefPtr<Document>);

        void setPageZoomFactor(float factor);
        float pageZoomFactor() const { return m_pageZoomFactor; }
        void setTextZoomFactor(float factor);
        float textZoomFactor() const { return m_textZoomFactor; }
        void setPageAndTextZoomFactors(float pageZoomFactor, float textZoomFactor);

        // Scale factor of this frame with respect to the container.
        float frameScaleFactor() const;

#if USE(ACCELERATED_COMPOSITING)
        void deviceOrPageScaleFactorChanged();
#endif

#if ENABLE(ORIENTATION_EVENTS)
        // Orientation is the interface orientation in degrees. Some examples are:
        //  0 is straight up; -90 is when the device is rotated 90 clockwise;
        //  90 is when rotated counter clockwise.
        void sendOrientationChangeEvent(int orientation);
        int orientation() const { return m_orientation; }
#endif

        void clearTimers();
        static void clearTimers(FrameView*, Document*);

        String documentTypeString() const;

        String displayStringModifiedByEncoding(const String&) const;

        DragImageRef nodeImage(Node*);
        DragImageRef dragImageForSelection();

        VisiblePosition visiblePositionForPoint(const LayoutPoint& framePoint);
        Document* documentAtPoint(const IntPoint& windowPoint);
        PassRefPtr<Range> rangeForPoint(const LayoutPoint& framePoint);

        String searchForLabelsAboveCell(RegularExpression*, HTMLTableCellElement*, size_t* resultDistanceFromStartOfCell);
        String searchForLabelsBeforeElement(const Vector<String>& labels, Element*, size_t* resultDistance, bool* resultIsInCellAbove);
        String matchLabelsAgainstElement(const Vector<String>& labels, Element*);
        
#if PLATFORM(MAC)
        NSImage* selectionImage(bool forceBlackText = false) const;
        NSImage* rangeImage(Range*, bool forceBlackText = false) const;
        NSImage* snapshotDragImage(Node*, NSRect* imageRect, NSRect* elementRect) const;
        NSImage* imageFromRect(NSRect) const;
#endif

        // Should only be called on the main frame of a page.
        void notifyChromeClientWheelEventHandlerCountChanged() const;

    // ========

    private:
        Frame(Page*, HTMLFrameOwnerElement*, FrameLoaderClient*);

        void injectUserScriptsForWorld(DOMWrapperWorld*, const UserScriptVector&, UserScriptInjectionTime);

        HashSet<FrameDestructionObserver*> m_destructionObservers;

        Page* m_page;
        mutable FrameTree m_treeNode;
        mutable FrameLoader m_loader;
        mutable NavigationScheduler m_navigationScheduler;

        mutable RefPtr<DOMWindow> m_domWindow;

        HTMLFrameOwnerElement* m_ownerElement;
        RefPtr<FrameView> m_view;
        RefPtr<Document> m_doc;

        ScriptController m_script;

        mutable Editor m_editor;
        mutable FrameSelection m_selection;
        mutable EventHandler m_eventHandler;
        mutable AnimationController m_animationController;

        float m_pageZoomFactor;
        float m_textZoomFactor;

#if ENABLE(ORIENTATION_EVENTS)
        int m_orientation;
#endif

        bool m_inViewSourceMode;
        bool m_isDisconnected;
        bool m_excludeFromTextSearch;

#if USE(TILED_BACKING_STORE)
    // FIXME: The tiled backing store belongs in FrameView, not Frame.

    public:
        TiledBackingStore* tiledBackingStore() const { return m_tiledBackingStore.get(); }
        void setTiledBackingStoreEnabled(bool);

    private:
        // TiledBackingStoreClient interface
        virtual void tiledBackingStorePaintBegin();
        virtual void tiledBackingStorePaint(GraphicsContext*, const IntRect&);
        virtual void tiledBackingStorePaintEnd(const Vector<IntRect>& paintedArea);
        virtual IntRect tiledBackingStoreContentsRect();
        virtual IntRect tiledBackingStoreVisibleRect();
        virtual Color tiledBackingStoreBackgroundColor() const;

        OwnPtr<TiledBackingStore> m_tiledBackingStore;
#endif

    };

    inline void Frame::init()
    {
        m_loader.init();
    }

    inline FrameLoader* Frame::loader() const
    {
        return &m_loader;
    }

    inline NavigationScheduler* Frame::navigationScheduler() const
    {
        return &m_navigationScheduler;
    }

    inline FrameView* Frame::view() const
    {
        return m_view.get();
    }

    inline ScriptController* Frame::script()
    {
        return &m_script;
    }

    inline Document* Frame::document() const
    {
        return m_doc.get();
    }

    inline FrameSelection* Frame::selection() const
    {
        return &m_selection;
    }

    inline Editor* Frame::editor() const
    {
        return &m_editor;
    }

    inline AnimationController* Frame::animation() const
    {
        return &m_animationController;
    }

    inline HTMLFrameOwnerElement* Frame::ownerElement() const
    {
        return m_ownerElement;
    }

    inline bool Frame::isDisconnected() const
    {
        return m_isDisconnected;
    }

    inline void Frame::setIsDisconnected(bool isDisconnected)
    {
        m_isDisconnected = isDisconnected;
    }

    inline bool Frame::excludeFromTextSearch() const
    {
        return m_excludeFromTextSearch;
    }

    inline void Frame::setExcludeFromTextSearch(bool exclude)
    {
        m_excludeFromTextSearch = exclude;
    }

    inline bool Frame::inViewSourceMode() const
    {
        return m_inViewSourceMode;
    }

    inline void Frame::setInViewSourceMode(bool mode)
    {
        m_inViewSourceMode = mode;
    }

    inline FrameTree* Frame::tree() const
    {
        return &m_treeNode;
    }

    inline Page* Frame::page() const
    {
        return m_page;
    }

    inline void Frame::detachFromPage()
    {
        m_page = 0;
    }

    inline EventHandler* Frame::eventHandler() const
    {
        return &m_eventHandler;
    }

} // namespace WebCore

#endif // Frame_h
