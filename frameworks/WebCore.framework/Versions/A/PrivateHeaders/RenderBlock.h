/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2007 David Smith (catfish.man@gmail.com)
 * Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef RenderBlock_h
#define RenderBlock_h

#include "GapRects.h"
#include "PODIntervalTree.h"
#include "RenderBox.h"
#include "RenderLineBoxList.h"
#include "RootInlineBox.h"
#include "TextRun.h"
#include <wtf/OwnPtr.h>
#include <wtf/ListHashSet.h>

namespace WebCore {

class BidiContext;
class ColumnInfo;
class InlineIterator;
class LayoutStateMaintainer;
class LazyLineBreakIterator;
class LineLayoutState;
class LineWidth;
class RenderInline;
class RenderText;

struct BidiRun;
struct PaintInfo;
class LineInfo;
class RenderRubyRun;

template <class Iterator, class Run> class BidiResolver;
template <class Run> class BidiRunList;
template <class Iterator> struct MidpointState;
typedef BidiResolver<InlineIterator, BidiRun> InlineBidiResolver;
typedef MidpointState<InlineIterator> LineMidpointState;

enum CaretType { CursorCaret, DragCaret };

enum TextRunFlag {
    DefaultTextRunFlags = 0,
    RespectDirection = 1 << 0,
    RespectDirectionOverride = 1 << 1
};

typedef unsigned TextRunFlags;

class RenderBlock : public RenderBox {
public:
    friend class LineLayoutState;
#ifndef NDEBUG
    // Used by the PODIntervalTree for debugging the FloatingObject.
    template <class> friend struct ValueToString;
#endif

    RenderBlock(Node*);
    virtual ~RenderBlock();

    const RenderObjectChildList* children() const { return &m_children; }
    RenderObjectChildList* children() { return &m_children; }

    bool beingDestroyed() const { return m_beingDestroyed; }

    // These two functions are overridden for inline-block.
    virtual LayoutUnit lineHeight(bool firstLine, LineDirectionMode, LinePositionMode = PositionOnContainingLine) const;
    virtual LayoutUnit baselinePosition(FontBaseline, bool firstLine, LineDirectionMode, LinePositionMode = PositionOnContainingLine) const;

    RenderLineBoxList* lineBoxes() { return &m_lineBoxes; }
    const RenderLineBoxList* lineBoxes() const { return &m_lineBoxes; }

    InlineFlowBox* firstLineBox() const { return m_lineBoxes.firstLineBox(); }
    InlineFlowBox* lastLineBox() const { return m_lineBoxes.lastLineBox(); }

    void deleteLineBoxTree();

    virtual void addChild(RenderObject* newChild, RenderObject* beforeChild = 0);
    virtual void removeChild(RenderObject*);

    enum BlockLayoutPass { NormalLayoutPass, PositionedFloatLayoutPass };
    virtual void layoutBlock(bool relayoutChildren, LayoutUnit pageLogicalHeight = 0, BlockLayoutPass = NormalLayoutPass);

    void insertPositionedObject(RenderBox*);
    void removePositionedObject(RenderBox*);
    void removePositionedObjects(RenderBlock*);

    typedef ListHashSet<RenderBox*, 4> PositionedObjectsListHashSet;
    PositionedObjectsListHashSet* positionedObjects() const { return m_positionedObjects.get(); }

    void addPercentHeightDescendant(RenderBox*);
    static void removePercentHeightDescendant(RenderBox*);
    HashSet<RenderBox*>* percentHeightDescendants() const;
#if !ASSERT_DISABLED
    static bool hasPercentHeightDescendant(RenderBox*);
#endif

    RootInlineBox* createAndAppendRootInlineBox();

    bool generatesLineBoxesForInlineChild(RenderObject*);

    void markAllDescendantsWithFloatsForLayout(RenderBox* floatToRemove = 0, bool inLayout = true);
    void markSiblingsWithFloatsForLayout(RenderBox* floatToRemove = 0);
    void markPositionedObjectsForLayout();
    virtual void markForPaginationRelayoutIfNeeded();
    
    bool containsFloats() { return m_floatingObjects && !m_floatingObjects->set().isEmpty(); }
    bool containsFloat(RenderBox*);

    // Versions that can compute line offsets with the region and page offset passed in. Used for speed to avoid having to
    // compute the region all over again when you already know it.
    LayoutUnit availableLogicalWidthForLine(LayoutUnit position, bool firstLine, RenderRegion* region, LayoutUnit offsetFromLogicalTopOfFirstPage) const
    {
        return max<LayoutUnit>(0, logicalRightOffsetForLine(position, firstLine, region, offsetFromLogicalTopOfFirstPage)
            - logicalLeftOffsetForLine(position, firstLine, region, offsetFromLogicalTopOfFirstPage));
    }
    LayoutUnit logicalRightOffsetForLine(LayoutUnit position, bool firstLine, RenderRegion* region, LayoutUnit offsetFromLogicalTopOfFirstPage) const 
    {
        return logicalRightOffsetForLine(position, logicalRightOffsetForContent(region, offsetFromLogicalTopOfFirstPage), firstLine);
    }
    LayoutUnit logicalLeftOffsetForLine(LayoutUnit position, bool firstLine, RenderRegion* region, LayoutUnit offsetFromLogicalTopOfFirstPage) const 
    {
        return logicalLeftOffsetForLine(position, logicalLeftOffsetForContent(region, offsetFromLogicalTopOfFirstPage), firstLine);
    }
    LayoutUnit startOffsetForLine(LayoutUnit position, bool firstLine, RenderRegion* region, LayoutUnit offsetFromLogicalTopOfFirstPage) const
    {
        return style()->isLeftToRightDirection() ? logicalLeftOffsetForLine(position, firstLine, region, offsetFromLogicalTopOfFirstPage)
            : logicalWidth() - logicalRightOffsetForLine(position, firstLine, region, offsetFromLogicalTopOfFirstPage);
    }

    LayoutUnit availableLogicalWidthForLine(LayoutUnit position, bool firstLine) const
    {
        return availableLogicalWidthForLine(position, firstLine, regionAtBlockOffset(position), offsetFromLogicalTopOfFirstPage());
    }
    LayoutUnit logicalRightOffsetForLine(LayoutUnit position, bool firstLine) const 
    {
        return logicalRightOffsetForLine(position, logicalRightOffsetForContent(position), firstLine, 0);
    }
    LayoutUnit logicalLeftOffsetForLine(LayoutUnit position, bool firstLine) const 
    {
        return logicalLeftOffsetForLine(position, logicalLeftOffsetForContent(position), firstLine, 0);
    }
    LayoutUnit startOffsetForLine(LayoutUnit position, bool firstLine) const
    {
        return style()->isLeftToRightDirection() ? logicalLeftOffsetForLine(position, firstLine)
            : logicalWidth() - logicalRightOffsetForLine(position, firstLine);
    }
    
    LayoutUnit startAlignedOffsetForLine(RenderBox* child, LayoutUnit position, bool firstLine);
    LayoutUnit textIndentOffset() const;

    virtual VisiblePosition positionForPoint(const LayoutPoint&);
    
    // Block flows subclass availableWidth to handle multi column layout (shrinking the width available to children when laying out.)
    virtual LayoutUnit availableLogicalWidth() const;

    LayoutPoint flipForWritingModeIncludingColumns(const LayoutPoint&) const;
    void adjustStartEdgeForWritingModeIncludingColumns(LayoutRect&) const;

