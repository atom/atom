/*
 * Copyright (C) 2003, 2004, 2005, 2006, 2007 Apple Inc. All rights reserved.
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

#ifndef InlineFlowBox_h
#define InlineFlowBox_h

#include "InlineBox.h"
#include "RenderOverflow.h"
#include "ShadowData.h"

namespace WebCore {

class HitTestRequest;
class HitTestResult;
class InlineTextBox;
class RenderLineBoxList;
class VerticalPositionCache;

typedef HashMap<const InlineTextBox*, pair<Vector<const SimpleFontData*>, GlyphOverflow> > GlyphOverflowAndFallbackFontsMap;

class InlineFlowBox : public InlineBox {
public:
    InlineFlowBox(RenderObject* obj)
        : InlineBox(obj)
        , m_firstChild(0)
        , m_lastChild(0)
        , m_prevLineBox(0)
        , m_nextLineBox(0)
        , m_includeLogicalLeftEdge(false)
        , m_includeLogicalRightEdge(false)
        , m_descendantsHaveSameLineHeightAndBaseline(true)
        , m_baselineType(AlphabeticBaseline)
        , m_hasAnnotationsBefore(false)
        , m_hasAnnotationsAfter(false)
#ifndef NDEBUG
        , m_hasBadChildList(false)
#endif
    {
        // Internet Explorer and Firefox always create a marker for list items, even when the list-style-type is none.  We do not make a marker
        // in the list-style-type: none case, since it is wasteful to do so.  However, in order to match other browsers we have to pretend like
        // an invisible marker exists.  The side effect of having an invisible marker is that the quirks mode behavior of shrinking lines with no
        // text children must not apply.  This change also means that gaps will exist between image bullet list items.  Even when the list bullet
        // is an image, the line is still considered to be immune from the quirk.
        m_hasTextChildren = obj->style()->display() == LIST_ITEM;
        m_hasTextDescendants = m_hasTextChildren;
    }

#ifndef NDEBUG
    virtual ~InlineFlowBox();
    
    virtual void showLineTreeAndMark(const InlineBox* = 0, const char* = 0, const InlineBox* = 0, const char* = 0, const RenderObject* = 0, int = 0) const;
    virtual const char* boxName() const;
#endif

    InlineFlowBox* prevLineBox() const { return m_prevLineBox; }
    InlineFlowBox* nextLineBox() const { return m_nextLineBox; }
    void setNextLineBox(InlineFlowBox* n) { m_nextLineBox = n; }
    void setPreviousLineBox(InlineFlowBox* p) { m_prevLineBox = p; }

    InlineBox* firstChild() const { checkConsistency(); return m_firstChild; }
    InlineBox* lastChild() const { checkConsistency(); return m_lastChild; }

    virtual bool isLeaf() const { return false; }
    
    InlineBox* firstLeafChild() const;
    InlineBox* lastLeafChild() const;

    typedef void (*CustomInlineBoxRangeReverse)(void* userData, Vector<InlineBox*>::iterator first, Vector<InlineBox*>::iterator last);
    void collectLeafBoxesInLogicalOrder(Vector<InlineBox*>&, CustomInlineBoxRangeReverse customReverseImplementation = 0, void* userData = 0) const;

    virtual void setConstructed()
    {
        InlineBox::setConstructed();
        for (InlineBox* child = firstChild(); child; child = child->next())
            child->setConstructed();
    }

    void addToLine(InlineBox* child);
    virtual void deleteLine(RenderArena*);
    virtual void extractLine();
    virtual void attachLine();
    virtual void adjustPosition(float dx, float dy);

    virtual void extractLineBoxFromRenderObject();
    virtual void attachLineBoxToRenderObject();
    virtual void removeLineBoxFromRenderObject();

    virtual void clearTruncation();

    IntRect roundedFrameRect() const;
    
    virtual void paintBoxDecorations(PaintInfo&, const LayoutPoint&);
    virtual void paintMask(PaintInfo&, const LayoutPoint&);
    void paintFillLayers(const PaintInfo&, const Color&, const FillLayer*, const LayoutRect&, CompositeOperator = CompositeSourceOver);
    void paintFillLayer(const PaintInfo&, const Color&, const FillLayer*, const LayoutRect&, CompositeOperator = CompositeSourceOver);
    void paintBoxShadow(const PaintInfo&, RenderStyle*, ShadowStyle, const LayoutRect&);
    virtual void paint(PaintInfo&, const LayoutPoint&, LayoutUnit lineTop, LayoutUnit lineBottom);
    virtual bool nodeAtPoint(const HitTestRequest&, HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset, LayoutUnit lineTop, LayoutUnit lineBottom);

    virtual RenderLineBoxList* rendererLineBoxes() const;

    // logicalLeft = left in a horizontal line and top in a vertical line.
    int marginBorderPaddingLogicalLeft() const { return marginLogicalLeft() + borderLogicalLeft() + paddingLogicalLeft(); }
    int marginBorderPaddingLogicalRight() const { return marginLogicalRight() + borderLogicalRight() + paddingLogicalRight(); }
    LayoutUnit marginLogicalLeft() const
    {
        if (!includeLogicalLeftEdge())
            return 0;
        return isHorizontal() ? boxModelObject()->marginLeft() : boxModelObject()->marginTop();
    }
    LayoutUnit marginLogicalRight() const
    {
        if (!includeLogicalRightEdge())
            return 0;
        return isHorizontal() ? boxModelObject()->marginRight() : boxModelObject()->marginBottom();
    }
    int borderLogicalLeft() const
    {
        if (!includeLogicalLeftEdge())
            return 0;
        return isHorizontal() ? renderer()->style()->borderLeftWidth() : renderer()->style()->borderTopWidth();
    }
    int borderLogicalRight() const
    {
        if (!includeLogicalRightEdge())
            return 0;
        return isHorizontal() ? renderer()->style()->borderRightWidth() : renderer()->style()->borderBottomWidth();
    }
    int paddingLogicalLeft() const
    {
        if (!includeLogicalLeftEdge())
            return 0;
        return isHorizontal() ? boxModelObject()->paddingLeft() : boxModelObject()->paddingTop();
    }
    int paddingLogicalRight() const
    {
        if (!includeLogicalRightEdge())
            return 0;
        return isHorizontal() ? boxModelObject()->paddingRight() : boxModelObject()->paddingBottom();
    }

    bool includeLogicalLeftEdge() const { return m_includeLogicalLeftEdge; }
    bool includeLogicalRightEdge() const { return m_includeLogicalRightEdge; }
    void setEdges(bool includeLeft, bool includeRight)
    {
        m_includeLogicalLeftEdge = includeLeft;
        m_includeLogicalRightEdge = includeRight;
    }

    // Helper functions used during line construction and placement.
    void determineSpacingForFlowBoxes(bool lastLine, bool isLogicallyLastRunWrapped, RenderObject* logicallyLastRunRenderer);
    int getFlowSpacingLogicalWidth();
    float placeBoxesInInlineDirection(float logicalLeft, bool& needsWordSpacing, GlyphOverflowAndFallbackFontsMap&);
    void computeLogicalBoxHeights(RootInlineBox*, LayoutUnit& maxPositionTop, LayoutUnit& maxPositionBottom,
                                  LayoutUnit& maxAscent, LayoutUnit& maxDescent, bool& setMaxAscent, bool& setMaxDescent,
                                  bool strictMode, GlyphOverflowAndFallbackFontsMap&, FontBaseline, VerticalPositionCache&);
    void adjustMaxAscentAndDescent(LayoutUnit& maxAscent, LayoutUnit& maxDescent,
                                   LayoutUnit maxPositionTop, LayoutUnit maxPositionBottom);
    void placeBoxesInBlockDirection(LayoutUnit logicalTop, LayoutUnit maxHeight, LayoutUnit maxAscent, bool strictMode, LayoutUnit& lineTop, LayoutUnit& lineBottom, bool& setLineTop,
                                    LayoutUnit& lineTopIncludingMargins, LayoutUnit& lineBottomIncludingMargins, bool& hasAnnotationsBefore, bool& hasAnnotationsAfter, FontBaseline);
    void flipLinesInBlockDirection(LayoutUnit lineTop, LayoutUnit lineBottom);
    bool requiresIdeographicBaseline(const GlyphOverflowAndFallbackFontsMap&) const;

    LayoutUnit computeOverAnnotationAdjustment(LayoutUnit allowedPosition) const;
    LayoutUnit computeUnderAnnotationAdjustment(LayoutUnit allowedPosition) const;

    void computeOverflow(LayoutUnit lineTop, LayoutUnit lineBottom, GlyphOverflowAndFallbackFontsMap&);
    
    void removeChild(InlineBox* child);

    virtual RenderObject::SelectionState selectionState();

    virtual bool canAccommodateEllipsis(bool ltr, int blockEdge, int ellipsisWidth);
    virtual float placeEllipsisBox(bool ltr, float blockLeftEdge, float blockRightEdge, float ellipsisWidth, bool&);

    bool hasTextChildren() const { return m_hasTextChildren; }
    bool hasTextDescendants() const { return m_hasTextDescendants; }
    void setHasTextChildren() { m_hasTextChildren = true; setHasTextDescendants(); }
    void setHasTextDescendants() { m_hasTextDescendants = true; }
    
    void checkConsistency() const;
    void setHasBadChildList();

    // Line visual and layout overflow are in the coordinate space of the block.  This means that they aren't purely physical directions.
    // For horizontal-tb and vertical-lr they will match physical directions, but for horizontal-bt and vertical-rl, the top/bottom and left/right
    // respectively are flipped when compared to their physical counterparts.  For example minX is on the left in vertical-lr, but it is on the right in vertical-rl.
    LayoutRect layoutOverflowRect(LayoutUnit lineTop, LayoutUnit lineBottom) const
    { 
        return m_overflow ? m_overflow->layoutOverflowRect() : enclosingLayoutRect(frameRectIncludingLineHeight(lineTop, lineBottom));
    }
    LayoutUnit logicalLeftLayoutOverflow() const { return m_overflow ? (isHorizontal() ? m_overflow->minXLayoutOverflow() : m_overflow->minYLayoutOverflow()) : logicalLeft(); }
    LayoutUnit logicalRightLayoutOverflow() const { return m_overflow ? (isHorizontal() ? m_overflow->maxXLayoutOverflow() : m_overflow->maxYLayoutOverflow()) : ceilf(logicalRight()); }
    LayoutUnit logicalTopLayoutOverflow(LayoutUnit lineTop) const
    {
        if (m_overflow)
            return isHorizontal() ? m_overflow->minYLayoutOverflow() : m_overflow->minXLayoutOverflow();
        return lineTop;
    }
    LayoutUnit logicalBottomLayoutOverflow(LayoutUnit lineBottom) const
    {
        if (m_overflow)
            return isHorizontal() ? m_overflow->maxYLayoutOverflow() : m_overflow->maxXLayoutOverflow();
        return lineBottom;
    }
    LayoutRect logicalLayoutOverflowRect(LayoutUnit lineTop, LayoutUnit lineBottom) const
    {
        LayoutRect result = layoutOverflowRect(lineTop, lineBottom);
        if (!renderer()->isHorizontalWritingMode())
            result = result.transposedRect();
        return result;
    }

    LayoutRect visualOverflowRect(LayoutUnit lineTop, LayoutUnit lineBottom) const
    { 
        return m_overflow ? m_overflow->visualOverflowRect() : enclosingLayoutRect(frameRectIncludingLineHeight(lineTop, lineBottom));
    }
    LayoutUnit logicalLeftVisualOverflow() const { return m_overflow ? (isHorizontal() ? m_overflow->minXVisualOverflow() : m_overflow->minYVisualOverflow()) : logicalLeft(); }
    LayoutUnit logicalRightVisualOverflow() const { return m_overflow ? (isHorizontal() ? m_overflow->maxXVisualOverflow() : m_overflow->maxYVisualOverflow()) : ceilf(logicalRight()); }
    LayoutUnit logicalTopVisualOverflow(LayoutUnit lineTop) const
    {
        if (m_overflow)
            return isHorizontal() ? m_overflow->minYVisualOverflow() : m_overflow->minXVisualOverflow();
        return lineTop;
    }
    LayoutUnit logicalBottomVisualOverflow(LayoutUnit lineBottom) const
    {
        if (m_overflow)
            return isHorizontal() ? m_overflow->maxYVisualOverflow() : m_overflow->maxXVisualOverflow();
        return lineBottom;
    }
    LayoutRect logicalVisualOverflowRect(LayoutUnit lineTop, LayoutUnit lineBottom) const
    {
        LayoutRect result = visualOverflowRect(lineTop, lineBottom);
        if (!renderer()->isHorizontalWritingMode())
            result = result.transposedRect();
        return result;
    }

    void setOverflowFromLogicalRects(const LayoutRect& logicalLayoutOverflow, const LayoutRect& logicalVisualOverflow, LayoutUnit lineTop, LayoutUnit lineBottom);
    void setLayoutOverflow(const LayoutRect&, LayoutUnit lineTop, LayoutUnit lineBottom);
    void setVisualOverflow(const LayoutRect&, LayoutUnit lineTop, LayoutUnit lineBottom);

    FloatRect frameRectIncludingLineHeight(LayoutUnit lineTop, LayoutUnit lineBottom) const
    {
        if (isHorizontal())
            return FloatRect(m_topLeft.x(), lineTop, width(), lineBottom - lineTop);
        return FloatRect(lineTop, m_topLeft.y(), lineBottom - lineTop, height());
    }
    
    FloatRect logicalFrameRectIncludingLineHeight(LayoutUnit lineTop, LayoutUnit lineBottom) const
    {
        return FloatRect(logicalLeft(), lineTop, logicalWidth(), lineBottom - lineTop);
    }
    
    bool descendantsHaveSameLineHeightAndBaseline() const { return m_descendantsHaveSameLineHeightAndBaseline; }
    void clearDescendantsHaveSameLineHeightAndBaseline()
    { 
        m_descendantsHaveSameLineHeightAndBaseline = false;
        if (parent() && parent()->descendantsHaveSameLineHeightAndBaseline())
            parent()->clearDescendantsHaveSameLineHeightAndBaseline();
    }

private:
    void addBoxShadowVisualOverflow(LayoutRect& logicalVisualOverflow);
    void addBorderOutsetVisualOverflow(LayoutRect& logicalVisualOverflow);
    void addTextBoxVisualOverflow(InlineTextBox*, GlyphOverflowAndFallbackFontsMap&, LayoutRect& logicalVisualOverflow);
    void addReplacedChildOverflow(const InlineBox*, LayoutRect& logicalLayoutOverflow, LayoutRect& logicalVisualOverflow);
    void constrainToLineTopAndBottomIfNeeded(LayoutRect&) const;

protected:
    OwnPtr<RenderOverflow> m_overflow;

    virtual bool isInlineFlowBox() const { return true; }

    InlineBox* m_firstChild;
    InlineBox* m_lastChild;
    
    InlineFlowBox* m_prevLineBox; // The previous box that also uses our RenderObject
    InlineFlowBox* m_nextLineBox; // The next box that also uses our RenderObject

    bool m_includeLogicalLeftEdge : 1;
    bool m_includeLogicalRightEdge : 1;
    bool m_hasTextChildren : 1;
    bool m_hasTextDescendants : 1;
    bool m_descendantsHaveSameLineHeightAndBaseline : 1;

    // The following members are only used by RootInlineBox but moved here to keep the bits packed.

    // Whether or not this line uses alphabetic or ideographic baselines by default.
    unsigned m_baselineType : 1; // FontBaseline

    // If the line contains any ruby runs, then this will be true.
    bool m_hasAnnotationsBefore : 1;
    bool m_hasAnnotationsAfter : 1;

    unsigned m_lineBreakBidiStatusEor : 5; // WTF::Unicode::Direction
    unsigned m_lineBreakBidiStatusLastStrong : 5; // WTF::Unicode::Direction
    unsigned m_lineBreakBidiStatusLast : 5; // WTF::Unicode::Direction

    // End of RootInlineBox-specific members.

#ifndef NDEBUG
private:
    bool m_hasBadChildList;
#endif
};

inline InlineFlowBox* toInlineFlowBox(InlineBox* object)
{
    ASSERT(!object || object->isInlineFlowBox());
    return static_cast<InlineFlowBox*>(object);
}

inline const InlineFlowBox* toInlineFlowBox(const InlineBox* object)
{
    ASSERT(!object || object->isInlineFlowBox());
    return static_cast<const InlineFlowBox*>(object);
}

// This will catch anyone doing an unnecessary cast.
void toInlineFlowBox(const InlineFlowBox*);

#ifdef NDEBUG
inline void InlineFlowBox::checkConsistency() const
{
}
#endif

inline void InlineFlowBox::setHasBadChildList()
{
#ifndef NDEBUG
    m_hasBadChildList = true;
#endif
}

} // namespace WebCore

#ifndef NDEBUG
// Outside the WebCore namespace for ease of invocation from gdb.
void showTree(const WebCore::InlineFlowBox*);
#endif

#endif // InlineFlowBox_h
