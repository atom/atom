/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2006 Apple Computer, Inc.
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

#ifndef RenderView_h
#define RenderView_h

#include "FrameView.h"
#include "LayoutState.h"
#include "PODFreeListArena.h"
#include "RenderBlock.h"
#include <wtf/ListHashSet.h>
#include <wtf/OwnPtr.h>

namespace WebCore {

class RenderFlowThread;
class RenderRegion;
class RenderWidget;

#if USE(ACCELERATED_COMPOSITING)
class RenderLayerCompositor;
#endif

typedef ListHashSet<RenderFlowThread*> RenderFlowThreadList;

class RenderView : public RenderBlock {
public:
    RenderView(Node*, FrameView*);
    virtual ~RenderView();

    virtual const char* renderName() const { return "RenderView"; }

    virtual bool isRenderView() const { return true; }

    virtual bool requiresLayer() const { return true; }

    virtual bool isChildAllowed(RenderObject*, RenderStyle*) const;

    virtual void layout();
    virtual void computeLogicalWidth();
    virtual void computeLogicalHeight();
    virtual void computePreferredLogicalWidths();

    // The same as the FrameView's layoutHeight/layoutWidth but with null check guards.
    int viewHeight() const;
    int viewWidth() const;
    int viewLogicalWidth() const { return style()->isHorizontalWritingMode() ? viewWidth() : viewHeight(); }
    int viewLogicalHeight() const;

    float zoomFactor() const;

    FrameView* frameView() const { return m_frameView; }

    virtual void computeRectForRepaint(RenderBoxModelObject* repaintContainer, IntRect&, bool fixed = false) const;
    virtual void repaintViewRectangle(const IntRect&, bool immediate = false);
    // Repaint the view, and all composited layers that intersect the given absolute rectangle.
    // FIXME: ideally we'd never have to do this, if all repaints are container-relative.
    virtual void repaintRectangleInViewAndCompositedLayers(const IntRect&, bool immediate = false);

    virtual void paint(PaintInfo&, const LayoutPoint&);
    virtual void paintBoxDecorations(PaintInfo&, const IntPoint&);

    enum SelectionRepaintMode { RepaintNewXOROld, RepaintNewMinusOld, RepaintNothing };
    void setSelection(RenderObject* start, int startPos, RenderObject* end, int endPos, SelectionRepaintMode = RepaintNewXOROld);
    void getSelection(RenderObject*& startRenderer, int& startOffset, RenderObject*& endRenderer, int& endOffset) const;
    void clearSelection();
    RenderObject* selectionStart() const { return m_selectionStart; }
    RenderObject* selectionEnd() const { return m_selectionEnd; }
    IntRect selectionBounds(bool clipToVisibleContent = true) const;
    void selectionStartEnd(int& startPos, int& endPos) const;

    bool printing() const;

    virtual void absoluteRects(Vector<LayoutRect>&, const LayoutPoint& accumulatedOffset) const;
    virtual void absoluteQuads(Vector<FloatQuad>&, bool* wasFixed) const;

#if USE(ACCELERATED_COMPOSITING)
    void setMaximalOutlineSize(int o);
#else
    void setMaximalOutlineSize(int o) { m_maximalOutlineSize = o; }
#endif
    int maximalOutlineSize() const { return m_maximalOutlineSize; }

    virtual IntRect viewRect() const;

    void updateWidgetPositions();
    void addWidget(RenderWidget*);
    void removeWidget(RenderWidget*);
    
    void notifyWidgets(WidgetNotification);

    // layoutDelta is used transiently during layout to store how far an object has moved from its
    // last layout location, in order to repaint correctly.
    // If we're doing a full repaint m_layoutState will be 0, but in that case layoutDelta doesn't matter.
    LayoutSize layoutDelta() const
    {
        return m_layoutState ? m_layoutState->m_layoutDelta : LayoutSize();
    }
    void addLayoutDelta(const LayoutSize& delta) 
    {
        if (m_layoutState)
            m_layoutState->m_layoutDelta += delta;
    }

    bool doingFullRepaint() const { return m_frameView->needsFullRepaint(); }

    // Subtree push/pop
    void pushLayoutState(RenderObject*);
    void popLayoutState(RenderObject*) { return popLayoutState(); } // Just doing this to keep popLayoutState() private and to make the subtree calls symmetrical.

    bool shouldDisableLayoutStateForSubtree(RenderObject*) const;

    // Returns true if layoutState should be used for its cached offset and clip.
    bool layoutStateEnabled() const { return m_layoutStateDisableCount == 0 && m_layoutState; }
    LayoutState* layoutState() const { return m_layoutState; }

    virtual void updateHitTestResult(HitTestResult&, const LayoutPoint&);

    unsigned pageLogicalHeight() const { return m_pageLogicalHeight; }
    void setPageLogicalHeight(unsigned height)
    {
        if (m_pageLogicalHeight != height) {
            m_pageLogicalHeight = height;
            m_pageLogicalHeightChanged = true;
        }
    }