    RootInlineBox* firstRootBox() const { return static_cast<RootInlineBox*>(firstLineBox()); }
    RootInlineBox* lastRootBox() const { return static_cast<RootInlineBox*>(lastLineBox()); }

    bool containsNonZeroBidiLevel() const;

    GapRects selectionGapRectsForRepaint(RenderBoxModelObject* repaintContainer);
    LayoutRect logicalLeftSelectionGap(RenderBlock* rootBlock, const LayoutPoint& rootBlockPhysicalPosition, const LayoutSize& offsetFromRootBlock,
                                       RenderObject* selObj, LayoutUnit logicalLeft, LayoutUnit logicalTop, LayoutUnit logicalHeight, const PaintInfo*);
    LayoutRect logicalRightSelectionGap(RenderBlock* rootBlock, const LayoutPoint& rootBlockPhysicalPosition, const LayoutSize& offsetFromRootBlock,
                                        RenderObject* selObj, LayoutUnit logicalRight, LayoutUnit logicalTop, LayoutUnit logicalHeight, const PaintInfo*);
    void getSelectionGapInfo(SelectionState, bool& leftGap, bool& rightGap);
    LayoutRect logicalRectToPhysicalRect(const LayoutPoint& physicalPosition, const LayoutRect& logicalRect);
        
    // Helper methods for computing line counts and heights for line counts.
    RootInlineBox* lineAtIndex(int);
    int lineCount();
    int heightForLineCount(int);
    void clearTruncation();

    void adjustRectForColumns(LayoutRect&) const;
    virtual void adjustForColumns(LayoutSize&, const LayoutPoint&) const;
    void adjustForColumnRect(LayoutSize& offset, const LayoutPoint& pointInContainer) const;

    void addContinuationWithOutline(RenderInline*);
    bool paintsContinuationOutline(RenderInline*);

    virtual RenderBoxModelObject* virtualContinuation() const { return continuation(); }
    bool isAnonymousBlockContinuation() const { return continuation() && isAnonymousBlock(); }
    RenderInline* inlineElementContinuation() const;
    RenderBlock* blockElementContinuation() const;

    using RenderBoxModelObject::continuation;
    using RenderBoxModelObject::setContinuation;

    // This function is a convenience helper for creating an anonymous block that inherits its
    // style from this RenderBlock.
    RenderBlock* createAnonymousBlock(bool isFlexibleBox = false) const;
    RenderBlock* createAnonymousColumnsBlock() const;
    RenderBlock* createAnonymousColumnSpanBlock() const;
    RenderBlock* createAnonymousBlockWithSameTypeAs(RenderBlock* otherAnonymousBlock) const;
    
    static void appendRunsForObject(BidiRunList<BidiRun>&, int start, int end, RenderObject*, InlineBidiResolver&);

    static TextRun constructTextRun(RenderObject* context, const Font&, const String&, RenderStyle*,
                                    TextRun::ExpansionBehavior = TextRun::AllowTrailingExpansion | TextRun::ForbidLeadingExpansion, TextRunFlags = DefaultTextRunFlags);

    static TextRun constructTextRun(RenderObject* context, const Font&, const UChar*, int length, RenderStyle*,
                                    TextRun::ExpansionBehavior = TextRun::AllowTrailingExpansion | TextRun::ForbidLeadingExpansion, TextRunFlags = DefaultTextRunFlags);

    ColumnInfo* columnInfo() const;
    int columnGap() const;
    
    // These two functions take the ColumnInfo* to avoid repeated lookups of the info in the global HashMap.
    unsigned columnCount(ColumnInfo*) const;
    LayoutRect columnRectAt(ColumnInfo*, unsigned) const;

    LayoutUnit paginationStrut() const { return m_rareData ? m_rareData->m_paginationStrut : 0; }
    void setPaginationStrut(LayoutUnit);
    
    // The page logical offset is the object's offset from the top of the page in the page progression
    // direction (so an x-offset in vertical text and a y-offset for horizontal text).
    int pageLogicalOffset() const { return m_rareData ? m_rareData->m_pageLogicalOffset : 0; }
    void setPageLogicalOffset(int);

    RootInlineBox* lineGridBox() const { return m_rareData ? m_rareData->m_lineGridBox : 0; }
    void setLineGridBox(RootInlineBox* box)
    {
        if (!m_rareData)
            m_rareData = adoptPtr(new RenderBlockRareData(this));
        if (m_rareData->m_lineGridBox)
            m_rareData->m_lineGridBox->destroy(renderArena());
        m_rareData->m_lineGridBox = box;
    }
    void layoutLineGridBox();

    // Accessors for logical width/height and margins in the containing block's block-flow direction.
    enum ApplyLayoutDeltaMode { ApplyLayoutDelta, DoNotApplyLayoutDelta };
    LayoutUnit logicalWidthForChild(const RenderBox* child) { return isHorizontalWritingMode() ? child->width() : child->height(); }
    LayoutUnit logicalHeightForChild(const RenderBox* child) { return isHorizontalWritingMode() ? child->height() : child->width(); }
    LayoutUnit logicalTopForChild(const RenderBox* child) { return isHorizontalWritingMode() ? child->y() : child->x(); }
    LayoutUnit logicalLeftForChild(const RenderBox* child) { return isHorizontalWritingMode() ? child->x() : child->y(); }
    void setLogicalLeftForChild(RenderBox* child, LayoutUnit logicalLeft, ApplyLayoutDeltaMode = DoNotApplyLayoutDelta);
    void setLogicalTopForChild(RenderBox* child, LayoutUnit logicalTop, ApplyLayoutDeltaMode = DoNotApplyLayoutDelta);
    LayoutUnit marginBeforeForChild(const RenderBoxModelObject* child) const;
    LayoutUnit marginAfterForChild(const RenderBoxModelObject* child) const;
    LayoutUnit marginStartForChild(const RenderBoxModelObject* child) const;
    LayoutUnit marginEndForChild(const RenderBoxModelObject* child) const;
    LayoutUnit marginLogicalLeftForChild(const RenderBoxModelObject* child) const;
    LayoutUnit marginLogicalRightForChild(const RenderBoxModelObject* child) const;
    void setMarginStartForChild(RenderBox* child, LayoutUnit);
    void setMarginEndForChild(RenderBox* child, LayoutUnit);
    void setMarginBeforeForChild(RenderBox* child, LayoutUnit);
    void setMarginAfterForChild(RenderBox* child, LayoutUnit);
    LayoutUnit collapsedMarginBeforeForChild(const RenderBox* child) const;
    LayoutUnit collapsedMarginAfterForChild(const RenderBox* child) const;

    void updateLogicalWidthForAlignment(const ETextAlign&, BidiRun* trailingSpaceRun, float& logicalLeft, float& totalLogicalWidth, float& availableLogicalWidth, int expansionOpportunityCount);

    virtual void updateFirstLetter();

    class MarginValues {
    public:
        MarginValues(LayoutUnit beforePos, LayoutUnit beforeNeg, LayoutUnit afterPos, LayoutUnit afterNeg)
            : m_positiveMarginBefore(beforePos)
            , m_negativeMarginBefore(beforeNeg)
            , m_positiveMarginAfter(afterPos)
            , m_negativeMarginAfter(afterNeg)
        { }
        
        LayoutUnit positiveMarginBefore() const { return m_positiveMarginBefore; }
        LayoutUnit negativeMarginBefore() const { return m_negativeMarginBefore; }
        LayoutUnit positiveMarginAfter() const { return m_positiveMarginAfter; }
        LayoutUnit negativeMarginAfter() const { return m_negativeMarginAfter; }
        
