/*
 * Copyright (C) 2004, 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef Scrollbar_h
#define Scrollbar_h

#include "ScrollTypes.h"
#include "Timer.h"
#include "Widget.h"
#include <wtf/MathExtras.h>
#include <wtf/PassRefPtr.h>

namespace WebCore {

class GraphicsContext;
class IntRect;
class PlatformMouseEvent;
class ScrollableArea;
class ScrollbarTheme;

class Scrollbar : public Widget {
public:
    // Must be implemented by platforms that can't simply use the Scrollbar base class.  Right now the only platform that is not using the base class is GTK.
    static PassRefPtr<Scrollbar> createNativeScrollbar(ScrollableArea*, ScrollbarOrientation orientation, ScrollbarControlSize size);

    virtual ~Scrollbar();

    // Called by the ScrollableArea when the scroll offset changes.
    void offsetDidChange();

    static int pixelsPerLineStep() { return 40; }
    static float minFractionToStepWhenPaging() { return 0.875f; }
    static int maxOverlapBetweenPages();

    void disconnectFromScrollableArea() { m_scrollableArea = 0; }
    ScrollableArea* scrollableArea() const { return m_scrollableArea; }

    virtual bool isCustomScrollbar() const { return false; }
    ScrollbarOrientation orientation() const { return m_orientation; }

    int value() const { return lroundf(m_currentPos); }
    float currentPos() const { return m_currentPos; }
    int pressedPos() const { return m_pressedPos; }
    int visibleSize() const { return m_visibleSize; }
    int totalSize() const { return m_totalSize; }
    int maximum() const { return m_totalSize - m_visibleSize; }        
    ScrollbarControlSize controlSize() const { return m_controlSize; }

    int lineStep() const { return m_lineStep; }
    int pageStep() const { return m_pageStep; }
    float pixelStep() const { return m_pixelStep; }

    ScrollbarPart pressedPart() const { return m_pressedPart; }
    ScrollbarPart hoveredPart() const { return m_hoveredPart; }
    virtual void setHoveredPart(ScrollbarPart);
    virtual void setPressedPart(ScrollbarPart);

    void setSteps(int lineStep, int pageStep, int pixelsPerStep = 1);
    void setProportion(int visibleSize, int totalSize);
    void setPressedPos(int p) { m_pressedPos = p; }
    
    virtual void paint(GraphicsContext*, const IntRect& damageRect);

    bool enabled() const { return m_enabled; }
    virtual void setEnabled(bool e);

    virtual bool isOverlayScrollbar() const;
    bool shouldParticipateInHitTesting();

    bool isWindowActive() const;

    // These methods are used for platform scrollbars to give :hover feedback.  They will not get called
    // when the mouse went down in a scrollbar, since it is assumed the scrollbar will start
    // grabbing all events in that case anyway.
    bool mouseMoved(const PlatformMouseEvent&);
    void mouseEntered();
    bool mouseExited();
    
    // Used by some platform scrollbars to know when they've been released from capture.
    bool mouseUp(const PlatformMouseEvent&);

    bool mouseDown(const PlatformMouseEvent&);

#if PLATFORM(QT)
    // For platforms that wish to handle context menu events.
    // FIXME: This is misplaced.  Normal hit testing should be used to populate a correct
    // context menu.  There's no reason why the scrollbar should have to do it.
    bool contextMenu(const PlatformMouseEvent& event);
#endif

    ScrollbarTheme* theme() const { return m_theme; }

    virtual void setParent(ScrollView*);
    virtual void setFrameRect(const IntRect&);

    virtual void invalidateRect(const IntRect&);
    
    bool suppressInvalidation() const { return m_suppressInvalidation; }
    void setSuppressInvalidation(bool s) { m_suppressInvalidation = s; }

    virtual void styleChanged() { }

    virtual IntRect convertToContainingView(const IntRect&) const;
    virtual IntRect convertFromContainingView(const IntRect&) const;
    
    virtual IntPoint convertToContainingView(const IntPoint&) const;
    virtual IntPoint convertFromContainingView(const IntPoint&) const;

protected:
    Scrollbar(ScrollableArea*, ScrollbarOrientation, ScrollbarControlSize, ScrollbarTheme* = 0);

    void updateThumb();
    virtual void updateThumbPosition();
    virtual void updateThumbProportion();

    void autoscrollTimerFired(Timer<Scrollbar>*);
    void startTimerIfNeeded(double delay);
    void stopTimerIfNeeded();
    void autoscrollPressedPart(double delay);
    ScrollDirection pressedPartScrollDirection();
    ScrollGranularity pressedPartScrollGranularity();
    
    void moveThumb(int pos, bool draggingDocument = false);

    ScrollableArea* m_scrollableArea;
    ScrollbarOrientation m_orientation;
    ScrollbarControlSize m_controlSize;
    ScrollbarTheme* m_theme;

    int m_visibleSize;
    int m_totalSize;
    float m_currentPos;
    float m_dragOrigin;
    int m_lineStep;
    int m_pageStep;
    float m_pixelStep;

    ScrollbarPart m_hoveredPart;
    ScrollbarPart m_pressedPart;
    int m_pressedPos;
    bool m_draggingDocument;
    int m_documentDragPos;

    bool m_enabled;

    Timer<Scrollbar> m_scrollTimer;
    bool m_overlapsResizer;
    
    bool m_suppressInvalidation;

private:
    virtual bool isScrollbar() const { return true; }
    virtual AXObjectCache* axObjectCache() const;
};

} // namespace WebCore

#endif // Scrollbar_h