    // FIXME: These functions are deprecated. No code should be added that uses these.
    int bestTruncatedAt() const { return m_legacyPrinting.m_bestTruncatedAt; }
    void setBestTruncatedAt(int y, RenderBoxModelObject* forRenderer, bool forcedBreak = false);
    int truncatedAt() const { return m_legacyPrinting.m_truncatedAt; }
    void setTruncatedAt(int y)
    { 
        m_legacyPrinting.m_truncatedAt = y;
        m_legacyPrinting.m_bestTruncatedAt = 0;
        m_legacyPrinting.m_truncatorWidth = 0;
        m_legacyPrinting.m_forcedPageBreak = false;
    }
    const IntRect& printRect() const { return m_legacyPrinting.m_printRect; }
    void setPrintRect(const IntRect& r) { m_legacyPrinting.m_printRect = r; }
    // End deprecated functions.

    // Notifications that this view became visible in a window, or will be
    // removed from the window.
    void didMoveOnscreen();
    void willMoveOffscreen();

#if USE(ACCELERATED_COMPOSITING)
    RenderLayerCompositor* compositor();
    bool usesCompositing() const;
#endif

    IntRect unscaledDocumentRect() const;
    LayoutRect backgroundRect(RenderBox* backgroundRenderer) const;

    IntRect documentRect() const;

    RenderFlowThread* ensureRenderFlowThreadWithName(const AtomicString& flowThread);
    bool hasRenderFlowThreads() const { return m_renderFlowThreadList && !m_renderFlowThreadList->isEmpty(); }
    void layoutRenderFlowThreads();
    bool isRenderFlowThreadOrderDirty() const { return m_isRenderFlowThreadOrderDirty; }
    void setIsRenderFlowThreadOrderDirty(bool dirty)
    {
        m_isRenderFlowThreadOrderDirty = dirty;
        if (dirty)
            setNeedsLayout(true);
    }
    const RenderFlowThreadList* renderFlowThreadList() const { return m_renderFlowThreadList.get(); }

    RenderFlowThread* currentRenderFlowThread() const { return m_currentRenderFlowThread; }
    void setCurrentRenderFlowThread(RenderFlowThread* flowThread) { m_currentRenderFlowThread = flowThread; }

    RenderRegion* currentRenderRegion() const { return m_currentRenderRegion; }
    void setCurrentRenderRegion(RenderRegion* region) { m_currentRenderRegion = region; }

    void styleDidChange(StyleDifference, const RenderStyle* oldStyle);

    IntervalArena* intervalArena();

protected:
    virtual void mapLocalToContainer(RenderBoxModelObject* repaintContainer, bool useTransforms, bool fixed, TransformState&, bool* wasFixed = 0) const;
    virtual void mapAbsoluteToLocalPoint(bool fixed, bool useTransforms, TransformState&) const;
    virtual bool requiresColumns(int desiredColumnCount) const OVERRIDE;

private:
    virtual void calcColumnWidth() OVERRIDE;

    bool shouldRepaint(const IntRect& r) const;

    // These functions may only be accessed by LayoutStateMaintainer.
    void pushLayoutState(RenderFlowThread*, bool regionsChanged);
    bool pushLayoutState(RenderBox* renderer, const LayoutSize& offset, LayoutUnit pageHeight = 0, bool pageHeightChanged = false, ColumnInfo* colInfo = 0)
    {
        // We push LayoutState even if layoutState is disabled because it stores layoutDelta too.
        if (!doingFullRepaint() || m_layoutState->isPaginated() || renderer->hasColumns() || renderer->inRenderFlowThread()
            || m_layoutState->currentLineGrid() || (renderer->style()->lineGrid() != RenderStyle::initialLineGrid() && renderer->isBlockFlow())) {
            m_layoutState = new (renderArena()) LayoutState(m_layoutState, renderer, offset, pageHeight, pageHeightChanged, colInfo);
            return true;
        }
        return false;
    }

    void popLayoutState()
    {
        LayoutState* state = m_layoutState;
        m_layoutState = state->m_next;
        state->destroy(renderArena());
    }

    // Suspends the LayoutState optimization. Used under transforms that cannot be represented by
    // LayoutState (common in SVG) and when manipulating the render tree during layout in ways
    // that can trigger repaint of a non-child (e.g. when a list item moves its list marker around).
    // Note that even when disabled, LayoutState is still used to store layoutDelta.
    // These functions may only be accessed by LayoutStateMaintainer or LayoutStateDisabler.
    void disableLayoutState() { m_layoutStateDisableCount++; }
    void enableLayoutState() { ASSERT(m_layoutStateDisableCount > 0); m_layoutStateDisableCount--; }

    size_t getRetainedWidgets(Vector<RenderWidget*>&);
    void releaseWidgets(Vector<RenderWidget*>&);
    
    friend class LayoutStateMaintainer;
    friend class LayoutStateDisabler;

protected:
    FrameView* m_frameView;

    RenderObject* m_selectionStart;
    RenderObject* m_selectionEnd;
    int m_selectionStartPos;
    int m_selectionEndPos;

    // FIXME: Only used by embedded WebViews inside AppKit NSViews.  Find a way to remove.
    struct LegacyPrinting {
        LegacyPrinting()
            : m_bestTruncatedAt(0)
            , m_truncatedAt(0)
            , m_truncatorWidth(0)
            , m_forcedPageBreak(false)
        { }