        void setPositiveMarginBefore(LayoutUnit pos) { m_positiveMarginBefore = pos; }
        void setNegativeMarginBefore(LayoutUnit neg) { m_negativeMarginBefore = neg; }
        void setPositiveMarginAfter(LayoutUnit pos) { m_positiveMarginAfter = pos; }
        void setNegativeMarginAfter(LayoutUnit neg) { m_negativeMarginAfter = neg; }
    
    private:
        LayoutUnit m_positiveMarginBefore;
        LayoutUnit m_negativeMarginBefore;
        LayoutUnit m_positiveMarginAfter;
        LayoutUnit m_negativeMarginAfter;
    };
    MarginValues marginValuesForChild(RenderBox* child);

    virtual void scrollbarsChanged(bool /*horizontalScrollbarChanged*/, bool /*verticalScrollbarChanged*/) { };

    LayoutUnit logicalLeftOffsetForContent(RenderRegion*, LayoutUnit offsetFromLogicalTopOfFirstPage) const;
    LayoutUnit logicalRightOffsetForContent(RenderRegion*, LayoutUnit offsetFromLogicalTopOfFirstPage) const;
    LayoutUnit availableLogicalWidthForContent(RenderRegion* region, LayoutUnit offsetFromLogicalTopOfFirstPage) const
    { 
        return max<LayoutUnit>(0, logicalRightOffsetForContent(region, offsetFromLogicalTopOfFirstPage) -
            logicalLeftOffsetForContent(region, offsetFromLogicalTopOfFirstPage)); }
    LayoutUnit startOffsetForContent(RenderRegion* region, LayoutUnit offsetFromLogicalTopOfFirstPage) const
    {
        return style()->isLeftToRightDirection() ? logicalLeftOffsetForContent(region, offsetFromLogicalTopOfFirstPage)
            : logicalWidth() - logicalRightOffsetForContent(region, offsetFromLogicalTopOfFirstPage);
    }
    LayoutUnit logicalLeftOffsetForContent(LayoutUnit blockOffset) const
    {
        return logicalLeftOffsetForContent(regionAtBlockOffset(blockOffset), offsetFromLogicalTopOfFirstPage());
    }
    LayoutUnit logicalRightOffsetForContent(LayoutUnit blockOffset) const
    {
        return logicalRightOffsetForContent(regionAtBlockOffset(blockOffset), offsetFromLogicalTopOfFirstPage());
    }
    LayoutUnit availableLogicalWidthForContent(LayoutUnit blockOffset) const
    {
        return availableLogicalWidthForContent(regionAtBlockOffset(blockOffset), offsetFromLogicalTopOfFirstPage());
    }
    LayoutUnit startOffsetForContent(LayoutUnit blockOffset) const
    {
        return startOffsetForContent(regionAtBlockOffset(blockOffset), offsetFromLogicalTopOfFirstPage());
    }
    LayoutUnit logicalLeftOffsetForContent() const { return isHorizontalWritingMode() ? borderLeft() + paddingLeft() : borderTop() + paddingTop(); }
    LayoutUnit logicalRightOffsetForContent() const { return logicalLeftOffsetForContent() + availableLogicalWidth(); }
    LayoutUnit startOffsetForContent() const { return style()->isLeftToRightDirection() ? logicalLeftOffsetForContent() : logicalWidth() - logicalRightOffsetForContent(); }
    
    void setStaticInlinePositionForChild(RenderBox*, LayoutUnit blockOffset, LayoutUnit inlinePosition);

    LayoutUnit computeStartPositionDeltaForChildAvoidingFloats(const RenderBox* child, LayoutUnit childMarginStart,
        LayoutUnit childLogicalWidth, RenderRegion* = 0, LayoutUnit offsetFromLogicalTopOfFirstPage = 0);

#ifndef NDEBUG
    void showLineTreeAndMark(const InlineBox* = 0, const char* = 0, const InlineBox* = 0, const char* = 0, const RenderObject* = 0) const;
#endif

protected:
    virtual void willBeDestroyed();

    // These functions are only used internally to manipulate the render tree structure via remove/insert/appendChildNode.
    // Since they are typically called only to move objects around within anonymous blocks (which only have layers in
    // the case of column spans), the default for fullRemoveInsert is false rather than true.
    void moveChildTo(RenderBlock* to, RenderObject* child, bool fullRemoveInsert = false)
    {
        return moveChildTo(to, child, 0, fullRemoveInsert);
    }
    void moveChildTo(RenderBlock* to, RenderObject* child, RenderObject* beforeChild, bool fullRemoveInsert = false);
    void moveAllChildrenTo(RenderBlock* to, bool fullRemoveInsert = false)
    {
        return moveAllChildrenTo(to, 0, fullRemoveInsert);
    }
    void moveAllChildrenTo(RenderBlock* to, RenderObject* beforeChild, bool fullRemoveInsert = false)
    {
        return moveChildrenTo(to, firstChild(), 0, beforeChild, fullRemoveInsert);
    }
    // Move all of the kids from |startChild| up to but excluding |endChild|.  0 can be passed as the endChild to denote
    // that all the kids from |startChild| onwards should be added.
    void moveChildrenTo(RenderBlock* to, RenderObject* startChild, RenderObject* endChild, bool fullRemoveInsert = false)
    {
        return moveChildrenTo(to, startChild, endChild, 0, fullRemoveInsert);
    }
    void moveChildrenTo(RenderBlock* to, RenderObject* startChild, RenderObject* endChild, RenderObject* beforeChild, bool fullRemoveInsert = false);
    
    LayoutUnit maxPositiveMarginBefore() const { return m_rareData ? m_rareData->m_margins.positiveMarginBefore() : RenderBlockRareData::positiveMarginBeforeDefault(this); }
    LayoutUnit maxNegativeMarginBefore() const { return m_rareData ? m_rareData->m_margins.negativeMarginBefore() : RenderBlockRareData::negativeMarginBeforeDefault(this); }
    LayoutUnit maxPositiveMarginAfter() const { return m_rareData ? m_rareData->m_margins.positiveMarginAfter() : RenderBlockRareData::positiveMarginAfterDefault(this); }
    LayoutUnit maxNegativeMarginAfter() const { return m_rareData ? m_rareData->m_margins.negativeMarginAfter() : RenderBlockRareData::negativeMarginAfterDefault(this); }
    
    void setMaxMarginBeforeValues(LayoutUnit pos, LayoutUnit neg);
    void setMaxMarginAfterValues(LayoutUnit pos, LayoutUnit neg);

    void initMaxMarginValues()
    {
        if (m_rareData) {
            m_rareData->m_margins = MarginValues(RenderBlockRareData::positiveMarginBeforeDefault(this) , RenderBlockRareData::negativeMarginBeforeDefault(this),
                                                 RenderBlockRareData::positiveMarginAfterDefault(this), RenderBlockRareData::negativeMarginAfterDefault(this));
            m_rareData->m_paginationStrut = 0;
        }
    }

    virtual void layout();

    bool layoutPositionedObjects(bool relayoutChildren);

    virtual void paint(PaintInfo&, const LayoutPoint&);
    virtual void paintObject(PaintInfo&, const LayoutPoint&);
   
    LayoutUnit logicalRightOffsetForLine(LayoutUnit position, LayoutUnit fixedOffset, bool applyTextIndent, LayoutUnit* logicalHeightRemaining = 0) const;
    LayoutUnit logicalLeftOffsetForLine(LayoutUnit position, LayoutUnit fixedOffset, bool applyTextIndent, LayoutUnit* logicalHeightRemaining = 0) const;

