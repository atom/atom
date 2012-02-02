/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef FrameSelection_h
#define FrameSelection_h

#include "EditingStyle.h"
#include "IntRect.h"
#include "LayoutTypes.h"
#include "Range.h"
#include "ScrollBehavior.h"
#include "Timer.h"
#include "VisibleSelection.h"
#include <wtf/Noncopyable.h>

namespace WebCore {

class CharacterData;
class CSSMutableStyleDeclaration;
class Frame;
class GraphicsContext;
class HTMLFormElement;
class RenderObject;
class RenderView;
class Settings;
class VisiblePosition;

enum EUserTriggered { NotUserTriggered = 0, UserTriggered = 1 };

class CaretBase {
    WTF_MAKE_NONCOPYABLE(CaretBase);
    WTF_MAKE_FAST_ALLOCATED;
protected:
    enum CaretVisibility { Visible, Hidden };
    explicit CaretBase(CaretVisibility = Hidden);

    void invalidateCaretRect(Node*, bool caretRectChanged = false);
    void clearCaretRect();
    bool updateCaretRect(Document*, const VisiblePosition& caretPosition);
    LayoutRect absoluteBoundsForLocalRect(Node*, const LayoutRect&) const;
    LayoutRect caretRepaintRect(Node*) const;
    bool shouldRepaintCaret(const RenderView*, bool isContentEditable) const;
    void paintCaret(Node*, GraphicsContext*, const LayoutPoint&, const LayoutRect& clipRect) const;
    RenderObject* caretRenderer(Node*) const;

    const LayoutRect& localCaretRectWithoutUpdate() const { return m_caretLocalRect; }

    bool shouldUpdateCaretRect() const { return m_caretRectNeedsUpdate; }
    void setCaretRectNeedsUpdate() { m_caretRectNeedsUpdate = true; }

    void setCaretVisibility(CaretVisibility visibility) { m_caretVisibility = visibility; }
    bool caretIsVisible() const { return m_caretVisibility == Visible; }
    CaretVisibility caretVisibility() const { return m_caretVisibility; }

private:
    LayoutRect m_caretLocalRect; // caret rect in coords local to the renderer responsible for painting the caret
    bool m_caretRectNeedsUpdate; // true if m_caretRect (and m_absCaretBounds in FrameSelection) need to be calculated
    CaretVisibility m_caretVisibility;
};

class DragCaretController : private CaretBase {
    WTF_MAKE_NONCOPYABLE(DragCaretController);
    WTF_MAKE_FAST_ALLOCATED;
public:
    static PassOwnPtr<DragCaretController> create();

    RenderObject* caretRenderer() const;
    void paintDragCaret(Frame*, GraphicsContext*, const LayoutPoint&, const LayoutRect& clipRect) const;

    bool isContentEditable() const { return m_position.rootEditableElement(); }
    bool isContentRichlyEditable() const;

    bool hasCaret() const { return m_position.isNotNull(); }
    const VisiblePosition& caretPosition() { return m_position; }
    void setCaretPosition(const VisiblePosition&);
    void clear() { setCaretPosition(VisiblePosition()); }

    void nodeWillBeRemoved(Node*);

private:
    DragCaretController();

    VisiblePosition m_position;
};

class FrameSelection : private CaretBase {
    WTF_MAKE_NONCOPYABLE(FrameSelection);
    WTF_MAKE_FAST_ALLOCATED;
public:
    enum EAlteration { AlterationMove, AlterationExtend };
    enum CursorAlignOnScroll { AlignCursorOnScrollIfNeeded,
                               AlignCursorOnScrollAlways };
    enum SetSelectionOption {
        // 1 << 0 is reserved for EUserTriggered
        CloseTyping = 1 << 1,
        ClearTypingStyle = 1 << 2,
        SpellCorrectionTriggered = 1 << 3,
        DoNotSetFocus = 1 << 4,
    };
    typedef unsigned SetSelectionOptions; // Union of values in SetSelectionOption and EUserTriggered
    static inline EUserTriggered selectionOptionsToUserTriggered(SetSelectionOptions options)
    {
        return static_cast<EUserTriggered>(options & UserTriggered);
    }

    FrameSelection(Frame* = 0);

    Element* rootEditableElement() const { return m_selection.rootEditableElement(); }
    Element* rootEditableElementOrDocumentElement() const;
    bool isContentEditable() const { return m_selection.isContentEditable(); }
    bool isContentRichlyEditable() const { return m_selection.isContentRichlyEditable(); }
     