        int m_bestTruncatedAt;
        int m_truncatedAt;
        int m_truncatorWidth;
        IntRect m_printRect;
        bool m_forcedPageBreak;
    };
    LegacyPrinting m_legacyPrinting;
    // End deprecated members.

    int m_maximalOutlineSize; // Used to apply a fudge factor to dirty-rect checks on blocks/tables.

    typedef HashSet<RenderWidget*> RenderWidgetSet;
    RenderWidgetSet m_widgets;
    
private:
    unsigned m_pageLogicalHeight;
    bool m_pageLogicalHeightChanged;
    bool m_isRenderFlowThreadOrderDirty;
    LayoutState* m_layoutState;
    unsigned m_layoutStateDisableCount;
#if USE(ACCELERATED_COMPOSITING)
    OwnPtr<RenderLayerCompositor> m_compositor;
#endif
    OwnPtr<RenderFlowThreadList> m_renderFlowThreadList;
    RenderFlowThread* m_currentRenderFlowThread;
    RenderRegion* m_currentRenderRegion;
    RefPtr<IntervalArena> m_intervalArena;
};

inline RenderView* toRenderView(RenderObject* object)
{
    ASSERT(!object || object->isRenderView());
    return static_cast<RenderView*>(object);
}

inline const RenderView* toRenderView(const RenderObject* object)
{
    ASSERT(!object || object->isRenderView());
    return static_cast<const RenderView*>(object);
}

// This will catch anyone doing an unnecessary cast.
void toRenderView(const RenderView*);


ALWAYS_INLINE RenderView* RenderObject::view() const
{
    return toRenderView(document()->renderer());
}

// Stack-based class to assist with LayoutState push/pop
class LayoutStateMaintainer {
    WTF_MAKE_NONCOPYABLE(LayoutStateMaintainer);
public:
    // ctor to push now
    LayoutStateMaintainer(RenderView* view, RenderBox* root, LayoutSize offset, bool disableState = false, LayoutUnit pageHeight = 0, bool pageHeightChanged = false, ColumnInfo* colInfo = 0)
        : m_view(view)
        , m_disabled(disableState)
        , m_didStart(false)
        , m_didEnd(false)
        , m_didCreateLayoutState(false)
    {
        push(root, offset, pageHeight, pageHeightChanged, colInfo);
    }
    
    // ctor to maybe push later
    LayoutStateMaintainer(RenderView* view)
        : m_view(view)
        , m_disabled(false)
        , m_didStart(false)
        , m_didEnd(false)
        , m_didCreateLayoutState(false)
    {
    }
    
    LayoutStateMaintainer(RenderView* view, RenderFlowThread* flowThread, bool regionsChanged)
        : m_view(view)
        , m_disabled(false)
        , m_didStart(false)
        , m_didEnd(false)
        , m_didCreateLayoutState(false)
    {
        push(flowThread, regionsChanged);
    }
    
    ~LayoutStateMaintainer()
    {
        ASSERT(m_didStart == m_didEnd);   // if this fires, it means that someone did a push(), but forgot to pop().
    }

    void push(RenderBox* root, LayoutSize offset, LayoutUnit pageHeight = 0, bool pageHeightChanged = false, ColumnInfo* colInfo = 0)
    {
        ASSERT(!m_didStart);
        // We push state even if disabled, because we still need to store layoutDelta
        m_didCreateLayoutState = m_view->pushLayoutState(root, offset, pageHeight, pageHeightChanged, colInfo);
        if (m_disabled && m_didCreateLayoutState)
            m_view->disableLayoutState();
        m_didStart = true;
    }
    
    void push(RenderFlowThread* flowThread, bool regionsChanged)
    {
        ASSERT(!m_didStart);
        m_view->pushLayoutState(flowThread, regionsChanged);
        m_didCreateLayoutState = true;
        m_didStart = true;
    }

    void pop()
    {
        if (m_didStart) {
            ASSERT(!m_didEnd);
            if (m_didCreateLayoutState) {
                m_view->popLayoutState();
                if (m_disabled)
                    m_view->enableLayoutState();
            }
            
            m_didEnd = true;
        }
    }

    bool didPush() const { return m_didStart; }

private:
    RenderView* m_view;
    bool m_disabled : 1;        // true if the offset and clip part of layoutState is disabled
    bool m_didStart : 1;        // true if we did a push or disable
    bool m_didEnd : 1;          // true if we popped or re-enabled
    bool m_didCreateLayoutState : 1; // true if we actually made a layout state.
};

class LayoutStateDisabler {
    WTF_MAKE_NONCOPYABLE(LayoutStateDisabler);
public:
    LayoutStateDisabler(RenderView* view)
        : m_view(view)
    {
        if (m_view)
            m_view->disableLayoutState();
    }

    ~LayoutStateDisabler()
    {
        if (m_view)
            m_view->enableLayoutState();
    }
private:
    RenderView* m_view;
};

} // namespace WebCore

#endif // RenderView_h