    virtual ETextAlign textAlignmentForLine(bool endsWithSoftBreak) const;
    virtual void adjustInlineDirectionLineBounds(int /* expansionOpportunityCount */, float& /* logicalLeft */, float& /* logicalWidth */) const { }

    virtual bool nodeAtPoint(const HitTestRequest&, HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset, HitTestAction);

    virtual void computePreferredLogicalWidths();

    virtual LayoutUnit firstLineBoxBaseline() const;
    virtual LayoutUnit lastLineBoxBaseline() const;

    virtual void updateHitTestResult(HitTestResult&, const LayoutPoint&);

    // Delay update scrollbar until finishDelayRepaint() will be
    // called. This function is used when a flexbox is laying out its
    // descendant. If multiple calls are made to startDelayRepaint(),
    // finishDelayRepaint() will do nothing until finishDelayRepaint()
    // is called the same number of times.
    static void startDelayUpdateScrollInfo();
    static void finishDelayUpdateScrollInfo();

    virtual void styleWillChange(StyleDifference, const RenderStyle* newStyle);
    virtual void styleDidChange(StyleDifference, const RenderStyle* oldStyle);

    virtual bool hasLineIfEmpty() const;
    
    bool simplifiedLayout();
    void simplifiedNormalFlowLayout();

    void setDesiredColumnCountAndWidth(int, LayoutUnit);

    void computeOverflow(LayoutUnit oldClientAfterEdge, bool recomputeFloats = false);
    virtual void addOverflowFromChildren();
    void addOverflowFromFloats();
    void addOverflowFromPositionedObjects();
    void addOverflowFromBlockChildren();
    void addOverflowFromInlineChildren();
    void addVisualOverflowFromTheme();

    virtual void addFocusRingRects(Vector<LayoutRect>&, const LayoutPoint&);

#if ENABLE(SVG)
    // Only used by RenderSVGText, which explicitely overrides RenderBlock::layoutBlock(), do NOT use for anything else.
    void forceLayoutInlineChildren()
    {
        LayoutUnit repaintLogicalTop = 0;
        LayoutUnit repaintLogicalBottom = 0;
        layoutInlineChildren(true, repaintLogicalTop, repaintLogicalBottom);
    }
#endif

private:
    virtual RenderObjectChildList* virtualChildren() { return children(); }
    virtual const RenderObjectChildList* virtualChildren() const { return children(); }

    virtual const char* renderName() const;

    virtual bool isRenderBlock() const { return true; }
    virtual bool isBlockFlow() const { return (!isInline() || isReplaced()) && !isTable(); }
    virtual bool isInlineBlockOrInlineTable() const { return isInline() && isReplaced(); }

    void makeChildrenNonInline(RenderObject* insertionPoint = 0);
    virtual void removeLeftoverAnonymousBlock(RenderBlock* child);

    static void collapseAnonymousBoxChild(RenderBlock* parent, RenderObject* child);

    virtual void dirtyLinesFromChangedChild(RenderObject* child) { m_lineBoxes.dirtyLinesFromChangedChild(this, child); }

    void addChildToContinuation(RenderObject* newChild, RenderObject* beforeChild);
    void addChildIgnoringContinuation(RenderObject* newChild, RenderObject* beforeChild);
    void addChildToAnonymousColumnBlocks(RenderObject* newChild, RenderObject* beforeChild);
    virtual void addChildIgnoringAnonymousColumnBlocks(RenderObject* newChild, RenderObject* beforeChild = 0);
    
    virtual bool isSelfCollapsingBlock() const;

    virtual LayoutUnit collapsedMarginBefore() const { return maxPositiveMarginBefore() - maxNegativeMarginBefore(); }
    virtual LayoutUnit collapsedMarginAfter() const { return maxPositiveMarginAfter() - maxNegativeMarginAfter(); }

    virtual void repaintOverhangingFloats(bool paintAllDescendants);

    void layoutBlockChildren(bool relayoutChildren, LayoutUnit& maxFloatLogicalBottom);
    void layoutInlineChildren(bool relayoutChildren, LayoutUnit& repaintLogicalTop, LayoutUnit& repaintLogicalBottom);
    BidiRun* handleTrailingSpaces(BidiRunList<BidiRun>&, BidiContext*);

    virtual void borderFitAdjust(LayoutRect&) const; // Shrink the box in which the border paints if border-fit is set.

    virtual void updateBeforeAfterContent(PseudoId);
    
    virtual RootInlineBox* createRootInlineBox(); // Subclassed by SVG and Ruby.

    // Called to lay out the legend for a fieldset or the ruby text of a ruby run.
    virtual RenderObject* layoutSpecialExcludedChild(bool /*relayoutChildren*/) { return 0; }

    struct FloatWithRect {
        FloatWithRect(RenderBox* f)
            : object(f)
            , rect(LayoutRect(f->x() - f->marginLeft(), f->y() - f->marginTop(), f->width() + f->marginLeft() + f->marginRight(), f->height() + f->marginTop() + f->marginBottom()))
            , everHadLayout(f->everHadLayout())
        {
        }

        RenderBox* object;
        LayoutRect rect;
        bool everHadLayout;
    };

    struct FloatingObject {
        WTF_MAKE_NONCOPYABLE(FloatingObject); WTF_MAKE_FAST_ALLOCATED;
    public:
        // FloatLeftRight is a mask to query for both left and right but not positioned.
        // FloatAll is a mask to query for all types of floats.
        enum Type { FloatLeft = 1, FloatRight = 2, FloatLeftRight = 3, FloatPositioned = 4, FloatAll = 7 };

        FloatingObject(EFloat type)
            : m_renderer(0)
            , m_originatingLine(0)
            , m_paginationStrut(0)
            , m_shouldPaint(false)
            , m_isDescendant(false)
            , m_isPlaced(false)
#ifndef NDEBUG
            , m_isInPlacedTree(false)
#endif
        {
            ASSERT(type != NoFloat);
            if (type == LeftFloat)
                m_type = FloatLeft;
            else if (type == RightFloat)
                m_type = FloatRight;
            else if (type == PositionedFloat)
                m_type = FloatPositioned;
        }

        FloatingObject(Type type, const LayoutRect& frameRect)
            : m_renderer(0)
            , m_originatingLine(0)
            , m_frameRect(frameRect)
            , m_paginationStrut(0)
            , m_type(type)
            , m_shouldPaint(type != FloatPositioned)
            , m_isDescendant(false)
            , m_isPlaced(true)
#ifndef NDEBUG
            , m_isInPlacedTree(false)
#endif
        {
        }

        Type type() const { return static_cast<Type>(m_type); }
        RenderBox* renderer() const { return m_renderer; }
        
        bool isPlaced() const { return m_isPlaced; }
        void setIsPlaced(bool placed = true) { m_isPlaced = placed; }

        LayoutUnit x() const { ASSERT(isPlaced()); return m_frameRect.x(); }
        LayoutUnit maxX() const { ASSERT(isPlaced()); return m_frameRect.maxX(); }
        LayoutUnit y() const { ASSERT(isPlaced()); return m_frameRect.y(); }
        LayoutUnit maxY() const { ASSERT(isPlaced()); return m_frameRect.maxY(); }
        LayoutUnit width() const { return m_frameRect.width(); }
        LayoutUnit height() const { return m_frameRect.height(); }