    void moveTo(const Range*, EAffinity, EUserTriggered = NotUserTriggered);
    void moveTo(const VisiblePosition&, EUserTriggered = NotUserTriggered, CursorAlignOnScroll = AlignCursorOnScrollIfNeeded);
    void moveTo(const VisiblePosition&, const VisiblePosition&, EUserTriggered = NotUserTriggered);
    void moveTo(const Position&, EAffinity, EUserTriggered = NotUserTriggered);
    void moveTo(const Position&, const Position&, EAffinity, EUserTriggered = NotUserTriggered);

    const VisibleSelection& selection() const { return m_selection; }
    void setSelection(const VisibleSelection&, SetSelectionOptions = CloseTyping | ClearTypingStyle, CursorAlignOnScroll = AlignCursorOnScrollIfNeeded, TextGranularity = CharacterGranularity);
    void setSelection(const VisibleSelection& selection, TextGranularity granularity) { setSelection(selection, CloseTyping | ClearTypingStyle, AlignCursorOnScrollIfNeeded, granularity); }
    bool setSelectedRange(Range*, EAffinity, bool closeTyping);
    void selectAll();
    void clear();
    
    // Call this after doing user-triggered selections to make it easy to delete the frame you entirely selected.
    void selectFrameElementInParentIfFullySelected();

    bool contains(const LayoutPoint&);

    VisibleSelection::SelectionType selectionType() const { return m_selection.selectionType(); }

    EAffinity affinity() const { return m_selection.affinity(); }

    bool modify(EAlteration, SelectionDirection, TextGranularity, EUserTriggered = NotUserTriggered);
    enum VerticalDirection { DirectionUp, DirectionDown };
    bool modify(EAlteration, unsigned verticalDistance, VerticalDirection, EUserTriggered = NotUserTriggered, CursorAlignOnScroll = AlignCursorOnScrollIfNeeded);

    TextGranularity granularity() const { return m_granularity; }

    void setStart(const VisiblePosition &, EUserTriggered = NotUserTriggered);
    void setEnd(const VisiblePosition &, EUserTriggered = NotUserTriggered);
    
    void setBase(const VisiblePosition&, EUserTriggered = NotUserTriggered);
    void setBase(const Position&, EAffinity, EUserTriggered = NotUserTriggered);
    void setExtent(const VisiblePosition&, EUserTriggered = NotUserTriggered);
    void setExtent(const Position&, EAffinity, EUserTriggered = NotUserTriggered);

    Position base() const { return m_selection.base(); }
    Position extent() const { return m_selection.extent(); }
    Position start() const { return m_selection.start(); }
    Position end() const { return m_selection.end(); }

    // Return the renderer that is responsible for painting the caret (in the selection start node)
    RenderObject* caretRenderer() const;

    // Caret rect local to the caret's renderer
    LayoutRect localCaretRect();

    // Bounds of (possibly transformed) caret in absolute coords
    LayoutRect absoluteCaretBounds();
    void setCaretRectNeedsUpdate() { CaretBase::setCaretRectNeedsUpdate(); }

    void willBeModified(EAlteration, SelectionDirection);

    bool isNone() const { return m_selection.isNone(); }
    bool isCaret() const { return m_selection.isCaret(); }
    bool isRange() const { return m_selection.isRange(); }
    bool isCaretOrRange() const { return m_selection.isCaretOrRange(); }
    bool isInPasswordField() const;
    bool isAll(EditingBoundaryCrossingRule rule = CannotCrossEditingBoundary) const { return m_selection.isAll(rule); }
    
    PassRefPtr<Range> toNormalizedRange() const { return m_selection.toNormalizedRange(); }

    void debugRenderer(RenderObject*, bool selected) const;

    void nodeWillBeRemoved(Node*);
    void textWillBeReplaced(CharacterData*, unsigned offset, unsigned oldLength, unsigned newLength);

    void setCaretVisible(bool caretIsVisible) { setCaretVisibility(caretIsVisible ? Visible : Hidden); }
    void clearCaretRectIfNeeded();
    bool recomputeCaretRect();
    void invalidateCaretRect();
    void paintCaret(GraphicsContext*, const LayoutPoint&, const LayoutRect& clipRect);

    // Used to suspend caret blinking while the mouse is down.
    void setCaretBlinkingSuspended(bool suspended) { m_isCaretBlinkingSuspended = suspended; }
    bool isCaretBlinkingSuspended() const { return m_isCaretBlinkingSuspended; }