        void setX(LayoutUnit x) { ASSERT(!isInPlacedTree()); m_frameRect.setX(x); }
        void setY(LayoutUnit y) { ASSERT(!isInPlacedTree()); m_frameRect.setY(y); }
        void setWidth(LayoutUnit width) { ASSERT(!isInPlacedTree()); m_frameRect.setWidth(width); }
        void setHeight(LayoutUnit height) { ASSERT(!isInPlacedTree()); m_frameRect.setHeight(height); }

        const LayoutRect& frameRect() const { ASSERT(isPlaced()); return m_frameRect; }
        void setFrameRect(const LayoutRect& frameRect) { ASSERT(!isInPlacedTree()); m_frameRect = frameRect; }

#ifndef NDEBUG
        bool isInPlacedTree() const { return m_isInPlacedTree; }
        void setIsInPlacedTree(bool value) { m_isInPlacedTree = value; }
#endif

        RenderBox* m_renderer;
        RootInlineBox* m_originatingLine;
        LayoutRect m_frameRect;
        int m_paginationStrut;
        unsigned m_type : 3; // Type (left/right aligned or positioned)
        bool m_shouldPaint : 1;
        bool m_isDescendant : 1;
        bool m_isPlaced : 1;
#ifndef NDEBUG
        bool m_isInPlacedTree : 1;
#endif
    };

    LayoutPoint flipFloatForWritingModeForChild(const FloatingObject*, const LayoutPoint&) const;

    LayoutUnit logicalTopForFloat(const FloatingObject* child) const { return isHorizontalWritingMode() ? child->y() : child->x(); }
    LayoutUnit logicalBottomForFloat(const FloatingObject* child) const { return isHorizontalWritingMode() ? child->maxY() : child->maxX(); }
    LayoutUnit logicalLeftForFloat(const FloatingObject* child) const { return isHorizontalWritingMode() ? child->x() : child->y(); }
    LayoutUnit logicalRightForFloat(const FloatingObject* child) const { return isHorizontalWritingMode() ? child->maxX() : child->maxY(); }
    LayoutUnit logicalWidthForFloat(const FloatingObject* child) const { return isHorizontalWritingMode() ? child->width() : child->height(); }

    void setLogicalTopForFloat(FloatingObject* child, LayoutUnit logicalTop)
    {
        if (isHorizontalWritingMode())
            child->setY(logicalTop);
        else
            child->setX(logicalTop);
    }
    void setLogicalLeftForFloat(FloatingObject* child, LayoutUnit logicalLeft)
    {
        if (isHorizontalWritingMode())
            child->setX(logicalLeft);
        else
            child->setY(logicalLeft);
    }
    void setLogicalHeightForFloat(FloatingObject* child, LayoutUnit logicalHeight)
    {
        if (isHorizontalWritingMode())
            child->setHeight(logicalHeight);
        else
            child->setWidth(logicalHeight);
    }
    void setLogicalWidthForFloat(FloatingObject* child, LayoutUnit logicalWidth)
    {
        if (isHorizontalWritingMode())
            child->setWidth(logicalWidth);
        else
            child->setHeight(logicalWidth);
    }

    LayoutUnit xPositionForFloatIncludingMargin(const FloatingObject* child) const
    {
        if (isHorizontalWritingMode())
            return child->x() + child->renderer()->marginLeft();
        else
            return child->x() + marginBeforeForChild(child->renderer());
    }
        
    LayoutUnit yPositionForFloatIncludingMargin(const FloatingObject* child) const
    {
        if (isHorizontalWritingMode())
            return child->y() + marginBeforeForChild(child->renderer());
        else
            return child->y() + child->renderer()->marginTop();
    }

    LayoutPoint computeLogicalLocationForFloat(const FloatingObject*, LayoutUnit logicalTopOffset) const;

    // The following functions' implementations are in RenderBlockLineLayout.cpp.
    typedef std::pair<RenderText*, LazyLineBreakIterator> LineBreakIteratorInfo;
    class LineBreaker {
    public:
        LineBreaker(RenderBlock* block)
            : m_block(block)
        {
            reset();
        }

        InlineIterator nextLineBreak(InlineBidiResolver&, LineInfo&, LineBreakIteratorInfo&, FloatingObject* lastFloatFromPreviousLine, unsigned consecutiveHyphenatedLines);

        bool lineWasHyphenated() { return m_hyphenated; }
        const Vector<RenderBox*>& positionedObjects() { return m_positionedObjects; }
        EClear clear() { return m_clear; }
    private:
        void reset();
        
        void skipTrailingWhitespace(InlineIterator&, const LineInfo&);
        void skipLeadingWhitespace(InlineBidiResolver&, LineInfo&, FloatingObject* lastFloatFromPreviousLine, LineWidth&);
        
        RenderBlock* m_block;
        bool m_hyphenated;
        EClear m_clear;
        Vector<RenderBox*> m_positionedObjects;
    };

    void checkFloatsInCleanLine(RootInlineBox*, Vector<FloatWithRect>&, size_t& floatIndex, bool& encounteredNewFloat, bool& dirtiedByFloat);
    RootInlineBox* determineStartPosition(LineLayoutState&, InlineBidiResolver&);
    void determineEndPosition(LineLayoutState&, RootInlineBox* startBox, InlineIterator& cleanLineStart, BidiStatus& cleanLineBidiStatus);
    bool matchedEndLine(LineLayoutState&, const InlineBidiResolver&, const InlineIterator& endLineStart, const BidiStatus& endLineStatus);
    bool checkPaginationAndFloatsAtEndLine(LineLayoutState&);
    
    RootInlineBox* constructLine(BidiRunList<BidiRun>&, const LineInfo&);
    InlineFlowBox* createLineBoxes(RenderObject*, const LineInfo&, InlineBox* childBox);

    void setMarginsForRubyRun(BidiRun*, RenderRubyRun*, RenderObject*, const LineInfo&);

    void computeInlineDirectionPositionsForLine(RootInlineBox*, const LineInfo&, BidiRun* firstRun, BidiRun* trailingSpaceRun, bool reachedEnd, GlyphOverflowAndFallbackFontsMap&, VerticalPositionCache&);
    void computeBlockDirectionPositionsForLine(RootInlineBox*, BidiRun*, GlyphOverflowAndFallbackFontsMap&, VerticalPositionCache&);
    void deleteEllipsisLineBoxes();
    void checkLinesForTextOverflow();

    // Positions new floats and also adjust all floats encountered on the line if any of them
    // have to move to the next page/column.
    bool positionNewFloatOnLine(FloatingObject* newFloat, FloatingObject* lastFloatFromPreviousLine, LineInfo&, LineWidth&);
    void appendFloatingObjectToLastLine(FloatingObject*);

    // End of functions defined in RenderBlockLineLayout.cpp.

    void paintFloats(PaintInfo&, const LayoutPoint&, bool preservePhase = false);
    void paintContents(PaintInfo&, const LayoutPoint&);
    void paintColumnContents(PaintInfo&, const LayoutPoint&, bool paintFloats = false);
    void paintColumnRules(PaintInfo&, const LayoutPoint&);
    void paintChildren(PaintInfo&, const LayoutPoint&);
    void paintEllipsisBoxes(PaintInfo&, const LayoutPoint&);
    void paintSelection(PaintInfo&, const LayoutPoint&);
    void paintCaret(PaintInfo&, const LayoutPoint&, CaretType);

    FloatingObject* insertFloatingObject(RenderBox*);
    void removeFloatingObject(RenderBox*);
    void removeFloatingObjectsBelow(FloatingObject*, int logicalOffset);
    
    // Called from lineWidth, to position the floats added in the last line.
    // Returns true if and only if it has positioned any floats.
    bool positionNewFloats();

    bool hasPositionedFloats() const { return m_hasPositionedFloats; }
    void addPositionedFloats();
    bool positionedFloatsNeedRelayout();

    void clearFloats(BlockLayoutPass);
    LayoutUnit getClearDelta(RenderBox* child, LayoutUnit yPos);

    virtual bool avoidsFloats() const;

    bool hasOverhangingFloats() { return parent() && !hasColumns() && containsFloats() && lowestFloatLogicalBottomIncludingPositionedFloats() > logicalHeight(); }
    bool hasOverhangingFloat(RenderBox*);
    void addIntrudingFloats(RenderBlock* prev, LayoutUnit xoffset, LayoutUnit yoffset);
    LayoutUnit addOverhangingFloats(RenderBlock* child, bool makeChildPaintOtherFloats);

    LayoutUnit lowestFloatLogicalBottom() const { return lowestFloatLogicalBottom(FloatingObject::FloatLeftRight); }
    LayoutUnit lowestFloatLogicalBottomIncludingPositionedFloats() const { return lowestFloatLogicalBottom(FloatingObject::FloatAll); }
    LayoutUnit lowestFloatLogicalBottom(FloatingObject::Type) const;
    LayoutUnit nextFloatLogicalBottomBelow(LayoutUnit) const;
    
    virtual bool hitTestColumns(const HitTestRequest&, HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset, HitTestAction);
    virtual bool hitTestContents(const HitTestRequest&, HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset, HitTestAction);
    bool hitTestFloats(const HitTestRequest&, HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset);

    virtual bool isPointInOverflowControl(HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset);

    void computeInlinePreferredLogicalWidths();
    void computeBlockPreferredLogicalWidths();

    // Obtains the nearest enclosing block (including this block) that contributes a first-line style to our inline
    // children.
    virtual RenderBlock* firstLineBlock() const;

    virtual LayoutRect rectWithOutlineForRepaint(RenderBoxModelObject* repaintContainer, LayoutUnit outlineWidth) const;
    virtual RenderStyle* outlineStyleForRepaint() const;
    
    virtual RenderObject* hoverAncestor() const;
    virtual void updateDragState(bool dragOn);
    virtual void childBecameNonInline(RenderObject* child);

    virtual LayoutRect selectionRectForRepaint(RenderBoxModelObject* repaintContainer, bool /*clipToVisibleContent*/)
    {
        return selectionGapRectsForRepaint(repaintContainer);
    }
    virtual bool shouldPaintSelectionGaps() const;
    bool isSelectionRoot() const;
    GapRects selectionGaps(RenderBlock* rootBlock, const LayoutPoint& rootBlockPhysicalPosition, const LayoutSize& offsetFromRootBlock,
                           LayoutUnit& lastLogicalTop, LayoutUnit& lastLogicalLeft, LayoutUnit& lastLogicalRight, const PaintInfo* = 0);
    GapRects inlineSelectionGaps(RenderBlock* rootBlock, const LayoutPoint& rootBlockPhysicalPosition, const LayoutSize& offsetFromRootBlock,
                                 LayoutUnit& lastLogicalTop, LayoutUnit& lastLogicalLeft, LayoutUnit& lastLogicalRight, const PaintInfo*);
    GapRects blockSelectionGaps(RenderBlock* rootBlock, const LayoutPoint& rootBlockPhysicalPosition, const LayoutSize& offsetFromRootBlock,
                                LayoutUnit& lastLogicalTop, LayoutUnit& lastLogicalLeft, LayoutUnit& lastLogicalRight, const PaintInfo*);
    LayoutRect blockSelectionGap(RenderBlock* rootBlock, const LayoutPoint& rootBlockPhysicalPosition, const LayoutSize& offsetFromRootBlock,
                                 LayoutUnit lastLogicalTop, LayoutUnit lastLogicalLeft, LayoutUnit lastLogicalRight, LayoutUnit logicalBottom, const PaintInfo*);
    LayoutUnit logicalLeftSelectionOffset(RenderBlock* rootBlock, LayoutUnit position);
    LayoutUnit logicalRightSelectionOffset(RenderBlock* rootBlock, LayoutUnit position);
    
    virtual void absoluteRects(Vector<LayoutRect>&, const LayoutPoint& accumulatedOffset) const;
    virtual void absoluteQuads(Vector<FloatQuad>&, bool* wasFixed) const;

    LayoutUnit desiredColumnWidth() const;
    unsigned desiredColumnCount() const;

    void paintContinuationOutlines(PaintInfo&, const LayoutPoint&);

    virtual LayoutRect localCaretRect(InlineBox*, int caretOffset, LayoutUnit* extraWidthToEndOfLine = 0);

    void adjustPointToColumnContents(LayoutPoint&) const;
    void adjustForBorderFit(LayoutUnit x, LayoutUnit& left, LayoutUnit& right) const; // Helper function for borderFitAdjust

    void markLinesDirtyInBlockRange(LayoutUnit logicalTop, LayoutUnit logicalBottom, RootInlineBox* highest = 0);

    void newLine(EClear);

    Position positionForBox(InlineBox*, bool start = true) const;
    VisiblePosition positionForPointWithInlineChildren(const LayoutPoint&);

    // Adjust from painting offsets to the local coords of this renderer
    void offsetForContents(LayoutPoint&) const;

    virtual void calcColumnWidth();
    bool layoutColumns(bool hasSpecifiedPageLogicalHeight, LayoutUnit pageLogicalHeight, LayoutStateMaintainer&);
    void makeChildrenAnonymousColumnBlocks(RenderObject* beforeChild, RenderBlock* newBlockBox, RenderObject* newChild);

    bool expandsToEncloseOverhangingFloats() const;

    void updateScrollInfoAfterLayout();

    RenderObject* splitAnonymousBlocksAroundChild(RenderObject* beforeChild);
    void splitBlocks(RenderBlock* fromBlock, RenderBlock* toBlock, RenderBlock* middleBlock,
                     RenderObject* beforeChild, RenderBoxModelObject* oldCont);
    void splitFlow(RenderObject* beforeChild, RenderBlock* newBlockBox,
                   RenderObject* newChild, RenderBoxModelObject* oldCont);
    RenderBlock* clone() const;
    RenderBlock* continuationBefore(RenderObject* beforeChild);
    RenderBlock* containingColumnsBlock(bool allowAnonymousColumnBlock = true);
    RenderBlock* columnsBlockForSpanningElement(RenderObject* newChild);

    class MarginInfo {
        // Collapsing flags for whether we can collapse our margins with our children's margins.
        bool m_canCollapseWithChildren : 1;
        bool m_canCollapseMarginBeforeWithChildren : 1;
        bool m_canCollapseMarginAfterWithChildren : 1;

        // Whether or not we are a quirky container, i.e., do we collapse away top and bottom
        // margins in our container.  Table cells and the body are the common examples. We
        // also have a custom style property for Safari RSS to deal with TypePad blog articles.
        bool m_quirkContainer : 1;

        // This flag tracks whether we are still looking at child margins that can all collapse together at the beginning of a block.  
        // They may or may not collapse with the top margin of the block (|m_canCollapseTopWithChildren| tells us that), but they will
        // always be collapsing with one another.  This variable can remain set to true through multiple iterations 
        // as long as we keep encountering self-collapsing blocks.
        bool m_atBeforeSideOfBlock : 1;