    // Focus
    void setFocused(bool);
    bool isFocused() const { return m_focused; }
    bool isFocusedAndActive() const;
    void pageActivationChanged();

    // Painting.
    void updateAppearance();

    void updateSecureKeyboardEntryIfActive();

#ifndef NDEBUG
    void formatForDebugger(char* buffer, unsigned length) const;
    void showTreeForThis() const;
#endif

    bool shouldChangeSelection(const VisibleSelection&) const;
    bool shouldDeleteSelection(const VisibleSelection&) const;
    enum EndPointsAdjustmentMode { AdjustEndpointsAtBidiBoundary, DoNotAdjsutEndpoints };
    void setNonDirectionalSelectionIfNeeded(const VisibleSelection&, TextGranularity, EndPointsAdjustmentMode = DoNotAdjsutEndpoints);
    void setFocusedNodeIfNeeded();
    void notifyRendererOfSelectionChange(EUserTriggered);

    void paintDragCaret(GraphicsContext*, const LayoutPoint&, const LayoutRect& clipRect) const;

    EditingStyle* typingStyle() const;
    PassRefPtr<CSSMutableStyleDeclaration> copyTypingStyle() const;
    void setTypingStyle(PassRefPtr<EditingStyle>);
    void clearTypingStyle();

    FloatRect bounds(bool clipToVisibleContent = true) const;

    void getClippedVisibleTextRectangles(Vector<FloatRect>&) const;

    HTMLFormElement* currentForm() const;

    void revealSelection(const ScrollAlignment& = ScrollAlignment::alignCenterIfNeeded, bool revealExtent = false);
    void setSelectionFromNone();

private:
    enum EPositionType { START, END, BASE, EXTENT };

    void respondToNodeModification(Node*, bool baseRemoved, bool extentRemoved, bool startRemoved, bool endRemoved);
    TextDirection directionOfEnclosingBlock();
    TextDirection directionOfSelection();

    VisiblePosition positionForPlatform(bool isGetStart) const;
    VisiblePosition startForPlatform() const;
    VisiblePosition endForPlatform() const;

    VisiblePosition modifyExtendingRight(TextGranularity);
    VisiblePosition modifyExtendingForward(TextGranularity);
    VisiblePosition modifyMovingRight(TextGranularity);
    VisiblePosition modifyMovingForward(TextGranularity);
    VisiblePosition modifyExtendingLeft(TextGranularity);
    VisiblePosition modifyExtendingBackward(TextGranularity);
    VisiblePosition modifyMovingLeft(TextGranularity);
    VisiblePosition modifyMovingBackward(TextGranularity);

    LayoutUnit lineDirectionPointForBlockDirectionNavigation(EPositionType);
    
    void notifyAccessibilityForSelectionChange();

    void focusedOrActiveStateChanged();

    void caretBlinkTimerFired(Timer<FrameSelection>*);

    void setUseSecureKeyboardEntry(bool);

    void setCaretVisibility(CaretVisibility);

    bool dispatchSelectStart();
  
    bool visualWordMovementEnabled() const;

    Frame* m_frame;

    LayoutUnit m_xPosForVerticalArrowNavigation;

    VisibleSelection m_selection;
    VisiblePosition m_originalBase; // Used to store base before the adjustment at bidi boundary
    TextGranularity m_granularity;

    RefPtr<EditingStyle> m_typingStyle;

    Timer<FrameSelection> m_caretBlinkTimer;
    LayoutRect m_absCaretBounds; // absolute bounding rect for the caret
    LayoutRect m_absoluteCaretRepaintBounds;
    bool m_absCaretBoundsDirty : 1;
    bool m_caretPaint : 1;
    bool m_isCaretBlinkingSuspended : 1;
    bool m_focused : 1;
};

inline EditingStyle* FrameSelection::typingStyle() const
{
    return m_typingStyle.get();
}

inline void FrameSelection::clearTypingStyle()
{
    m_typingStyle.clear();
}

inline void FrameSelection::setTypingStyle(PassRefPtr<EditingStyle> style)
{
    m_typingStyle = style;
}

#if !(PLATFORM(MAC) || PLATFORM(GTK) || PLATFORM(CHROMIUM))
inline void FrameSelection::notifyAccessibilityForSelectionChange()
{
}
#endif

} // namespace WebCore

#ifndef NDEBUG
// Outside the WebCore namespace for ease of invocation from gdb.
void showTree(const WebCore::FrameSelection&);
void showTree(const WebCore::FrameSelection*);
#endif

#endif // FrameSelection_h