        // This flag is set when we know we're examining bottom margins and we know we're at the bottom of the block.
        bool m_atAfterSideOfBlock : 1;

        // These variables are used to detect quirky margins that we need to collapse away (in table cells
        // and in the body element).
        bool m_marginBeforeQuirk : 1;
        bool m_marginAfterQuirk : 1;
        bool m_determinedMarginBeforeQuirk : 1;

        // These flags track the previous maximal positive and negative margins.
        LayoutUnit m_positiveMargin;
        LayoutUnit m_negativeMargin;

    public:
        MarginInfo(RenderBlock*, LayoutUnit beforeBorderPadding, LayoutUnit afterBorderPadding);

        void setAtBeforeSideOfBlock(bool b) { m_atBeforeSideOfBlock = b; }
        void setAtAfterSideOfBlock(bool b) { m_atAfterSideOfBlock = b; }
        void clearMargin() { m_positiveMargin = m_negativeMargin = 0; }
        void setMarginBeforeQuirk(bool b) { m_marginBeforeQuirk = b; }
        void setMarginAfterQuirk(bool b) { m_marginAfterQuirk = b; }
        void setDeterminedMarginBeforeQuirk(bool b) { m_determinedMarginBeforeQuirk = b; }
        void setPositiveMargin(LayoutUnit p) { m_positiveMargin = p; }
        void setNegativeMargin(LayoutUnit n) { m_negativeMargin = n; }
        void setPositiveMarginIfLarger(LayoutUnit p)
        {
            if (p > m_positiveMargin)
                m_positiveMargin = p;
        }
        void setNegativeMarginIfLarger(LayoutUnit n)
        {
            if (n > m_negativeMargin)
                m_negativeMargin = n;
        }

        void setMargin(LayoutUnit p, LayoutUnit n) { m_positiveMargin = p; m_negativeMargin = n; }

        bool atBeforeSideOfBlock() const { return m_atBeforeSideOfBlock; }
        bool canCollapseWithMarginBefore() const { return m_atBeforeSideOfBlock && m_canCollapseMarginBeforeWithChildren; }
        bool canCollapseWithMarginAfter() const { return m_atAfterSideOfBlock && m_canCollapseMarginAfterWithChildren; }
        bool canCollapseMarginBeforeWithChildren() const { return m_canCollapseMarginBeforeWithChildren; }
        bool canCollapseMarginAfterWithChildren() const { return m_canCollapseMarginAfterWithChildren; }
        bool quirkContainer() const { return m_quirkContainer; }
        bool determinedMarginBeforeQuirk() const { return m_determinedMarginBeforeQuirk; }
        bool marginBeforeQuirk() const { return m_marginBeforeQuirk; }
        bool marginAfterQuirk() const { return m_marginAfterQuirk; }
        LayoutUnit positiveMargin() const { return m_positiveMargin; }
        LayoutUnit negativeMargin() const { return m_negativeMargin; }
        LayoutUnit margin() const { return m_positiveMargin - m_negativeMargin; }
    };

    void layoutBlockChild(RenderBox* child, MarginInfo&, LayoutUnit& previousFloatLogicalBottom, LayoutUnit& maxFloatLogicalBottom);
    void adjustPositionedBlock(RenderBox* child, const MarginInfo&);
    void adjustFloatingBlock(const MarginInfo&);
    bool handleSpecialChild(RenderBox* child, const MarginInfo&);
    bool handleFloatingChild(RenderBox* child, const MarginInfo&);
    bool handlePositionedChild(RenderBox* child, const MarginInfo&);
    bool handleRunInChild(RenderBox* child);
    LayoutUnit collapseMargins(RenderBox* child, MarginInfo&);
    LayoutUnit clearFloatsIfNeeded(RenderBox* child, MarginInfo&, LayoutUnit oldTopPosMargin, LayoutUnit oldTopNegMargin, LayoutUnit yPos);
    LayoutUnit estimateLogicalTopPosition(RenderBox* child, const MarginInfo&, LayoutUnit& estimateWithoutPagination);
    void determineLogicalLeftPositionForChild(RenderBox* child);
    void handleAfterSideOfBlock(LayoutUnit top, LayoutUnit bottom, MarginInfo&);
    void setCollapsedBottomMargin(const MarginInfo&);
    // End helper functions and structs used by layoutBlockChildren.

    // Helper function for layoutInlineChildren()
    RootInlineBox* createLineBoxesFromBidiRuns(BidiRunList<BidiRun>&, const InlineIterator& end, LineInfo&, VerticalPositionCache&, BidiRun* trailingSpaceRun);
    void layoutRunsAndFloats(LineLayoutState&, bool hasInlineChild);
    void layoutRunsAndFloatsInRange(LineLayoutState&, InlineBidiResolver&, const InlineIterator& cleanLineStart, const BidiStatus& cleanLineBidiStatus, unsigned consecutiveHyphenatedLines);
    void linkToEndLineIfNeeded(LineLayoutState&);
    static void repaintDirtyFloats(Vector<FloatWithRect>& floats);

protected:
    // Pagination routines.
    
    // Returns the logicalOffset at the top of the next page. If the offset passed in is already at the top of the current page,
    // then nextPageLogicalTop with ExcludePageBoundary will still move to the top of the next page. nextPageLogicalTop with
    // IncludePageBoundary set will not.
    //
    // For a page height of 800px, the first rule will return 800 if the value passed in is 0. The second rule will simply return 0.
    enum PageBoundaryRule { ExcludePageBoundary, IncludePageBoundary };
    LayoutUnit nextPageLogicalTop(LayoutUnit logicalOffset, PageBoundaryRule = ExcludePageBoundary) const;
    bool hasNextPage(LayoutUnit logicalOffset, PageBoundaryRule = ExcludePageBoundary) const;

    LayoutUnit applyBeforeBreak(RenderBox* child, LayoutUnit logicalOffset); // If the child has a before break, then return a new yPos that shifts to the top of the next page/column.
    LayoutUnit applyAfterBreak(RenderBox* child, LayoutUnit logicalOffset, MarginInfo&); // If the child has an after break, then return a new offset that shifts to the top of the next page/column.

public:
    LayoutUnit pageLogicalTopForOffset(LayoutUnit offset) const;
    LayoutUnit pageLogicalHeightForOffset(LayoutUnit offset) const;
    LayoutUnit pageRemainingLogicalHeightForOffset(LayoutUnit offset, PageBoundaryRule = IncludePageBoundary) const;
    
protected:
    bool pushToNextPageWithMinimumLogicalHeight(LayoutUnit& adjustment, LayoutUnit logicalOffset, LayoutUnit minimumLogicalHeight) const;

    LayoutUnit adjustForUnsplittableChild(RenderBox* child, LayoutUnit logicalOffset, bool includeMargins = false); // If the child is unsplittable and can't fit on the current page, return the top of the next page/column.
    void adjustLinePositionForPagination(RootInlineBox*, LayoutUnit& deltaOffset); // Computes a deltaOffset value that put a line at the top of the next page if it doesn't fit on the current page.
    LayoutUnit adjustBlockChildForPagination(LayoutUnit logicalTopAfterClear, LayoutUnit estimateWithoutPagination, RenderBox* child, bool atBeforeSideOfBlock);

    // This function is called to test a line box that has moved in the block direction to see if it has ended up in a new
    // region/page/column that has a different available line width than the old one. Used to know when you have to dirty a
    // line, i.e., that it can't be re-used.
    bool lineWidthForPaginatedLineChanged(RootInlineBox*, LayoutUnit lineDelta = 0) const;

    bool logicalWidthChangedInRegions() const;

    virtual bool requiresColumns(int desiredColumnCount) const;

public:
    LayoutUnit offsetFromLogicalTopOfFirstPage() const;
    RenderRegion* regionAtBlockOffset(LayoutUnit) const;
    RenderRegion* clampToStartAndEndRegions(RenderRegion*) const;

protected:
    struct FloatingObjectHashFunctions {
        static unsigned hash(FloatingObject* key) { return DefaultHash<RenderBox*>::Hash::hash(key->m_renderer); }
        static bool equal(FloatingObject* a, FloatingObject* b) { return a->m_renderer == b->m_renderer; }
        static const bool safeToCompareToEmptyOrDeleted = true;
    };
    struct FloatingObjectHashTranslator {
        static unsigned hash(RenderBox* key) { return DefaultHash<RenderBox*>::Hash::hash(key); }
        static bool equal(FloatingObject* a, RenderBox* b) { return a->m_renderer == b; }
    };
    typedef ListHashSet<FloatingObject*, 4, FloatingObjectHashFunctions> FloatingObjectSet;
    typedef FloatingObjectSet::const_iterator FloatingObjectSetIterator;
    typedef PODInterval<int, FloatingObject*> FloatingObjectInterval;
    typedef PODIntervalTree<int, FloatingObject*> FloatingObjectTree;
    typedef PODFreeListArena<PODRedBlackTree<FloatingObjectInterval>::Node> IntervalArena;
    
    template <FloatingObject::Type FloatTypeValue>
    class FloatIntervalSearchAdapter {
    public:
        typedef FloatingObjectInterval IntervalType;
        
        FloatIntervalSearchAdapter(const RenderBlock* renderer, int value, LayoutUnit& offset, LayoutUnit* heightRemaining)
            : m_renderer(renderer)
            , m_value(value)
            , m_offset(offset)
            , m_heightRemaining(heightRemaining)
        {
        }
        
        inline int lowValue() const { return m_value; }
        inline int highValue() const { return m_value; }
        void collectIfNeeded(const IntervalType&) const;

    private:
        const RenderBlock* m_renderer;
        int m_value;
        LayoutUnit& m_offset;
        LayoutUnit* m_heightRemaining;
    };

    class FloatingObjects {
    public:
        FloatingObjects(const RenderBlock* renderer, bool horizontalWritingMode)
            : m_placedFloatsTree(UninitializedTree)
            , m_leftObjectsCount(0)
            , m_rightObjectsCount(0)
            , m_positionedObjectsCount(0)
            , m_horizontalWritingMode(horizontalWritingMode)
            , m_renderer(renderer)
        {
        }

        void clear();
        void add(FloatingObject*);
        void remove(FloatingObject*);
        void addPlacedObject(FloatingObject*);
        void removePlacedObject(FloatingObject*);
        void setHorizontalWritingMode(bool b = true) { m_horizontalWritingMode = b; }

        bool hasLeftObjects() const { return m_leftObjectsCount > 0; }
        bool hasRightObjects() const { return m_rightObjectsCount > 0; }
        bool hasPositionedObjects() const { return m_positionedObjectsCount > 0; }
        const FloatingObjectSet& set() const { return m_set; }
        const FloatingObjectTree& placedFloatsTree()
        {
            computePlacedFloatsTreeIfNeeded();
            return m_placedFloatsTree; 
        }
    private:
        void computePlacedFloatsTree();
        inline void computePlacedFloatsTreeIfNeeded()
        {
            if (!m_placedFloatsTree.isInitialized())
                computePlacedFloatsTree();
        }
        void increaseObjectsCount(FloatingObject::Type);
        void decreaseObjectsCount(FloatingObject::Type);
        FloatingObjectInterval intervalForFloatingObject(FloatingObject*);

        FloatingObjectSet m_set;
        FloatingObjectTree m_placedFloatsTree;
        unsigned m_leftObjectsCount;
        unsigned m_rightObjectsCount;
        unsigned m_positionedObjectsCount;
        bool m_horizontalWritingMode;
        const RenderBlock* m_renderer;
    };
    OwnPtr<FloatingObjects> m_floatingObjects;
    
    typedef PositionedObjectsListHashSet::const_iterator Iterator;
    OwnPtr<PositionedObjectsListHashSet> m_positionedObjects;

    // Allocated only when some of these fields have non-default values
    struct RenderBlockRareData {
        WTF_MAKE_NONCOPYABLE(RenderBlockRareData); WTF_MAKE_FAST_ALLOCATED;
    public:
        RenderBlockRareData(const RenderBlock* block) 
            : m_margins(positiveMarginBeforeDefault(block), negativeMarginBeforeDefault(block), positiveMarginAfterDefault(block), negativeMarginAfterDefault(block))
            , m_paginationStrut(0)
            , m_pageLogicalOffset(0)
            , m_lineGridBox(0)
        { 
        }

        static LayoutUnit positiveMarginBeforeDefault(const RenderBlock* block)
        { 
            return std::max<LayoutUnit>(block->marginBefore(), 0);
        }
        
        static LayoutUnit negativeMarginBeforeDefault(const RenderBlock* block)
        { 
            return std::max<LayoutUnit>(-block->marginBefore(), 0);
        }
        static LayoutUnit positiveMarginAfterDefault(const RenderBlock* block)
        {
            return std::max<LayoutUnit>(block->marginAfter(), 0);
        }
        static LayoutUnit negativeMarginAfterDefault(const RenderBlock* block)
        {
            return std::max<LayoutUnit>(-block->marginAfter(), 0);
        }
        
        MarginValues m_margins;
        LayoutUnit m_paginationStrut;
        LayoutUnit m_pageLogicalOffset;
        
        RootInlineBox* m_lineGridBox;
     };

    OwnPtr<RenderBlockRareData> m_rareData;

    RenderObjectChildList m_children;
    RenderLineBoxList m_lineBoxes;   // All of the root line boxes created for this block flow.  For example, <div>Hello<br>world.</div> will have two total lines for the <div>.

    mutable signed m_lineHeight : 30;
    bool m_beingDestroyed : 1;
    bool m_hasPositionedFloats : 1;

    // RenderRubyBase objects need to be able to split and merge, moving their children around
    // (calling moveChildTo, moveAllChildrenTo, and makeChildrenNonInline).
    friend class RenderRubyBase;
    friend class LineWidth; // Needs to know FloatingObject

private:
    // Used to store state between styleWillChange and styleDidChange
    static bool s_canPropagateFloatIntoSibling;
};

inline RenderBlock* toRenderBlock(RenderObject* object)
{ 
    ASSERT(!object || object->isRenderBlock());
    return static_cast<RenderBlock*>(object);
}

inline const RenderBlock* toRenderBlock(const RenderObject* object)
{ 
    ASSERT(!object || object->isRenderBlock());
    return static_cast<const RenderBlock*>(object);
}

// This will catch anyone doing an unnecessary cast.
void toRenderBlock(const RenderBlock*);

#ifndef NDEBUG
// These structures are used by PODIntervalTree for debugging purposes.
template <> struct ValueToString<int> {
    static String string(const int value);
};
template<> struct ValueToString<RenderBlock::FloatingObject*> {
    static String string(const RenderBlock::FloatingObject*);
};
#endif

} // namespace WebCore

#endif // RenderBlock_h
