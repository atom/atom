/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
 *           (C) 2000 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2005, 2006, 2007, 2008, 2009, 2010, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Graham Dennis (graham.dennis@gmail.com)
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

#ifndef RenderStyle_h
#define RenderStyle_h

#include "AnimationList.h"
#include "BorderValue.h"
#include "CSSLineBoxContainValue.h"
#include "CSSPrimitiveValue.h"
#include "CSSPropertyNames.h"
#include "Color.h"
#include "ColorSpace.h"
#include "CounterDirectives.h"
#include "DataRef.h"
#include "FillLayer.h"
#include "Font.h"
#include "GraphicsTypes.h"
#include "Length.h"
#include "LengthBox.h"
#include "LengthSize.h"
#include "LineClampValue.h"
#include "NinePieceImage.h"
#include "OutlineValue.h"
#include "RenderStyleConstants.h"
#include "RoundedRect.h"
#include "ShadowData.h"
#include "StyleBackgroundData.h"
#include "StyleBoxData.h"
#include "StyleDeprecatedFlexibleBoxData.h"
#include "StyleFlexibleBoxData.h"
#include "StyleInheritedData.h"
#include "StyleMarqueeData.h"
#include "StyleMultiColData.h"
#include "StyleRareInheritedData.h"
#include "StyleRareNonInheritedData.h"
#include "StyleReflection.h"
#include "StyleSurroundData.h"
#include "StyleTransformData.h"
#include "StyleVisualData.h"
#include "TextDirection.h"
#include "TextOrientation.h"
#include "ThemeTypes.h"
#include "TransformOperations.h"
#include "UnicodeBidi.h"
#include <wtf/Forward.h>
#include <wtf/OwnPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/StdLibExtras.h>
#include <wtf/Vector.h>

#if ENABLE(CSS_FILTERS)
#include "FilterOperations.h"
#include "StyleFilterData.h"
#endif

#if ENABLE(CSS_GRID_LAYOUT)
#include "StyleGridData.h"
#endif

#if ENABLE(DASHBOARD_SUPPORT)
#include "StyleDashboardRegion.h"
#endif

#if ENABLE(SVG)
#include "SVGPaint.h"
#include "SVGRenderStyle.h"
#endif

template<typename T, typename U> inline bool compareEqual(const T& t, const U& u) { return t == static_cast<T>(u); }

#define SET_VAR(group, variable, value) \
    if (!compareEqual(group->variable, value)) \
        group.access()->variable = value;

namespace WebCore {

using std::max;

class BorderData;
class CSSStyleSelector;
class CounterContent;
class CursorList;
class IntRect;
class Pair;
class ShadowData;
class StyleImage;
class TransformationMatrix;

class ContentData;

typedef Vector<RefPtr<RenderStyle>, 4> PseudoStyleCache;

class RenderStyle: public RefCounted<RenderStyle> {
    friend class AnimationBase; // Used by CSS animations. We can't allow them to animate based off visited colors.
    friend class ApplyStyleCommand; // Editing has to only reveal unvisited info.
    friend class EditingStyle; // Editing has to only reveal unvisited info.
    friend class CSSStyleApplyProperty; // Sets members directly.
    friend class CSSStyleSelector; // Sets members directly.
    friend class CSSComputedStyleDeclaration; // Ignores visited styles, so needs to be able to see unvisited info.
    friend class PropertyWrapperMaybeInvalidColor; // Used by CSS animations. We can't allow them to animate based off visited colors.
    friend class RenderSVGResource; // FIXME: Needs to alter the visited state by hand. Should clean the SVG code up and move it into RenderStyle perhaps.
    friend class RenderTreeAsText; // FIXME: Only needed so the render tree can keep lying and dump the wrong colors.  Rebaselining would allow this to be yanked.
protected:

    class RenderStyleBitfields {
    public:
        RenderStyleBitfields()
            : m_affectedByUncommonAttributeSelectors(false)
            , m_unique(false)
            , m_affectedByEmpty(false)
            , m_emptyState(false)
            , m_childrenAffectedByFirstChildRules(false)
            , m_childrenAffectedByLastChildRules(false)
            , m_childrenAffectedByDirectAdjacentRules(false)
            , m_childrenAffectedByForwardPositionalRules(false)
            , m_childrenAffectedByBackwardPositionalRules(false)
            , m_firstChildState(false)
            , m_lastChildState(false)
            , m_explicitInheritance(false)
            , m_childIndex(0)
        {
        }

        bool affectedByUncommonAttributeSelectors() const { return m_affectedByUncommonAttributeSelectors; }
        void setAffectedByUncommonAttributeSelectors(bool value) { m_affectedByUncommonAttributeSelectors = value; }
        bool unique() const { return m_unique; }
        void setUnique(bool value) { m_unique = value; }
        bool affectedByEmpty() const { return m_affectedByEmpty; }
        void setAffectedByEmpty(bool value) { m_affectedByEmpty = value; }
        bool emptyState() const { return m_emptyState; }
        void setEmptyState(bool value) { m_emptyState = value; }
        bool childrenAffectedByFirstChildRules() const { return m_childrenAffectedByFirstChildRules; }
        void setChildrenAffectedByFirstChildRules(bool value) { m_childrenAffectedByFirstChildRules = value; }
        bool childrenAffectedByLastChildRules() const { return m_childrenAffectedByLastChildRules; }
        void setChildrenAffectedByLastChildRules(bool value) { m_childrenAffectedByLastChildRules = value; }
        bool childrenAffectedByDirectAdjacentRules() const { return m_childrenAffectedByDirectAdjacentRules; }
        void setChildrenAffectedByDirectAdjacentRules(bool value) { m_childrenAffectedByDirectAdjacentRules = value; }
        bool childrenAffectedByForwardPositionalRules() const { return m_childrenAffectedByForwardPositionalRules; }
        void setChildrenAffectedByForwardPositionalRules(bool value) { m_childrenAffectedByForwardPositionalRules = value; }
        bool childrenAffectedByBackwardPositionalRules() const { return m_childrenAffectedByBackwardPositionalRules; }
        void setChildrenAffectedByBackwardPositionalRules(bool value) { m_childrenAffectedByBackwardPositionalRules = value; }
        bool firstChildState() const { return m_firstChildState; }
        void setFirstChildState(bool value) { m_firstChildState = value; }
        bool lastChildState() const { return m_lastChildState; }
        void setLastChildState(bool value) { m_lastChildState = value; }
        bool explicitInheritance() const { return m_explicitInheritance; }
        void setExplicitInheritance(bool value) { m_explicitInheritance = value; }

        unsigned childIndex() const { return m_childIndex; }
        void setChildIndex(unsigned index) { m_childIndex = index; }

    private:
        // The following bitfield is 32-bits long, which optimizes padding with the
        // int refCount in the base class. Beware when adding more bits.
        unsigned m_affectedByUncommonAttributeSelectors : 1;
        unsigned m_unique : 1;

        // Bits for dynamic child matching.
        unsigned m_affectedByEmpty : 1;
        unsigned m_emptyState : 1;

        // We optimize for :first-child and :last-child. The other positional child selectors like nth-child or
        // *-child-of-type, we will just give up and re-evaluate whenever children change at all.
        unsigned m_childrenAffectedByFirstChildRules : 1;
        unsigned m_childrenAffectedByLastChildRules : 1;
        unsigned m_childrenAffectedByDirectAdjacentRules : 1;
        unsigned m_childrenAffectedByForwardPositionalRules : 1;
        unsigned m_childrenAffectedByBackwardPositionalRules : 1;
        unsigned m_firstChildState : 1;
        unsigned m_lastChildState : 1;
        unsigned m_explicitInheritance : 1;
        unsigned m_childIndex : 20; // Plenty of bits to cache an index.
    };
    RenderStyleBitfields m_bitfields;

    // non-inherited attributes
    DataRef<StyleBoxData> m_box;
    DataRef<StyleVisualData> visual;
    DataRef<StyleBackgroundData> m_background;
    DataRef<StyleSurroundData> surround;
    DataRef<StyleRareNonInheritedData> rareNonInheritedData;

    // inherited attributes
    DataRef<StyleRareInheritedData> rareInheritedData;
    DataRef<StyleInheritedData> inherited;

    // list of associated pseudo styles
    OwnPtr<PseudoStyleCache> m_cachedPseudoStyles;

#if ENABLE(SVG)
    DataRef<SVGRenderStyle> m_svgStyle;
#endif

// !START SYNC!: Keep this in sync with the copy constructor in RenderStyle.cpp and implicitlyInherited() in CSSStyleSelector.cpp

    // inherit
    struct InheritedFlags {
        bool operator==(const InheritedFlags& other) const
        {
            return (_empty_cells == other._empty_cells)
                && (_caption_side == other._caption_side)
                && (_list_style_type == other._list_style_type)
                && (_list_style_position == other._list_style_position)
                && (_visibility == other._visibility)
                && (_text_align == other._text_align)
                && (_text_transform == other._text_transform)
                && (_text_decorations == other._text_decorations)
                && (_cursor_style == other._cursor_style)
                && (_direction == other._direction)
                && (_white_space == other._white_space)
                && (_border_collapse == other._border_collapse)
                && (_box_direction == other._box_direction)
                && (m_rtlOrdering == other.m_rtlOrdering)
                && (m_printColorAdjust == other.m_printColorAdjust)
                && (_pointerEvents == other._pointerEvents)
                && (_insideLink == other._insideLink)
                && (m_writingMode == other.m_writingMode);
        }

        bool operator!=(const InheritedFlags& other) const { return !(*this == other); }

        unsigned _empty_cells : 1; // EEmptyCell
        unsigned _caption_side : 2; // ECaptionSide
        unsigned _list_style_type : 7; // EListStyleType
        unsigned _list_style_position : 1; // EListStylePosition
        unsigned _visibility : 2; // EVisibility
        unsigned _text_align : 4; // ETextAlign
        unsigned _text_transform : 2; // ETextTransform
        unsigned _text_decorations : ETextDecorationBits;
        unsigned _cursor_style : 6; // ECursor
        unsigned _direction : 1; // TextDirection
        unsigned _white_space : 3; // EWhiteSpace
        // 32 bits
        unsigned _border_collapse : 1; // EBorderCollapse
        unsigned _box_direction : 1; // EBoxDirection (CSS3 box_direction property, flexible box layout module)

        // non CSS2 inherited
        unsigned m_rtlOrdering : 1; // Order
        unsigned m_printColorAdjust : PrintColorAdjustBits;
        unsigned _pointerEvents : 4; // EPointerEvents
        unsigned _insideLink : 2; // EInsideLink
        // 43 bits

        // CSS Text Layout Module Level 3: Vertical writing support
        unsigned m_writingMode : 2; // WritingMode
        // 45 bits
    } inherited_flags;

// don't inherit
    struct NonInheritedFlags {
        bool operator==(const NonInheritedFlags& other) const
        {
            return _effectiveDisplay == other._effectiveDisplay
                && _originalDisplay == other._originalDisplay
                && _overflowX == other._overflowX
                && _overflowY == other._overflowY
                && _vertical_align == other._vertical_align
                && _clear == other._clear
                && _position == other._position
                && _floating == other._floating
                && _table_layout == other._table_layout
                && _page_break_before == other._page_break_before
                && _page_break_after == other._page_break_after
                && _page_break_inside == other._page_break_inside
                && _styleType == other._styleType
                && _affectedByHover == other._affectedByHover
                && _affectedByActive == other._affectedByActive
                && _affectedByDrag == other._affectedByDrag
                && _pseudoBits == other._pseudoBits
                && _unicodeBidi == other._unicodeBidi
                && _isLink == other._isLink;
        }

        bool operator!=(const NonInheritedFlags& other) const { return !(*this == other); }

        unsigned _effectiveDisplay : 5; // EDisplay
        unsigned _originalDisplay : 5; // EDisplay
        unsigned _overflowX : 3; // EOverflow
        unsigned _overflowY : 3; // EOverflow
        unsigned _vertical_align : 4; // EVerticalAlign
        unsigned _clear : 2; // EClear
        unsigned _position : 2; // EPosition
        unsigned _floating : 2; // EFloat
        unsigned _table_layout : 1; // ETableLayout

        unsigned _unicodeBidi : 3; // EUnicodeBidi
        unsigned _page_break_before : 2; // EPageBreak
        // 32 bits
        unsigned _page_break_after : 2; // EPageBreak
        unsigned _page_break_inside : 2; // EPageBreak

        unsigned _styleType : 6; // PseudoId
        unsigned _pseudoBits : 7;

        bool affectedByHover() const { return _affectedByHover; }
        void setAffectedByHover(bool value) { _affectedByHover = value; }
        bool affectedByActive() const { return _affectedByActive; }
        void setAffectedByActive(bool value) { _affectedByActive = value; }
        bool affectedByDrag() const { return _affectedByDrag; }
        void setAffectedByDrag(bool value) { _affectedByDrag = value; }
        bool isLink() const { return _isLink; }
        void setIsLink(bool value) { _isLink = value; }
    private:
        unsigned _affectedByHover : 1;
        unsigned _affectedByActive : 1;
        unsigned _affectedByDrag : 1;
        unsigned _isLink : 1;
        // If you add more style bits here, you will also need to update RenderStyle::copyNonInheritedFrom()
        // 53 bits
    } noninherited_flags;

// !END SYNC!

protected:
    void setBitDefaults()
    {
        inherited_flags._empty_cells = initialEmptyCells();
        inherited_flags._caption_side = initialCaptionSide();
        inherited_flags._list_style_type = initialListStyleType();
        inherited_flags._list_style_position = initialListStylePosition();
        inherited_flags._visibility = initialVisibility();
        inherited_flags._text_align = initialTextAlign();
        inherited_flags._text_transform = initialTextTransform();
        inherited_flags._text_decorations = initialTextDecoration();
        inherited_flags._cursor_style = initialCursor();
        inherited_flags._direction = initialDirection();
        inherited_flags._white_space = initialWhiteSpace();
        inherited_flags._border_collapse = initialBorderCollapse();
        inherited_flags.m_rtlOrdering = initialRTLOrdering();
        inherited_flags._box_direction = initialBoxDirection();
        inherited_flags.m_printColorAdjust = initialPrintColorAdjust();
        inherited_flags._pointerEvents = initialPointerEvents();
        inherited_flags._insideLink = NotInsideLink;
        inherited_flags.m_writingMode = initialWritingMode();

        noninherited_flags._effectiveDisplay = noninherited_flags._originalDisplay = initialDisplay();
        noninherited_flags._overflowX = initialOverflowX();
        noninherited_flags._overflowY = initialOverflowY();
        noninherited_flags._vertical_align = initialVerticalAlign();
        noninherited_flags._clear = initialClear();
        noninherited_flags._position = initialPosition();
        noninherited_flags._floating = initialFloating();
        noninherited_flags._table_layout = initialTableLayout();
        noninherited_flags._unicodeBidi = initialUnicodeBidi();
        noninherited_flags._page_break_before = initialPageBreak();
        noninherited_flags._page_break_after = initialPageBreak();
        noninherited_flags._page_break_inside = initialPageBreak();
        noninherited_flags._styleType = NOPSEUDO;
        noninherited_flags._pseudoBits = 0;
        noninherited_flags.setAffectedByHover(false);
        noninherited_flags.setAffectedByActive(false);
        noninherited_flags.setAffectedByDrag(false);
        noninherited_flags.setIsLink(false);
    }

private:
    ALWAYS_INLINE RenderStyle();
    // used to create the default style.
    ALWAYS_INLINE RenderStyle(bool);
    ALWAYS_INLINE RenderStyle(const RenderStyle&);

public:
    static PassRefPtr<RenderStyle> create();
    static PassRefPtr<RenderStyle> createDefaultStyle();
    static PassRefPtr<RenderStyle> createAnonymousStyle(const RenderStyle* parentStyle);
    static PassRefPtr<RenderStyle> clone(const RenderStyle*);

    void inheritFrom(const RenderStyle* inheritParent);
    void copyNonInheritedFrom(const RenderStyle*);

    PseudoId styleType() const { return static_cast<PseudoId>(noninherited_flags._styleType); }
    void setStyleType(PseudoId styleType) { noninherited_flags._styleType = styleType; }

    RenderStyle* getCachedPseudoStyle(PseudoId) const;
    RenderStyle* addCachedPseudoStyle(PassRefPtr<RenderStyle>);
    void removeCachedPseudoStyle(PseudoId);

    const PseudoStyleCache* cachedPseudoStyles() const { return m_cachedPseudoStyles.get(); }

    bool affectedByHoverRules() const { return noninherited_flags.affectedByHover(); }
    bool affectedByActiveRules() const { return noninherited_flags.affectedByActive(); }
    bool affectedByDragRules() const { return noninherited_flags.affectedByDrag(); }

    void setAffectedByHoverRules(bool b) { noninherited_flags.setAffectedByHover(b); }
    void setAffectedByActiveRules(bool b) { noninherited_flags.setAffectedByActive(b); }
    void setAffectedByDragRules(bool b) { noninherited_flags.setAffectedByDrag(b); }

    bool operator==(const RenderStyle& other) const;
    bool operator!=(const RenderStyle& other) const { return !(*this == other); }
    bool isFloating() const { return noninherited_flags._floating != NoFloat; }
    bool hasMargin() const { return surround->margin.nonZero(); }
    bool hasBorder() const { return surround->border.hasBorder(); }
    bool hasPadding() const { return surround->padding.nonZero(); }
    bool hasOffset() const { return surround->offset.nonZero(); }

    bool hasBackgroundImage() const { return m_background->background().hasImage(); }
    bool hasFixedBackgroundImage() const { return m_background->background().hasFixedImage(); }
    bool hasAppearance() const { return appearance() != NoControlPart; }

    bool hasBackground() const
    {
        Color color = visitedDependentColor(CSSPropertyBackgroundColor);
        if (color.isValid() && color.alpha() > 0)
            return true;
        return hasBackgroundImage();
    }
    
    void getImageOutsets(const NinePieceImage&, LayoutUnit& top, LayoutUnit& right, LayoutUnit& bottom, LayoutUnit& left) const;
    bool hasBorderImageOutsets() const
    {
        return borderImage().hasImage() && borderImage().outset().nonZero();
    }
    void getBorderImageOutsets(LayoutUnit& top, LayoutUnit& right, LayoutUnit& bottom, LayoutUnit& left) const
    {
        return getImageOutsets(borderImage(), top, right, bottom, left);
    }
    void getBorderImageHorizontalOutsets(LayoutUnit& left, LayoutUnit& right) const
    {
        return getImageHorizontalOutsets(borderImage(), left, right);
    }
    void getBorderImageVerticalOutsets(LayoutUnit& top, LayoutUnit& bottom) const
    {
        return getImageVerticalOutsets(borderImage(), top, bottom);
    }
    void getBorderImageInlineDirectionOutsets(LayoutUnit& logicalLeft, LayoutUnit& logicalRight) const
    {
        return getImageInlineDirectionOutsets(borderImage(), logicalLeft, logicalRight);
    }
    void getBorderImageBlockDirectionOutsets(LayoutUnit& logicalTop, LayoutUnit& logicalBottom) const
    {
        return getImageBlockDirectionOutsets(borderImage(), logicalTop, logicalBottom);
    }
    
    void getMaskBoxImageOutsets(LayoutUnit& top, LayoutUnit& right, LayoutUnit& bottom, LayoutUnit& left) const
    {
        return getImageOutsets(maskBoxImage(), top, right, bottom, left);
    }

#if ENABLE(CSS_FILTERS)
    void getFilterOutsets(LayoutUnit& top, LayoutUnit& right, LayoutUnit& bottom, LayoutUnit& left) const
    {
        if (hasFilter())
            filter().getOutsets(top, right, bottom, left);
        else {
            top = 0;
            right = 0;
            bottom = 0;
            left = 0;
        }
    }
    bool hasFilterOutsets() const { return hasFilter() && filter().hasOutsets(); }
#else
    bool hasFilterOutsets() const { return false; }
#endif

    Order rtlOrdering() const { return static_cast<Order>(inherited_flags.m_rtlOrdering); }
    void setRTLOrdering(Order o) { inherited_flags.m_rtlOrdering = o; }

    bool isStyleAvailable() const;

    bool hasAnyPublicPseudoStyles() const;
    bool hasPseudoStyle(PseudoId pseudo) const;
    void setHasPseudoStyle(PseudoId pseudo);

    // attribute getter methods

    EDisplay display() const { return static_cast<EDisplay>(noninherited_flags._effectiveDisplay); }
    EDisplay originalDisplay() const { return static_cast<EDisplay>(noninherited_flags._originalDisplay); }

    Length left() const { return surround->offset.left(); }
    Length right() const { return surround->offset.right(); }
    Length top() const { return surround->offset.top(); }
    Length bottom() const { return surround->offset.bottom(); }

    // Accessors for positioned object edges that take into account writing mode.
    Length logicalLeft() const { return isHorizontalWritingMode() ? left() : top(); }
    Length logicalRight() const { return isHorizontalWritingMode() ? right() : bottom(); }
    Length logicalTop() const { return isHorizontalWritingMode() ? (isFlippedBlocksWritingMode() ? bottom() : top()) : (isFlippedBlocksWritingMode() ? right() : left()); }
    Length logicalBottom() const { return isHorizontalWritingMode() ? (isFlippedBlocksWritingMode() ? top() : bottom()) : (isFlippedBlocksWritingMode() ? left() : right()); }

    // Whether or not a positioned element requires normal flow x/y to be computed
    // to determine its position.
    bool hasAutoLeftAndRight() const { return left().isAuto() && right().isAuto(); }
    bool hasAutoTopAndBottom() const { return top().isAuto() && bottom().isAuto(); }
    bool hasStaticInlinePosition(bool horizontal) const { return horizontal ? hasAutoLeftAndRight() : hasAutoTopAndBottom(); }
    bool hasStaticBlockPosition(bool horizontal) const { return horizontal ? hasAutoTopAndBottom() : hasAutoLeftAndRight(); }

    EPosition position() const { return static_cast<EPosition>(noninherited_flags._position); }
    bool isPositioned() const { return position() == AbsolutePosition || position() == FixedPosition; }
    EFloat floating() const { return static_cast<EFloat>(noninherited_flags._floating); }

    Length width() const { return m_box->width(); }
    Length height() const { return m_box->height(); }
    Length minWidth() const { return m_box->minWidth(); }
    Length maxWidth() const { return m_box->maxWidth(); }
    Length minHeight() const { return m_box->minHeight(); }
    Length maxHeight() const { return m_box->maxHeight(); }
    
    Length logicalWidth() const;
    Length logicalHeight() const;
    Length logicalMinWidth() const;
    Length logicalMaxWidth() const;
    Length logicalMinHeight() const;
    Length logicalMaxHeight() const;

    const BorderData& border() const { return surround->border; }
    const BorderValue& borderLeft() const { return surround->border.left(); }
    const BorderValue& borderRight() const { return surround->border.right(); }
    const BorderValue& borderTop() const { return surround->border.top(); }
    const BorderValue& borderBottom() const { return surround->border.bottom(); }

    const BorderValue& borderBefore() const;
    const BorderValue& borderAfter() const;
    const BorderValue& borderStart() const;
    const BorderValue& borderEnd() const;

    const NinePieceImage& borderImage() const { return surround->border.image(); }
    StyleImage* borderImageSource() const { return surround->border.image().image(); }
 
    LengthSize borderTopLeftRadius() const { return surround->border.topLeft(); }
    LengthSize borderTopRightRadius() const { return surround->border.topRight(); }
    LengthSize borderBottomLeftRadius() const { return surround->border.bottomLeft(); }
    LengthSize borderBottomRightRadius() const { return surround->border.bottomRight(); }
    bool hasBorderRadius() const { return surround->border.hasBorderRadius(); }

    unsigned borderLeftWidth() const { return surround->border.borderLeftWidth(); }
    EBorderStyle borderLeftStyle() const { return surround->border.left().style(); }
    bool borderLeftIsTransparent() const { return surround->border.left().isTransparent(); }
    unsigned borderRightWidth() const { return surround->border.borderRightWidth(); }
    EBorderStyle borderRightStyle() const { return surround->border.right().style(); }
    bool borderRightIsTransparent() const { return surround->border.right().isTransparent(); }
    unsigned borderTopWidth() const { return surround->border.borderTopWidth(); }
    EBorderStyle borderTopStyle() const { return surround->border.top().style(); }
    bool borderTopIsTransparent() const { return surround->border.top().isTransparent(); }
    unsigned borderBottomWidth() const { return surround->border.borderBottomWidth(); }
    EBorderStyle borderBottomStyle() const { return surround->border.bottom().style(); }
    bool borderBottomIsTransparent() const { return surround->border.bottom().isTransparent(); }
    
    unsigned short borderBeforeWidth() const;
    unsigned short borderAfterWidth() const;
    unsigned short borderStartWidth() const;
    unsigned short borderEndWidth() const;

    unsigned short outlineSize() const { return max(0, outlineWidth() + outlineOffset()); }
    unsigned short outlineWidth() const
    {
        if (m_background->outline().style() == BNONE)
            return 0;
        return m_background->outline().width();
    }
    bool hasOutline() const { return outlineWidth() > 0 && outlineStyle() > BHIDDEN; }
    EBorderStyle outlineStyle() const { return m_background->outline().style(); }
    OutlineIsAuto outlineStyleIsAuto() const { return static_cast<OutlineIsAuto>(m_background->outline().isAuto()); }
    
    EOverflow overflowX() const { return static_cast<EOverflow>(noninherited_flags._overflowX); }
    EOverflow overflowY() const { return static_cast<EOverflow>(noninherited_flags._overflowY); }

    EVisibility visibility() const { return static_cast<EVisibility>(inherited_flags._visibility); }
    EVerticalAlign verticalAlign() const { return static_cast<EVerticalAlign>(noninherited_flags._vertical_align); }
    Length verticalAlignLength() const { return m_box->verticalAlign(); }

    Length clipLeft() const { return visual->clip.left(); }
    Length clipRight() const { return visual->clip.right(); }
    Length clipTop() const { return visual->clip.top(); }
    Length clipBottom() const { return visual->clip.bottom(); }
    LengthBox clip() const { return visual->clip; }
    bool hasClip() const { return visual->hasClip; }

    EUnicodeBidi unicodeBidi() const { return static_cast<EUnicodeBidi>(noninherited_flags._unicodeBidi); }

    EClear clear() const { return static_cast<EClear>(noninherited_flags._clear); }
    ETableLayout tableLayout() const { return static_cast<ETableLayout>(noninherited_flags._table_layout); }

    const Font& font() const { return inherited->font; }
    const FontMetrics& fontMetrics() const { return inherited->font.fontMetrics(); }
    const FontDescription& fontDescription() const { return inherited->font.fontDescription(); }
    int fontSize() const { return inherited->font.pixelSize(); }

    Length textIndent() const { return rareInheritedData->indent; }
    ETextAlign textAlign() const { return static_cast<ETextAlign>(inherited_flags._text_align); }
    ETextTransform textTransform() const { return static_cast<ETextTransform>(inherited_flags._text_transform); }
    ETextDecoration textDecorationsInEffect() const { return static_cast<ETextDecoration>(inherited_flags._text_decorations); }
    ETextDecoration textDecoration() const { return static_cast<ETextDecoration>(visual->textDecoration); }
    int wordSpacing() const { return inherited->font.wordSpacing(); }
    int letterSpacing() const { return inherited->font.letterSpacing(); }

    float zoom() const { return visual->m_zoom; }
    float effectiveZoom() const { return rareInheritedData->m_effectiveZoom; }

    TextDirection direction() const { return static_cast<TextDirection>(inherited_flags._direction); }
    bool isLeftToRightDirection() const { return direction() == LTR; }

    Length lineHeight() const { return inherited->line_height; }
    int computedLineHeight() const
    {
        const Length& lh = inherited->line_height;

        // Negative value means the line height is not set.  Use the font's built-in spacing.
        if (lh.isNegative())
            return fontMetrics().lineSpacing();

        if (lh.isPercent())
            return lh.calcMinValue(fontSize());

        return lh.value();
    }

    EWhiteSpace whiteSpace() const { return static_cast<EWhiteSpace>(inherited_flags._white_space); }
    static bool autoWrap(EWhiteSpace ws)
    {
        // Nowrap and pre don't automatically wrap.
        return ws != NOWRAP && ws != PRE;
    }

    bool autoWrap() const
    {
        return autoWrap(whiteSpace());
    }

    static bool preserveNewline(EWhiteSpace ws)
    {
        // Normal and nowrap do not preserve newlines.
        return ws != NORMAL && ws != NOWRAP;
    }

    bool preserveNewline() const
    {
        return preserveNewline(whiteSpace());
    }

    static bool collapseWhiteSpace(EWhiteSpace ws)
    {
        // Pre and prewrap do not collapse whitespace.
        return ws != PRE && ws != PRE_WRAP;
    }

    bool collapseWhiteSpace() const
    {
        return collapseWhiteSpace(whiteSpace());
    }

    bool isCollapsibleWhiteSpace(UChar c) const
    {
        switch (c) {
            case ' ':
            case '\t':
                return collapseWhiteSpace();
            case '\n':
                return !preserveNewline();
        }
        return false;
    }

    bool breakOnlyAfterWhiteSpace() const
    {
        return whiteSpace() == PRE_WRAP || khtmlLineBreak() == AFTER_WHITE_SPACE;
    }

    bool breakWords() const
    {
        return wordBreak() == BreakWordBreak || wordWrap() == BreakWordWrap;
    }

    EFillRepeat backgroundRepeatX() const { return static_cast<EFillRepeat>(m_background->background().repeatX()); }
    EFillRepeat backgroundRepeatY() const { return static_cast<EFillRepeat>(m_background->background().repeatY()); }
    CompositeOperator backgroundComposite() const { return static_cast<CompositeOperator>(m_background->background().composite()); }
    EFillAttachment backgroundAttachment() const { return static_cast<EFillAttachment>(m_background->background().attachment()); }
    EFillBox backgroundClip() const { return static_cast<EFillBox>(m_background->background().clip()); }
    EFillBox backgroundOrigin() const { return static_cast<EFillBox>(m_background->background().origin()); }
    Length backgroundXPosition() const { return m_background->background().xPosition(); }
    Length backgroundYPosition() const { return m_background->background().yPosition(); }
    EFillSizeType backgroundSizeType() const { return m_background->background().sizeType(); }
    LengthSize backgroundSizeLength() const { return m_background->background().sizeLength(); }
    FillLayer* accessBackgroundLayers() { return &(m_background.access()->m_background); }
    const FillLayer* backgroundLayers() const { return &(m_background->background()); }

    StyleImage* maskImage() const { return rareNonInheritedData->m_mask.image(); }
    EFillRepeat maskRepeatX() const { return static_cast<EFillRepeat>(rareNonInheritedData->m_mask.repeatX()); }
    EFillRepeat maskRepeatY() const { return static_cast<EFillRepeat>(rareNonInheritedData->m_mask.repeatY()); }
    CompositeOperator maskComposite() const { return static_cast<CompositeOperator>(rareNonInheritedData->m_mask.composite()); }
    EFillAttachment maskAttachment() const { return static_cast<EFillAttachment>(rareNonInheritedData->m_mask.attachment()); }
    EFillBox maskClip() const { return static_cast<EFillBox>(rareNonInheritedData->m_mask.clip()); }
    EFillBox maskOrigin() const { return static_cast<EFillBox>(rareNonInheritedData->m_mask.origin()); }
    Length maskXPosition() const { return rareNonInheritedData->m_mask.xPosition(); }
    Length maskYPosition() const { return rareNonInheritedData->m_mask.yPosition(); }
    EFillSizeType maskSizeType() const { return rareNonInheritedData->m_mask.sizeType(); }
    LengthSize maskSizeLength() const { return rareNonInheritedData->m_mask.sizeLength(); }
    FillLayer* accessMaskLayers() { return &(rareNonInheritedData.access()->m_mask); }
    const FillLayer* maskLayers() const { return &(rareNonInheritedData->m_mask); }
    const NinePieceImage& maskBoxImage() const { return rareNonInheritedData->m_maskBoxImage; }
    StyleImage* maskBoxImageSource() const { return rareNonInheritedData->m_maskBoxImage.image(); }
 
    EBorderCollapse borderCollapse() const { return static_cast<EBorderCollapse>(inherited_flags._border_collapse); }
    short horizontalBorderSpacing() const { return inherited->horizontal_border_spacing; }
    short verticalBorderSpacing() const { return inherited->vertical_border_spacing; }
    EEmptyCell emptyCells() const { return static_cast<EEmptyCell>(inherited_flags._empty_cells); }
    ECaptionSide captionSide() const { return static_cast<ECaptionSide>(inherited_flags._caption_side); }

    short counterIncrement() const { return rareNonInheritedData->m_counterIncrement; }
    short counterReset() const { return rareNonInheritedData->m_counterReset; }

    EListStyleType listStyleType() const { return static_cast<EListStyleType>(inherited_flags._list_style_type); }
    StyleImage* listStyleImage() const { return inherited->list_style_image.get(); }
    EListStylePosition listStylePosition() const { return static_cast<EListStylePosition>(inherited_flags._list_style_position); }

    Length marginTop() const { return surround->margin.top(); }
    Length marginBottom() const { return surround->margin.bottom(); }
    Length marginLeft() const { return surround->margin.left(); }
    Length marginRight() const { return surround->margin.right(); }
    Length marginBefore() const;
    Length marginAfter() const;
    Length marginStart() const;
    Length marginEnd() const;
    Length marginStartUsing(const RenderStyle* otherStyle) const;
    Length marginEndUsing(const RenderStyle* otherStyle) const;
    Length marginBeforeUsing(const RenderStyle* otherStyle) const;
    Length marginAfterUsing(const RenderStyle* otherStyle) const;

    LengthBox paddingBox() const { return surround->padding; }
    Length paddingTop() const { return surround->padding.top(); }
    Length paddingBottom() const { return surround->padding.bottom(); }
    Length paddingLeft() const { return surround->padding.left(); }
    Length paddingRight() const { return surround->padding.right(); }
    Length paddingBefore() const;
    Length paddingAfter() const;
    Length paddingStart() const;
    Length paddingEnd() const;

    ECursor cursor() const { return static_cast<ECursor>(inherited_flags._cursor_style); }

    CursorList* cursors() const { return rareInheritedData->cursorData.get(); }

    EInsideLink insideLink() const { return static_cast<EInsideLink>(inherited_flags._insideLink); }
    bool isLink() const { return noninherited_flags.isLink(); }

    short widows() const { return rareInheritedData->widows; }
    short orphans() const { return rareInheritedData->orphans; }
    EPageBreak pageBreakInside() const { return static_cast<EPageBreak>(noninherited_flags._page_break_inside); }
    EPageBreak pageBreakBefore() const { return static_cast<EPageBreak>(noninherited_flags._page_break_before); }
    EPageBreak pageBreakAfter() const { return static_cast<EPageBreak>(noninherited_flags._page_break_after); }

    // CSS3 Getter Methods

    int outlineOffset() const
    {
        if (m_background->outline().style() == BNONE)
            return 0;
        return m_background->outline().offset();
    }

    const ShadowData* textShadow() const { return rareInheritedData->textShadow.get(); }
    void getTextShadowExtent(LayoutUnit& top, LayoutUnit& right, LayoutUnit& bottom, LayoutUnit& left) const { getShadowExtent(textShadow(), top, right, bottom, left); }
    void getTextShadowHorizontalExtent(LayoutUnit& left, LayoutUnit& right) const { getShadowHorizontalExtent(textShadow(), left, right); }
    void getTextShadowVerticalExtent(LayoutUnit& top, LayoutUnit& bottom) const { getShadowVerticalExtent(textShadow(), top, bottom); }
    void getTextShadowInlineDirectionExtent(LayoutUnit& logicalLeft, LayoutUnit& logicalRight) { getShadowInlineDirectionExtent(textShadow(), logicalLeft, logicalRight); }
    void getTextShadowBlockDirectionExtent(LayoutUnit& logicalTop, LayoutUnit& logicalBottom) { getShadowBlockDirectionExtent(textShadow(), logicalTop, logicalBottom); }

    float textStrokeWidth() const { return rareInheritedData->textStrokeWidth; }
    ColorSpace colorSpace() const { return static_cast<ColorSpace>(rareInheritedData->colorSpace); }
    float opacity() const { return rareNonInheritedData->opacity; }
    ControlPart appearance() const { return static_cast<ControlPart>(rareNonInheritedData->m_appearance); }
    // aspect ratio convenience method
    bool hasAspectRatio() const { return rareNonInheritedData->m_hasAspectRatio; }
    float aspectRatio() const { return aspectRatioNumerator() / aspectRatioDenominator(); }
    float aspectRatioDenominator() const { return rareNonInheritedData->m_aspectRatioDenominator; }
    float aspectRatioNumerator() const { return rareNonInheritedData->m_aspectRatioNumerator; }
    EBoxAlignment boxAlign() const { return static_cast<EBoxAlignment>(rareNonInheritedData->m_deprecatedFlexibleBox->align); }
    EBoxDirection boxDirection() const { return static_cast<EBoxDirection>(inherited_flags._box_direction); }
    float boxFlex() { return rareNonInheritedData->m_deprecatedFlexibleBox->flex; }
    unsigned int boxFlexGroup() const { return rareNonInheritedData->m_deprecatedFlexibleBox->flex_group; }
    EBoxLines boxLines() { return static_cast<EBoxLines>(rareNonInheritedData->m_deprecatedFlexibleBox->lines); }
    unsigned int boxOrdinalGroup() const { return rareNonInheritedData->m_deprecatedFlexibleBox->ordinal_group; }
    EBoxOrient boxOrient() const { return static_cast<EBoxOrient>(rareNonInheritedData->m_deprecatedFlexibleBox->orient); }
    EBoxPack boxPack() const { return static_cast<EBoxPack>(rareNonInheritedData->m_deprecatedFlexibleBox->pack); }

    float flexboxWidthPositiveFlex() const { return rareNonInheritedData->m_flexibleBox->m_widthPositiveFlex; }
    float flexboxWidthNegativeFlex() const { return rareNonInheritedData->m_flexibleBox->m_widthNegativeFlex; }
    float flexboxHeightPositiveFlex() const { return rareNonInheritedData->m_flexibleBox->m_heightPositiveFlex; }
    float flexboxHeightNegativeFlex() const { return rareNonInheritedData->m_flexibleBox->m_heightNegativeFlex; }
    int flexOrder() const { return rareNonInheritedData->m_flexibleBox->m_flexOrder; }
    EFlexPack flexPack() const { return static_cast<EFlexPack>(rareNonInheritedData->m_flexibleBox->m_flexPack); }
    EFlexAlign flexAlign() const { return static_cast<EFlexAlign>(rareNonInheritedData->m_flexibleBox->m_flexAlign); }
    EFlexAlign flexItemAlign() const { return static_cast<EFlexAlign>(rareNonInheritedData->m_flexibleBox->m_flexItemAlign); }
    EFlexDirection flexDirection() const { return static_cast<EFlexDirection>(rareNonInheritedData->m_flexibleBox->m_flexDirection); }
    bool isColumnFlexDirection() const { return flexDirection() == FlowColumn || flexDirection() == FlowColumnReverse; }
    EFlexWrap flexWrap() const { return static_cast<EFlexWrap>(rareNonInheritedData->m_flexibleBox->m_flexWrap); }

#if ENABLE(CSS_GRID_LAYOUT)
    const Vector<Length>& gridColumns() const { return rareNonInheritedData->m_grid->m_gridColumns; }
    const Vector<Length>& gridRows() const { return rareNonInheritedData->m_grid->m_gridRows; }
#endif

    const ShadowData* boxShadow() const { return rareNonInheritedData->m_boxShadow.get(); }
    void getBoxShadowExtent(LayoutUnit& top, LayoutUnit& right, LayoutUnit& bottom, LayoutUnit& left) const { getShadowExtent(boxShadow(), top, right, bottom, left); }
    void getBoxShadowHorizontalExtent(LayoutUnit& left, LayoutUnit& right) const { getShadowHorizontalExtent(boxShadow(), left, right); }
    void getBoxShadowVerticalExtent(LayoutUnit& top, LayoutUnit& bottom) const { getShadowVerticalExtent(boxShadow(), top, bottom); }
    void getBoxShadowInlineDirectionExtent(LayoutUnit& logicalLeft, LayoutUnit& logicalRight) { getShadowInlineDirectionExtent(boxShadow(), logicalLeft, logicalRight); }
    void getBoxShadowBlockDirectionExtent(LayoutUnit& logicalTop, LayoutUnit& logicalBottom) { getShadowBlockDirectionExtent(boxShadow(), logicalTop, logicalBottom); }

    StyleReflection* boxReflect() const { return rareNonInheritedData->m_boxReflect.get(); }
    EBoxSizing boxSizing() const { return m_box->boxSizing(); }
    Length marqueeIncrement() const { return rareNonInheritedData->m_marquee->increment; }
    int marqueeSpeed() const { return rareNonInheritedData->m_marquee->speed; }
    int marqueeLoopCount() const { return rareNonInheritedData->m_marquee->loops; }
    EMarqueeBehavior marqueeBehavior() const { return static_cast<EMarqueeBehavior>(rareNonInheritedData->m_marquee->behavior); }
    EMarqueeDirection marqueeDirection() const { return static_cast<EMarqueeDirection>(rareNonInheritedData->m_marquee->direction); }
    EUserModify userModify() const { return static_cast<EUserModify>(rareInheritedData->userModify); }
    EUserDrag userDrag() const { return static_cast<EUserDrag>(rareNonInheritedData->userDrag); }
    EUserSelect userSelect() const { return static_cast<EUserSelect>(rareInheritedData->userSelect); }
    TextOverflow textOverflow() const { return static_cast<TextOverflow>(rareNonInheritedData->textOverflow); }
    EMarginCollapse marginBeforeCollapse() const { return static_cast<EMarginCollapse>(rareNonInheritedData->marginBeforeCollapse); }
    EMarginCollapse marginAfterCollapse() const { return static_cast<EMarginCollapse>(rareNonInheritedData->marginAfterCollapse); }
    EWordBreak wordBreak() const { return static_cast<EWordBreak>(rareInheritedData->wordBreak); }
    EWordWrap wordWrap() const { return static_cast<EWordWrap>(rareInheritedData->wordWrap); }
    ENBSPMode nbspMode() const { return static_cast<ENBSPMode>(rareInheritedData->nbspMode); }
    EKHTMLLineBreak khtmlLineBreak() const { return static_cast<EKHTMLLineBreak>(rareInheritedData->khtmlLineBreak); }
    EMatchNearestMailBlockquoteColor matchNearestMailBlockquoteColor() const { return static_cast<EMatchNearestMailBlockquoteColor>(rareNonInheritedData->matchNearestMailBlockquoteColor); }
    const AtomicString& highlight() const { return rareInheritedData->highlight; }
    Hyphens hyphens() const { return static_cast<Hyphens>(rareInheritedData->hyphens); }
    short hyphenationLimitBefore() const { return rareInheritedData->hyphenationLimitBefore; }
    short hyphenationLimitAfter() const { return rareInheritedData->hyphenationLimitAfter; }
    short hyphenationLimitLines() const { return rareInheritedData->hyphenationLimitLines; }
    const AtomicString& hyphenationString() const { return rareInheritedData->hyphenationString; }
    const AtomicString& locale() const { return rareInheritedData->locale; }
    EBorderFit borderFit() const { return static_cast<EBorderFit>(rareNonInheritedData->m_borderFit); }
    EResize resize() const { return static_cast<EResize>(rareInheritedData->resize); }
    ColumnAxis columnAxis() const { return static_cast<ColumnAxis>(rareNonInheritedData->m_multiCol->m_axis); }
    bool hasInlineColumnAxis() const {
        ColumnAxis axis = columnAxis();
        return axis == AutoColumnAxis || isHorizontalWritingMode() == (axis == HorizontalColumnAxis);
    }
    float columnWidth() const { return rareNonInheritedData->m_multiCol->m_width; }
    bool hasAutoColumnWidth() const { return rareNonInheritedData->m_multiCol->m_autoWidth; }
    unsigned short columnCount() const { return rareNonInheritedData->m_multiCol->m_count; }
    bool hasAutoColumnCount() const { return rareNonInheritedData->m_multiCol->m_autoCount; }
    bool specifiesColumns() const { return !hasAutoColumnCount() || !hasAutoColumnWidth() || !hasInlineColumnAxis(); }
    float columnGap() const { return rareNonInheritedData->m_multiCol->m_gap; }
    bool hasNormalColumnGap() const { return rareNonInheritedData->m_multiCol->m_normalGap; }
    EBorderStyle columnRuleStyle() const { return rareNonInheritedData->m_multiCol->m_rule.style(); }
    unsigned short columnRuleWidth() const { return rareNonInheritedData->m_multiCol->ruleWidth(); }
    bool columnRuleIsTransparent() const { return rareNonInheritedData->m_multiCol->m_rule.isTransparent(); }
    ColumnSpan columnSpan() const { return static_cast<ColumnSpan>(rareNonInheritedData->m_multiCol->m_columnSpan); }
    EPageBreak columnBreakBefore() const { return static_cast<EPageBreak>(rareNonInheritedData->m_multiCol->m_breakBefore); }
    EPageBreak columnBreakInside() const { return static_cast<EPageBreak>(rareNonInheritedData->m_multiCol->m_breakInside); }
    EPageBreak columnBreakAfter() const { return static_cast<EPageBreak>(rareNonInheritedData->m_multiCol->m_breakAfter); }
    EPageBreak regionBreakBefore() const { return static_cast<EPageBreak>(rareNonInheritedData->m_regionBreakBefore); }
    EPageBreak regionBreakInside() const { return static_cast<EPageBreak>(rareNonInheritedData->m_regionBreakInside); }
    EPageBreak regionBreakAfter() const { return static_cast<EPageBreak>(rareNonInheritedData->m_regionBreakAfter); }
    const TransformOperations& transform() const { return rareNonInheritedData->m_transform->m_operations; }
    Length transformOriginX() const { return rareNonInheritedData->m_transform->m_x; }
    Length transformOriginY() const { return rareNonInheritedData->m_transform->m_y; }
    float transformOriginZ() const { return rareNonInheritedData->m_transform->m_z; }
    bool hasTransform() const { return !rareNonInheritedData->m_transform->m_operations.operations().isEmpty(); }

    TextEmphasisFill textEmphasisFill() const { return static_cast<TextEmphasisFill>(rareInheritedData->textEmphasisFill); }
    TextEmphasisMark textEmphasisMark() const;
    const AtomicString& textEmphasisCustomMark() const { return rareInheritedData->textEmphasisCustomMark; }
    TextEmphasisPosition textEmphasisPosition() const { return static_cast<TextEmphasisPosition>(rareInheritedData->textEmphasisPosition); }
    const AtomicString& textEmphasisMarkString() const;
    
    // Return true if any transform related property (currently transform, transformStyle3D or perspective) 
    // indicates that we are transforming
    bool hasTransformRelatedProperty() const { return hasTransform() || preserves3D() || hasPerspective(); }

    enum ApplyTransformOrigin { IncludeTransformOrigin, ExcludeTransformOrigin };
    void applyTransform(TransformationMatrix&, const LayoutSize& borderBoxSize, ApplyTransformOrigin = IncludeTransformOrigin) const;
    void setPageScaleTransform(float);

    bool hasMask() const { return rareNonInheritedData->m_mask.hasImage() || rareNonInheritedData->m_maskBoxImage.hasImage(); }

    TextCombine textCombine() const { return static_cast<TextCombine>(rareNonInheritedData->m_textCombine); }
    bool hasTextCombine() const { return textCombine() != TextCombineNone; }
    // End CSS3 Getters

    const AtomicString& flowThread() const { return rareNonInheritedData->m_flowThread; }
    const AtomicString& regionThread() const { return rareNonInheritedData->m_regionThread; }
    RegionOverflow regionOverflow() const { return static_cast<RegionOverflow>(rareNonInheritedData->m_regionOverflow); }

    const AtomicString& lineGrid() const { return rareInheritedData->m_lineGrid; }
    LineGridSnap lineGridSnap() const { return static_cast<LineGridSnap>(rareInheritedData->m_lineGridSnap); }

    WrapFlow wrapFlow() const { return static_cast<WrapFlow>(rareNonInheritedData->m_wrapFlow); }
    WrapThrough wrapThrough() const { return static_cast<WrapThrough>(rareNonInheritedData->m_wrapThrough); }

    // Apple-specific property getter methods
    EPointerEvents pointerEvents() const { return static_cast<EPointerEvents>(inherited_flags._pointerEvents); }
    const AnimationList* animations() const { return rareNonInheritedData->m_animations.get(); }
    const AnimationList* transitions() const { return rareNonInheritedData->m_transitions.get(); }

    AnimationList* accessAnimations();
    AnimationList* accessTransitions();

    bool hasAnimations() const { return rareNonInheritedData->m_animations && rareNonInheritedData->m_animations->size() > 0; }
    bool hasTransitions() const { return rareNonInheritedData->m_transitions && rareNonInheritedData->m_transitions->size() > 0; }

    // return the first found Animation (including 'all' transitions)
    const Animation* transitionForProperty(int property) const;

    ETransformStyle3D transformStyle3D() const { return static_cast<ETransformStyle3D>(rareNonInheritedData->m_transformStyle3D); }
    bool preserves3D() const { return rareNonInheritedData->m_transformStyle3D == TransformStyle3DPreserve3D; }

    EBackfaceVisibility backfaceVisibility() const { return static_cast<EBackfaceVisibility>(rareNonInheritedData->m_backfaceVisibility); }
    float perspective() const { return rareNonInheritedData->m_perspective; }
    bool hasPerspective() const { return rareNonInheritedData->m_perspective > 0; }
    Length perspectiveOriginX() const { return rareNonInheritedData->m_perspectiveOriginX; }
    Length perspectiveOriginY() const { return rareNonInheritedData->m_perspectiveOriginY; }
    LengthSize pageSize() const { return rareNonInheritedData->m_pageSize; }
    PageSizeType pageSizeType() const { return static_cast<PageSizeType>(rareNonInheritedData->m_pageSizeType); }
    
#if USE(ACCELERATED_COMPOSITING)
    // When set, this ensures that styles compare as different. Used during accelerated animations.
    bool isRunningAcceleratedAnimation() const { return rareNonInheritedData->m_runningAcceleratedAnimation; }
#endif

    LineBoxContain lineBoxContain() const { return rareInheritedData->m_lineBoxContain; }
    const LineClampValue& lineClamp() const { return rareNonInheritedData->lineClamp; }
#if ENABLE(TOUCH_EVENTS)
    Color tapHighlightColor() const { return rareInheritedData->tapHighlightColor; }
#endif
    bool textSizeAdjust() const { return rareInheritedData->textSizeAdjust; }
    ETextSecurity textSecurity() const { return static_cast<ETextSecurity>(rareInheritedData->textSecurity); }

    WritingMode writingMode() const { return static_cast<WritingMode>(inherited_flags.m_writingMode); }
    bool isHorizontalWritingMode() const { return writingMode() == TopToBottomWritingMode || writingMode() == BottomToTopWritingMode; }
    bool isFlippedLinesWritingMode() const { return writingMode() == LeftToRightWritingMode || writingMode() == BottomToTopWritingMode; }
    bool isFlippedBlocksWritingMode() const { return writingMode() == RightToLeftWritingMode || writingMode() == BottomToTopWritingMode; }

    EImageRendering imageRendering() const { return static_cast<EImageRendering>(rareInheritedData->m_imageRendering); }
    
    ESpeak speak() { return static_cast<ESpeak>(rareInheritedData->speak); }

#if ENABLE(CSS_FILTERS)
    FilterOperations& filter() { return rareNonInheritedData.access()->m_filter.access()->m_operations; }
    const FilterOperations& filter() const { return rareNonInheritedData->m_filter->m_operations; }
    bool hasFilter() const { return !rareNonInheritedData->m_filter->m_operations.operations().isEmpty(); }
#else
    bool hasFilter() const { return false; }
#endif
        
// attribute setter methods

    void setDisplay(EDisplay v) { noninherited_flags._effectiveDisplay = v; }
    void setOriginalDisplay(EDisplay v) { noninherited_flags._originalDisplay = v; }
    void setPosition(EPosition v) { noninherited_flags._position = v; }
    void setFloating(EFloat v) { noninherited_flags._floating = v; }

    void setLeft(Length v) { SET_VAR(surround, offset.m_left, v) }
    void setRight(Length v) { SET_VAR(surround, offset.m_right, v) }
    void setTop(Length v) { SET_VAR(surround, offset.m_top, v) }
    void setBottom(Length v) { SET_VAR(surround, offset.m_bottom, v) }

    void setWidth(Length v) { SET_VAR(m_box, m_width, v) }
    void setHeight(Length v) { SET_VAR(m_box, m_height, v) }

    void setMinWidth(Length v) { SET_VAR(m_box, m_minWidth, v) }
    void setMaxWidth(Length v) { SET_VAR(m_box, m_maxWidth, v) }
    void setMinHeight(Length v) { SET_VAR(m_box, m_minHeight, v) }
    void setMaxHeight(Length v) { SET_VAR(m_box, m_maxHeight, v) }

#if ENABLE(DASHBOARD_SUPPORT)
    Vector<StyleDashboardRegion> dashboardRegions() const { return rareNonInheritedData->m_dashboardRegions; }
    void setDashboardRegions(Vector<StyleDashboardRegion> regions) { SET_VAR(rareNonInheritedData, m_dashboardRegions, regions); }

    void setDashboardRegion(int type, const String& label, Length t, Length r, Length b, Length l, bool append)
    {
        StyleDashboardRegion region;
        region.label = label;
        region.offset.m_top = t;
        region.offset.m_right = r;
        region.offset.m_bottom = b;
        region.offset.m_left = l;
        region.type = type;
        if (!append)
            rareNonInheritedData.access()->m_dashboardRegions.clear();
        rareNonInheritedData.access()->m_dashboardRegions.append(region);
    }
#endif

    void resetBorder() { resetBorderImage(); resetBorderTop(); resetBorderRight(); resetBorderBottom(); resetBorderLeft(); resetBorderRadius(); }
    void resetBorderTop() { SET_VAR(surround, border.m_top, BorderValue()) }
    void resetBorderRight() { SET_VAR(surround, border.m_right, BorderValue()) }
    void resetBorderBottom() { SET_VAR(surround, border.m_bottom, BorderValue()) }
    void resetBorderLeft() { SET_VAR(surround, border.m_left, BorderValue()) }
    void resetBorderImage() { SET_VAR(surround, border.m_image, NinePieceImage()) }
    void resetBorderRadius() { resetBorderTopLeftRadius(); resetBorderTopRightRadius(); resetBorderBottomLeftRadius(); resetBorderBottomRightRadius(); }
    void resetBorderTopLeftRadius() { SET_VAR(surround, border.m_topLeft, initialBorderRadius()) }
    void resetBorderTopRightRadius() { SET_VAR(surround, border.m_topRight, initialBorderRadius()) }
    void resetBorderBottomLeftRadius() { SET_VAR(surround, border.m_bottomLeft, initialBorderRadius()) }
    void resetBorderBottomRightRadius() { SET_VAR(surround, border.m_bottomRight, initialBorderRadius()) }

    void setBackgroundColor(const Color& v) { SET_VAR(m_background, m_color, v) }

    void setBackgroundXPosition(Length l) { SET_VAR(m_background, m_background.m_xPosition, l) }
    void setBackgroundYPosition(Length l) { SET_VAR(m_background, m_background.m_yPosition, l) }
    void setBackgroundSize(EFillSizeType b) { SET_VAR(m_background, m_background.m_sizeType, b) }
    void setBackgroundSizeLength(LengthSize l) { SET_VAR(m_background, m_background.m_sizeLength, l) }
    
    void setBorderImage(const NinePieceImage& b) { SET_VAR(surround, border.m_image, b) }
    void setBorderImageSource(PassRefPtr<StyleImage> v) { surround.access()->border.m_image.setImage(v); }

    void setBorderTopLeftRadius(LengthSize s) { SET_VAR(surround, border.m_topLeft, s) }
    void setBorderTopRightRadius(LengthSize s) { SET_VAR(surround, border.m_topRight, s) }
    void setBorderBottomLeftRadius(LengthSize s) { SET_VAR(surround, border.m_bottomLeft, s) }
    void setBorderBottomRightRadius(LengthSize s) { SET_VAR(surround, border.m_bottomRight, s) }

    void setBorderRadius(LengthSize s)
    {
        setBorderTopLeftRadius(s);
        setBorderTopRightRadius(s);
        setBorderBottomLeftRadius(s);
        setBorderBottomRightRadius(s);
    }
    void setBorderRadius(const IntSize& s)
    {
        setBorderRadius(LengthSize(Length(s.width(), Fixed), Length(s.height(), Fixed)));
    }
    
    RoundedRect getRoundedBorderFor(const LayoutRect& borderRect, bool includeLogicalLeftEdge = true, bool includeLogicalRightEdge = true) const;
    RoundedRect getRoundedInnerBorderFor(const LayoutRect& borderRect, bool includeLogicalLeftEdge = true, bool includeLogicalRightEdge = true) const;

    RoundedRect getRoundedInnerBorderFor(const LayoutRect& borderRect,
        LayoutUnit topWidth, LayoutUnit bottomWidth, LayoutUnit leftWidth, LayoutUnit rightWidth, bool includeLogicalLeftEdge, bool includeLogicalRightEdge) const;

    void setBorderLeftWidth(unsigned v) { SET_VAR(surround, border.m_left.m_width, v) }
    void setBorderLeftStyle(EBorderStyle v) { SET_VAR(surround, border.m_left.m_style, v) }
    void setBorderLeftColor(const Color& v) { SET_VAR(surround, border.m_left.m_color, v) }
    void setBorderRightWidth(unsigned v) { SET_VAR(surround, border.m_right.m_width, v) }
    void setBorderRightStyle(EBorderStyle v) { SET_VAR(surround, border.m_right.m_style, v) }
    void setBorderRightColor(const Color& v) { SET_VAR(surround, border.m_right.m_color, v) }
    void setBorderTopWidth(unsigned v) { SET_VAR(surround, border.m_top.m_width, v) }
    void setBorderTopStyle(EBorderStyle v) { SET_VAR(surround, border.m_top.m_style, v) }
    void setBorderTopColor(const Color& v) { SET_VAR(surround, border.m_top.m_color, v) }
    void setBorderBottomWidth(unsigned v) { SET_VAR(surround, border.m_bottom.m_width, v) }
    void setBorderBottomStyle(EBorderStyle v) { SET_VAR(surround, border.m_bottom.m_style, v) }
    void setBorderBottomColor(const Color& v) { SET_VAR(surround, border.m_bottom.m_color, v) }

    void setOutlineWidth(unsigned short v) { SET_VAR(m_background, m_outline.m_width, v) }
    void setOutlineStyleIsAuto(OutlineIsAuto isAuto) { SET_VAR(m_background, m_outline.m_isAuto, isAuto) }
    void setOutlineStyle(EBorderStyle v) { SET_VAR(m_background, m_outline.m_style, v) }
    void setOutlineColor(const Color& v) { SET_VAR(m_background, m_outline.m_color, v) }

    void setOverflowX(EOverflow v) { noninherited_flags._overflowX = v; }
    void setOverflowY(EOverflow v) { noninherited_flags._overflowY = v; }
    void setVisibility(EVisibility v) { inherited_flags._visibility = v; }
    void setVerticalAlign(EVerticalAlign v) { noninherited_flags._vertical_align = v; }
    void setVerticalAlignLength(Length length) { setVerticalAlign(LENGTH); SET_VAR(m_box, m_verticalAlign, length) }

    void setHasClip(bool b = true) { SET_VAR(visual, hasClip, b) }
    void setClipLeft(Length v) { SET_VAR(visual, clip.m_left, v) }
    void setClipRight(Length v) { SET_VAR(visual, clip.m_right, v) }
    void setClipTop(Length v) { SET_VAR(visual, clip.m_top, v) }
    void setClipBottom(Length v) { SET_VAR(visual, clip.m_bottom, v) }
    void setClip(Length top, Length right, Length bottom, Length left);
    void setClip(LengthBox box) { SET_VAR(visual, clip, box) }

    void setUnicodeBidi(EUnicodeBidi b) { noninherited_flags._unicodeBidi = b; }

    void setClear(EClear v) { noninherited_flags._clear = v; }
    void setTableLayout(ETableLayout v) { noninherited_flags._table_layout = v; }

    bool setFontDescription(const FontDescription& v)
    {
        if (inherited->font.fontDescription() != v) {
            inherited.access()->font = Font(v, inherited->font.letterSpacing(), inherited->font.wordSpacing());
            return true;
        }
        return false;
    }

    // Only used for blending font sizes when animating.
    void setBlendedFontSize(int);

    void setColor(const Color& v) { SET_VAR(inherited, color, v) }
    void setTextIndent(Length v) { SET_VAR(rareInheritedData, indent, v) }
    void setTextAlign(ETextAlign v) { inherited_flags._text_align = v; }
    void setTextTransform(ETextTransform v) { inherited_flags._text_transform = v; }
    void addToTextDecorationsInEffect(ETextDecoration v) { inherited_flags._text_decorations |= v; }
    void setTextDecorationsInEffect(ETextDecoration v) { inherited_flags._text_decorations = v; }
    void setTextDecoration(ETextDecoration v) { SET_VAR(visual, textDecoration, v); }
    void setDirection(TextDirection v) { inherited_flags._direction = v; }
    void setLineHeight(Length v) { SET_VAR(inherited, line_height, v) }
    bool setZoom(float);
    void setZoomWithoutReturnValue(float f) { setZoom(f); }
    bool setEffectiveZoom(float);
    void setImageRendering(EImageRendering v) { SET_VAR(rareInheritedData, m_imageRendering, v) }

    void setWhiteSpace(EWhiteSpace v) { inherited_flags._white_space = v; }

    void setWordSpacing(int v) { inherited.access()->font.setWordSpacing(v); }
    void setLetterSpacing(int v) { inherited.access()->font.setLetterSpacing(v); }

    void clearBackgroundLayers() { m_background.access()->m_background = FillLayer(BackgroundFillLayer); }
    void inheritBackgroundLayers(const FillLayer& parent) { m_background.access()->m_background = parent; }

    void adjustBackgroundLayers()
    {
        if (backgroundLayers()->next()) {
            accessBackgroundLayers()->cullEmptyLayers();
            accessBackgroundLayers()->fillUnsetProperties();
        }
    }

    void clearMaskLayers() { rareNonInheritedData.access()->m_mask = FillLayer(MaskFillLayer); }
    void inheritMaskLayers(const FillLayer& parent) { rareNonInheritedData.access()->m_mask = parent; }

    void adjustMaskLayers()
    {
        if (maskLayers()->next()) {
            accessMaskLayers()->cullEmptyLayers();
            accessMaskLayers()->fillUnsetProperties();
        }
    }

    void setMaskImage(PassRefPtr<StyleImage> v) { rareNonInheritedData.access()->m_mask.setImage(v); }

    void setMaskBoxImage(const NinePieceImage& b) { SET_VAR(rareNonInheritedData, m_maskBoxImage, b) }
    void setMaskBoxImageSource(PassRefPtr<StyleImage> v) { rareNonInheritedData.access()->m_maskBoxImage.setImage(v); }
    void setMaskXPosition(Length l) { SET_VAR(rareNonInheritedData, m_mask.m_xPosition, l) }
    void setMaskYPosition(Length l) { SET_VAR(rareNonInheritedData, m_mask.m_yPosition, l) }
    void setMaskSize(LengthSize l) { SET_VAR(rareNonInheritedData, m_mask.m_sizeLength, l) }

    void setBorderCollapse(EBorderCollapse collapse) { inherited_flags._border_collapse = collapse; }
    void setHorizontalBorderSpacing(short v) { SET_VAR(inherited, horizontal_border_spacing, v) }
    void setVerticalBorderSpacing(short v) { SET_VAR(inherited, vertical_border_spacing, v) }
    void setEmptyCells(EEmptyCell v) { inherited_flags._empty_cells = v; }
    void setCaptionSide(ECaptionSide v) { inherited_flags._caption_side = v; }

    void setHasAspectRatio(bool b) { SET_VAR(rareNonInheritedData, m_hasAspectRatio, b); }
    void setAspectRatioDenominator(float v) { SET_VAR(rareNonInheritedData, m_aspectRatioDenominator, v); }
    void setAspectRatioNumerator(float v) { SET_VAR(rareNonInheritedData, m_aspectRatioNumerator, v); }
    void setCounterIncrement(short v) { SET_VAR(rareNonInheritedData, m_counterIncrement, v) }
    void setCounterReset(short v) { SET_VAR(rareNonInheritedData, m_counterReset, v) }

    void setListStyleType(EListStyleType v) { inherited_flags._list_style_type = v; }
    void setListStyleImage(PassRefPtr<StyleImage> v) { if (inherited->list_style_image != v) inherited.access()->list_style_image = v; }
    void setListStylePosition(EListStylePosition v) { inherited_flags._list_style_position = v; }

    void resetMargin() { SET_VAR(surround, margin, LengthBox(Fixed)) }
    void setMarginTop(Length v) { SET_VAR(surround, margin.m_top, v) }
    void setMarginBottom(Length v) { SET_VAR(surround, margin.m_bottom, v) }
    void setMarginLeft(Length v) { SET_VAR(surround, margin.m_left, v) }
    void setMarginRight(Length v) { SET_VAR(surround, margin.m_right, v) }
    void setMarginStart(Length);
    void setMarginEnd(Length);

    void resetPadding() { SET_VAR(surround, padding, LengthBox(Auto)) }
    void setPaddingBox(const LengthBox& b) { SET_VAR(surround, padding, b) }
    void setPaddingTop(Length v) { SET_VAR(surround, padding.m_top, v) }
    void setPaddingBottom(Length v) { SET_VAR(surround, padding.m_bottom, v) }
    void setPaddingLeft(Length v) { SET_VAR(surround, padding.m_left, v) }
    void setPaddingRight(Length v) { SET_VAR(surround, padding.m_right, v) }

    void setCursor(ECursor c) { inherited_flags._cursor_style = c; }
    void addCursor(PassRefPtr<StyleImage>, const IntPoint& hotSpot = IntPoint());
    void setCursorList(PassRefPtr<CursorList>);
    void clearCursorList();

    void setInsideLink(EInsideLink insideLink) { inherited_flags._insideLink = insideLink; }
    void setIsLink(bool b) { noninherited_flags.setIsLink(b); }

    PrintColorAdjust printColorAdjust() const { return static_cast<PrintColorAdjust>(inherited_flags.m_printColorAdjust); }
    void setPrintColorAdjust(PrintColorAdjust value) { inherited_flags.m_printColorAdjust = value; }

    bool hasAutoZIndex() const { return m_box->hasAutoZIndex(); }
    void setHasAutoZIndex() { SET_VAR(m_box, m_hasAutoZIndex, true); SET_VAR(m_box, m_zIndex, 0) }
    int zIndex() const { return m_box->zIndex(); }
    void setZIndex(int v) { SET_VAR(m_box, m_hasAutoZIndex, false); SET_VAR(m_box, m_zIndex, v) }

    void setWidows(short w) { SET_VAR(rareInheritedData, widows, w); }
    void setOrphans(short o) { SET_VAR(rareInheritedData, orphans, o); }
    // For valid values of page-break-inside see http://www.w3.org/TR/CSS21/page.html#page-break-props
    void setPageBreakInside(EPageBreak b) { ASSERT(b == PBAUTO || b == PBAVOID); noninherited_flags._page_break_inside = b; }
    void setPageBreakBefore(EPageBreak b) { noninherited_flags._page_break_before = b; }
    void setPageBreakAfter(EPageBreak b) { noninherited_flags._page_break_after = b; }

    // CSS3 Setters
    void setOutlineOffset(int v) { SET_VAR(m_background, m_outline.m_offset, v) }
    void setTextShadow(PassOwnPtr<ShadowData>, bool add = false);
    void setTextStrokeColor(const Color& c) { SET_VAR(rareInheritedData, textStrokeColor, c) }
    void setTextStrokeWidth(float w) { SET_VAR(rareInheritedData, textStrokeWidth, w) }
    void setTextFillColor(const Color& c) { SET_VAR(rareInheritedData, textFillColor, c) }
    void setColorSpace(ColorSpace space) { SET_VAR(rareInheritedData, colorSpace, space) }
    void setOpacity(float f) { SET_VAR(rareNonInheritedData, opacity, f); }
    void setAppearance(ControlPart a) { SET_VAR(rareNonInheritedData, m_appearance, a); }
    // For valid values of box-align see http://www.w3.org/TR/2009/WD-css3-flexbox-20090723/#alignment
    void setBoxAlign(EBoxAlignment a) { SET_VAR(rareNonInheritedData.access()->m_deprecatedFlexibleBox, align, a); }
    void setBoxDirection(EBoxDirection d) { inherited_flags._box_direction = d; }
    void setBoxFlex(float f) { SET_VAR(rareNonInheritedData.access()->m_deprecatedFlexibleBox, flex, f); }
    void setBoxFlexGroup(unsigned int fg) { SET_VAR(rareNonInheritedData.access()->m_deprecatedFlexibleBox, flex_group, fg); }
    void setBoxLines(EBoxLines l) { SET_VAR(rareNonInheritedData.access()->m_deprecatedFlexibleBox, lines, l); }
    void setBoxOrdinalGroup(unsigned int og) { SET_VAR(rareNonInheritedData.access()->m_deprecatedFlexibleBox, ordinal_group, og); }
    void setBoxOrient(EBoxOrient o) { SET_VAR(rareNonInheritedData.access()->m_deprecatedFlexibleBox, orient, o); }
    void setBoxPack(EBoxPack p) { SET_VAR(rareNonInheritedData.access()->m_deprecatedFlexibleBox, pack, p); }
    void setBoxShadow(PassOwnPtr<ShadowData>, bool add = false);
    void setBoxReflect(PassRefPtr<StyleReflection> reflect) { if (rareNonInheritedData->m_boxReflect != reflect) rareNonInheritedData.access()->m_boxReflect = reflect; }
    void setBoxSizing(EBoxSizing s) { SET_VAR(m_box, m_boxSizing, s); }
    void setFlexboxWidthPositiveFlex(float f) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_widthPositiveFlex, f); }
    void setFlexboxWidthNegativeFlex(float f) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_widthNegativeFlex, f); }
    void setFlexboxHeightPositiveFlex(float f) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_heightPositiveFlex, f); }
    void setFlexboxHeightNegativeFlex(float f) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_heightNegativeFlex, f); }
    void setFlexOrder(int o) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_flexOrder, o); }
    void setFlexPack(EFlexPack p) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_flexPack, p); }
    void setFlexAlign(EFlexAlign a) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_flexAlign, a); }
    void setFlexItemAlign(EFlexAlign a) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_flexItemAlign, a); }
    void setFlexDirection(EFlexDirection direction) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_flexDirection, direction); }
    void setFlexWrap(EFlexWrap w) { SET_VAR(rareNonInheritedData.access()->m_flexibleBox, m_flexWrap, w); }
#if ENABLE(CSS_GRID_LAYOUT)
    void setGridColumns(const Vector<Length>& lengths) { SET_VAR(rareNonInheritedData.access()->m_grid, m_gridColumns, lengths); }
    void setGridRows(const Vector<Length>& lengths) { SET_VAR(rareNonInheritedData.access()->m_grid, m_gridRows, lengths); }
#endif

    void setMarqueeIncrement(const Length& f) { SET_VAR(rareNonInheritedData.access()->m_marquee, increment, f); }
    void setMarqueeSpeed(int f) { SET_VAR(rareNonInheritedData.access()->m_marquee, speed, f); }
    void setMarqueeDirection(EMarqueeDirection d) { SET_VAR(rareNonInheritedData.access()->m_marquee, direction, d); }
    void setMarqueeBehavior(EMarqueeBehavior b) { SET_VAR(rareNonInheritedData.access()->m_marquee, behavior, b); }
    void setMarqueeLoopCount(int i) { SET_VAR(rareNonInheritedData.access()->m_marquee, loops, i); }
    void setUserModify(EUserModify u) { SET_VAR(rareInheritedData, userModify, u); }
    void setUserDrag(EUserDrag d) { SET_VAR(rareNonInheritedData, userDrag, d); }
    void setUserSelect(EUserSelect s) { SET_VAR(rareInheritedData, userSelect, s); }
    void setTextOverflow(TextOverflow overflow) { SET_VAR(rareNonInheritedData, textOverflow, overflow); }
    void setMarginBeforeCollapse(EMarginCollapse c) { SET_VAR(rareNonInheritedData, marginBeforeCollapse, c); }
    void setMarginAfterCollapse(EMarginCollapse c) { SET_VAR(rareNonInheritedData, marginAfterCollapse, c); }
    void setWordBreak(EWordBreak b) { SET_VAR(rareInheritedData, wordBreak, b); }
    void setWordWrap(EWordWrap b) { SET_VAR(rareInheritedData, wordWrap, b); }
    void setNBSPMode(ENBSPMode b) { SET_VAR(rareInheritedData, nbspMode, b); }
    void setKHTMLLineBreak(EKHTMLLineBreak b) { SET_VAR(rareInheritedData, khtmlLineBreak, b); }
    void setMatchNearestMailBlockquoteColor(EMatchNearestMailBlockquoteColor c) { SET_VAR(rareNonInheritedData, matchNearestMailBlockquoteColor, c); }
    void setHighlight(const AtomicString& h) { SET_VAR(rareInheritedData, highlight, h); }
    void setHyphens(Hyphens h) { SET_VAR(rareInheritedData, hyphens, h); }
    void setHyphenationLimitBefore(short limit) { SET_VAR(rareInheritedData, hyphenationLimitBefore, limit); }
    void setHyphenationLimitAfter(short limit) { SET_VAR(rareInheritedData, hyphenationLimitAfter, limit); }
    void setHyphenationLimitLines(short limit) { SET_VAR(rareInheritedData, hyphenationLimitLines, limit); }
    void setHyphenationString(const AtomicString& h) { SET_VAR(rareInheritedData, hyphenationString, h); }
    void setLocale(const AtomicString& locale) { SET_VAR(rareInheritedData, locale, locale); }
    void setBorderFit(EBorderFit b) { SET_VAR(rareNonInheritedData, m_borderFit, b); }
    void setResize(EResize r) { SET_VAR(rareInheritedData, resize, r); }
    void setColumnAxis(ColumnAxis axis) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_axis, axis); }
    void setColumnWidth(float f) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_autoWidth, false); SET_VAR(rareNonInheritedData.access()->m_multiCol, m_width, f); }
    void setHasAutoColumnWidth() { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_autoWidth, true); SET_VAR(rareNonInheritedData.access()->m_multiCol, m_width, 0); }
    void setColumnCount(unsigned short c) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_autoCount, false); SET_VAR(rareNonInheritedData.access()->m_multiCol, m_count, c); }
    void setHasAutoColumnCount() { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_autoCount, true); SET_VAR(rareNonInheritedData.access()->m_multiCol, m_count, 0); }
    void setColumnGap(float f) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_normalGap, false); SET_VAR(rareNonInheritedData.access()->m_multiCol, m_gap, f); }
    void setHasNormalColumnGap() { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_normalGap, true); SET_VAR(rareNonInheritedData.access()->m_multiCol, m_gap, 0); }
    void setColumnRuleColor(const Color& c) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_rule.m_color, c); }
    void setColumnRuleStyle(EBorderStyle b) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_rule.m_style, b); }
    void setColumnRuleWidth(unsigned short w) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_rule.m_width, w); }
    void resetColumnRule() { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_rule, BorderValue()) }
    void setColumnSpan(ColumnSpan columnSpan) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_columnSpan, columnSpan); }
    void setColumnBreakBefore(EPageBreak p) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_breakBefore, p); }
    // For valid values of column-break-inside see http://www.w3.org/TR/css3-multicol/#break-before-break-after-break-inside
    void setColumnBreakInside(EPageBreak p) { ASSERT(p == PBAUTO || p == PBAVOID); SET_VAR(rareNonInheritedData.access()->m_multiCol, m_breakInside, p); }
    void setColumnBreakAfter(EPageBreak p) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_breakAfter, p); }
    void setRegionBreakBefore(EPageBreak p) { SET_VAR(rareNonInheritedData, m_regionBreakBefore, p); }
    void setRegionBreakInside(EPageBreak p) { ASSERT(p == PBAUTO || p == PBAVOID); SET_VAR(rareNonInheritedData, m_regionBreakInside, p); }
    void setRegionBreakAfter(EPageBreak p) { SET_VAR(rareNonInheritedData, m_regionBreakAfter, p); }
    void inheritColumnPropertiesFrom(RenderStyle* parent) { rareNonInheritedData.access()->m_multiCol = parent->rareNonInheritedData->m_multiCol; }
    void setTransform(const TransformOperations& ops) { SET_VAR(rareNonInheritedData.access()->m_transform, m_operations, ops); }
    void setTransformOriginX(Length l) { SET_VAR(rareNonInheritedData.access()->m_transform, m_x, l); }
    void setTransformOriginY(Length l) { SET_VAR(rareNonInheritedData.access()->m_transform, m_y, l); }
    void setTransformOriginZ(float f) { SET_VAR(rareNonInheritedData.access()->m_transform, m_z, f); }
    void setSpeak(ESpeak s) { SET_VAR(rareInheritedData, speak, s); }
    void setTextCombine(TextCombine v) { SET_VAR(rareNonInheritedData, m_textCombine, v); }
    void setTextEmphasisColor(const Color& c) { SET_VAR(rareInheritedData, textEmphasisColor, c) }
    void setTextEmphasisFill(TextEmphasisFill fill) { SET_VAR(rareInheritedData, textEmphasisFill, fill); }
    void setTextEmphasisMark(TextEmphasisMark mark) { SET_VAR(rareInheritedData, textEmphasisMark, mark); }
    void setTextEmphasisCustomMark(const AtomicString& mark) { SET_VAR(rareInheritedData, textEmphasisCustomMark, mark); }
    void setTextEmphasisPosition(TextEmphasisPosition position) { SET_VAR(rareInheritedData, textEmphasisPosition, position); }

#if ENABLE(CSS_FILTERS)
    void setFilter(const FilterOperations& ops) { SET_VAR(rareNonInheritedData.access()->m_filter, m_operations, ops); }
#endif

    // End CSS3 Setters

    void setLineGrid(const AtomicString& lineGrid) { SET_VAR(rareInheritedData, m_lineGrid, lineGrid); }
    void setLineGridSnap(LineGridSnap lineGridSnap) { SET_VAR(rareInheritedData, m_lineGridSnap, lineGridSnap); }

    void setFlowThread(const AtomicString& flowThread) { SET_VAR(rareNonInheritedData, m_flowThread, flowThread); }
    void setRegionThread(const AtomicString& regionThread) { SET_VAR(rareNonInheritedData, m_regionThread, regionThread); }
    void setRegionOverflow(RegionOverflow regionOverflow) { SET_VAR(rareNonInheritedData, m_regionOverflow, regionOverflow); }

    void setWrapFlow(WrapFlow wrapFlow) { SET_VAR(rareNonInheritedData, m_wrapFlow, wrapFlow); }
    void setWrapThrough(WrapThrough wrapThrough) { SET_VAR(rareNonInheritedData, m_wrapThrough, wrapThrough); }

    // Apple-specific property setters
    void setPointerEvents(EPointerEvents p) { inherited_flags._pointerEvents = p; }

    void clearAnimations()
    {
        rareNonInheritedData.access()->m_animations.clear();
    }

    void clearTransitions()
    {
        rareNonInheritedData.access()->m_transitions.clear();
    }

    void inheritAnimations(const AnimationList* parent) { rareNonInheritedData.access()->m_animations = parent ? adoptPtr(new AnimationList(*parent)) : nullptr; }
    void inheritTransitions(const AnimationList* parent) { rareNonInheritedData.access()->m_transitions = parent ? adoptPtr(new AnimationList(*parent)) : nullptr; }
    void adjustAnimations();
    void adjustTransitions();

    void setTransformStyle3D(ETransformStyle3D b) { SET_VAR(rareNonInheritedData, m_transformStyle3D, b); }
    void setBackfaceVisibility(EBackfaceVisibility b) { SET_VAR(rareNonInheritedData, m_backfaceVisibility, b); }
    void setPerspective(float p) { SET_VAR(rareNonInheritedData, m_perspective, p); }
    void setPerspectiveOriginX(Length l) { SET_VAR(rareNonInheritedData, m_perspectiveOriginX, l); }
    void setPerspectiveOriginY(Length l) { SET_VAR(rareNonInheritedData, m_perspectiveOriginY, l); }
    void setPageSize(LengthSize s) { SET_VAR(rareNonInheritedData, m_pageSize, s); }
    void setPageSizeType(PageSizeType t) { SET_VAR(rareNonInheritedData, m_pageSizeType, t); }
    void resetPageSizeType() { SET_VAR(rareNonInheritedData, m_pageSizeType, PAGE_SIZE_AUTO); }

#if USE(ACCELERATED_COMPOSITING)
    void setIsRunningAcceleratedAnimation(bool b = true) { SET_VAR(rareNonInheritedData, m_runningAcceleratedAnimation, b); }
#endif

    void setLineBoxContain(LineBoxContain c) { SET_VAR(rareInheritedData, m_lineBoxContain, c); }
    void setLineClamp(LineClampValue c) { SET_VAR(rareNonInheritedData, lineClamp, c); }
#if ENABLE(TOUCH_EVENTS)
    void setTapHighlightColor(const Color& c) { SET_VAR(rareInheritedData, tapHighlightColor, c); }
#endif
    bool setTextSizeAdjust(bool);
    void setTextSecurity(ETextSecurity aTextSecurity) { SET_VAR(rareInheritedData, textSecurity, aTextSecurity); }

#if ENABLE(SVG)
    const SVGRenderStyle* svgStyle() const { return m_svgStyle.get(); }
    SVGRenderStyle* accessSVGStyle() { return m_svgStyle.access(); }

    const SVGPaint::SVGPaintType& fillPaintType() const { return svgStyle()->fillPaintType(); }
    const Color& fillPaintColor() const { return svgStyle()->fillPaintColor(); }
    void setFillPaintColor(const Color& c) { accessSVGStyle()->setFillPaint(SVGPaint::SVG_PAINTTYPE_RGBCOLOR, c, ""); }
    float fillOpacity() const { return svgStyle()->fillOpacity(); }
    void setFillOpacity(float f) { accessSVGStyle()->setFillOpacity(f); }

    const SVGPaint::SVGPaintType& strokePaintType() const { return svgStyle()->strokePaintType(); }
    const Color& strokePaintColor() const { return svgStyle()->strokePaintColor(); }
    void setStrokePaintColor(const Color& c) { accessSVGStyle()->setStrokePaint(SVGPaint::SVG_PAINTTYPE_RGBCOLOR, c, ""); }
    float strokeOpacity() const { return svgStyle()->strokeOpacity(); }
    void setStrokeOpacity(float f) { accessSVGStyle()->setStrokeOpacity(f); }
    SVGLength strokeWidth() const { return svgStyle()->strokeWidth(); }
    void setStrokeWidth(SVGLength w) { accessSVGStyle()->setStrokeWidth(w); }
    SVGLength strokeDashOffset() const { return svgStyle()->strokeDashOffset(); }
    void setStrokeDashOffset(SVGLength d) { accessSVGStyle()->setStrokeDashOffset(d); }
    float strokeMiterLimit() const { return svgStyle()->strokeMiterLimit(); }
    void setStrokeMiterLimit(float f) { accessSVGStyle()->setStrokeMiterLimit(f); }

    float floodOpacity() const { return svgStyle()->floodOpacity(); }
    void setFloodOpacity(float f) { accessSVGStyle()->setFloodOpacity(f); }

    float stopOpacity() const { return svgStyle()->stopOpacity(); }
    void setStopOpacity(float f) { accessSVGStyle()->setStopOpacity(f); }

    void setStopColor(const Color& c) { accessSVGStyle()->setStopColor(c); }
    void setFloodColor(const Color& c) { accessSVGStyle()->setFloodColor(c); }
    void setLightingColor(const Color& c) { accessSVGStyle()->setLightingColor(c); }

    SVGLength baselineShiftValue() const { return svgStyle()->baselineShiftValue(); }
    void setBaselineShiftValue(SVGLength s) { accessSVGStyle()->setBaselineShiftValue(s); }
    SVGLength kerning() const { return svgStyle()->kerning(); }
    void setKerning(SVGLength k) { accessSVGStyle()->setKerning(k); }
#endif

    void setWrapShapeInside(PassRefPtr<CSSWrapShape> shape)
    {
        if (rareNonInheritedData->m_wrapShapeInside != shape)
            rareNonInheritedData.access()->m_wrapShapeInside = shape;
    }
    CSSWrapShape* wrapShapeInside() const { return rareNonInheritedData->m_wrapShapeInside.get(); }

    void setWrapShapeOutside(PassRefPtr<CSSWrapShape> shape)
    {
        if (rareNonInheritedData->m_wrapShapeOutside != shape)
            rareNonInheritedData.access()->m_wrapShapeOutside = shape;
    }
    CSSWrapShape* wrapShapeOutside() const { return rareNonInheritedData->m_wrapShapeOutside.get(); }

    static CSSWrapShape* initialWrapShapeInside() { return 0; }
    static CSSWrapShape* initialWrapShapeOutside() { return 0; }

    Length wrapPadding() const { return rareNonInheritedData->m_wrapPadding; }
    void setWrapPadding(Length wrapPadding) { SET_VAR(rareNonInheritedData, m_wrapPadding, wrapPadding); }
    static Length initialWrapPadding() { return Length(0, Fixed); }

    Length wrapMargin() const { return rareNonInheritedData->m_wrapMargin; }
    void setWrapMargin(Length wrapMargin) { SET_VAR(rareNonInheritedData, m_wrapMargin, wrapMargin); }
    static Length initialWrapMargin() { return Length(0, Fixed); }

    bool hasContent() const { return contentData(); }
    const ContentData* contentData() const { return rareNonInheritedData->m_content.get(); }
    bool contentDataEquivalent(const RenderStyle* otherStyle) const { return const_cast<RenderStyle*>(this)->rareNonInheritedData->contentDataEquivalent(*const_cast<RenderStyle*>(otherStyle)->rareNonInheritedData); }
    void clearContent();
    void setContent(const String&, bool add = false);
    void setContent(PassRefPtr<StyleImage>, bool add = false);
    void setContent(PassOwnPtr<CounterContent>, bool add = false);
    void setContent(QuoteType, bool add = false);

    const CounterDirectiveMap* counterDirectives() const;
    CounterDirectiveMap& accessCounterDirectives();

    QuotesData* quotes() const { return rareInheritedData->quotes.get(); }
    void setQuotes(PassRefPtr<QuotesData>);

    const AtomicString& hyphenString() const;

    bool inheritedNotEqual(const RenderStyle*) const;
    bool inheritedDataShared(const RenderStyle*) const;

    StyleDifference diff(const RenderStyle*, unsigned& changedContextSensitiveProperties) const;

    bool isDisplayReplacedType() const
    {
        return display() == INLINE_BLOCK || display() == INLINE_BOX || display() == INLINE_TABLE;
    }

    bool isDisplayInlineType() const
    {
        return display() == INLINE || isDisplayReplacedType();
    }

    bool isOriginalDisplayInlineType() const
    {
        return originalDisplay() == INLINE || originalDisplay() == INLINE_BLOCK
            || originalDisplay() == INLINE_BOX || originalDisplay() == INLINE_TABLE;
    }

    void setWritingMode(WritingMode v) { inherited_flags.m_writingMode = v; }

    // To tell if this style matched attribute selectors. This makes it impossible to share.
    bool affectedByUncommonAttributeSelectors() const { return m_bitfields.affectedByUncommonAttributeSelectors(); }
    void setAffectedByUncommonAttributeSelectors() { m_bitfields.setAffectedByUncommonAttributeSelectors(true); }

    bool unique() const { return m_bitfields.unique(); }
    void setUnique() { m_bitfields.setUnique(true); }

    // Methods for indicating the style is affected by dynamic updates (e.g., children changing, our position changing in our sibling list, etc.)
    bool affectedByEmpty() const { return m_bitfields.affectedByEmpty(); }
    bool emptyState() const { return m_bitfields.emptyState(); }
    void setEmptyState(bool b) { m_bitfields.setAffectedByEmpty(true); m_bitfields.setUnique(true); m_bitfields.setEmptyState(b); }
    bool childrenAffectedByPositionalRules() const { return childrenAffectedByForwardPositionalRules() || childrenAffectedByBackwardPositionalRules(); }
    bool childrenAffectedByFirstChildRules() const { return m_bitfields.childrenAffectedByFirstChildRules(); }
    void setChildrenAffectedByFirstChildRules() { m_bitfields.setChildrenAffectedByFirstChildRules(true); }
    bool childrenAffectedByLastChildRules() const { return m_bitfields.childrenAffectedByLastChildRules(); }
    void setChildrenAffectedByLastChildRules() { m_bitfields.setChildrenAffectedByLastChildRules(true); }
    bool childrenAffectedByDirectAdjacentRules() const { return m_bitfields.childrenAffectedByDirectAdjacentRules(); }
    void setChildrenAffectedByDirectAdjacentRules() { m_bitfields.setChildrenAffectedByDirectAdjacentRules(true); }
    bool childrenAffectedByForwardPositionalRules() const { return m_bitfields.childrenAffectedByForwardPositionalRules(); }
    void setChildrenAffectedByForwardPositionalRules() { m_bitfields.setChildrenAffectedByForwardPositionalRules(true); }
    bool childrenAffectedByBackwardPositionalRules() const { return m_bitfields.childrenAffectedByBackwardPositionalRules(); }
    void setChildrenAffectedByBackwardPositionalRules() { m_bitfields.setChildrenAffectedByBackwardPositionalRules(true); }
    bool firstChildState() const { return m_bitfields.firstChildState(); }
    void setFirstChildState() { m_bitfields.setUnique(true); m_bitfields.setFirstChildState(true); }
    bool lastChildState() const { return m_bitfields.lastChildState(); }
    void setLastChildState() { m_bitfields.setUnique(true); m_bitfields.setLastChildState(true); }
    unsigned childIndex() const { return m_bitfields.childIndex(); }
    void setChildIndex(unsigned index) { m_bitfields.setUnique(true); m_bitfields.setChildIndex(index); }

    Color visitedDependentColor(int colorProperty) const;

    void setHasExplicitlyInheritedProperties() { m_bitfields.setExplicitInheritance(true); }
    bool hasExplicitlyInheritedProperties() const { return m_bitfields.explicitInheritance(); }
    
    // Initial values for all the properties
    static EBorderCollapse initialBorderCollapse() { return BSEPARATE; }
    static EBorderStyle initialBorderStyle() { return BNONE; }
    static OutlineIsAuto initialOutlineStyleIsAuto() { return AUTO_OFF; }
    static NinePieceImage initialNinePieceImage() { return NinePieceImage(); }
    static LengthSize initialBorderRadius() { return LengthSize(Length(0, Fixed), Length(0, Fixed)); }
    static ECaptionSide initialCaptionSide() { return CAPTOP; }
    static EClear initialClear() { return CNONE; }
    static ColorSpace initialColorSpace() { return ColorSpaceDeviceRGB; }
    static ColumnAxis initialColumnAxis() { return AutoColumnAxis; }
    static TextDirection initialDirection() { return LTR; }
    static WritingMode initialWritingMode() { return TopToBottomWritingMode; }
    static TextCombine initialTextCombine() { return TextCombineNone; }
    static TextOrientation initialTextOrientation() { return TextOrientationVerticalRight; }
    static EDisplay initialDisplay() { return INLINE; }
    static EEmptyCell initialEmptyCells() { return SHOW; }
    static EFloat initialFloating() { return NoFloat; }
    static EListStylePosition initialListStylePosition() { return OUTSIDE; }
    static EListStyleType initialListStyleType() { return Disc; }
    static EOverflow initialOverflowX() { return OVISIBLE; }
    static EOverflow initialOverflowY() { return OVISIBLE; }
    static EPageBreak initialPageBreak() { return PBAUTO; }
    static EPosition initialPosition() { return StaticPosition; }
    static ETableLayout initialTableLayout() { return TAUTO; }
    static EUnicodeBidi initialUnicodeBidi() { return UBNormal; }
    static ETextTransform initialTextTransform() { return TTNONE; }
    static EVisibility initialVisibility() { return VISIBLE; }
    static EWhiteSpace initialWhiteSpace() { return NORMAL; }
    static short initialHorizontalBorderSpacing() { return 0; }
    static short initialVerticalBorderSpacing() { return 0; }
    static ECursor initialCursor() { return CURSOR_AUTO; }
    static Color initialColor() { return Color::black; }
    static StyleImage* initialListStyleImage() { return 0; }
    static unsigned initialBorderWidth() { return 3; }
    static unsigned short initialColumnRuleWidth() { return 3; }
    static unsigned short initialOutlineWidth() { return 3; }
    static int initialLetterWordSpacing() { return 0; }
    static Length initialSize() { return Length(); }
    static Length initialMinSize() { return Length(0, Fixed); }
    static Length initialMaxSize() { return Length(Undefined); }
    static Length initialOffset() { return Length(); }
    static Length initialMargin() { return Length(Fixed); }
    static Length initialPadding() { return Length(Fixed); }
    static Length initialTextIndent() { return Length(Fixed); }
    static EVerticalAlign initialVerticalAlign() { return BASELINE; }
    static int initialWidows() { return 2; }
    static int initialOrphans() { return 2; }
    static Length initialLineHeight() { return Length(-100.0, Percent); }
    static ETextAlign initialTextAlign() { return TAAUTO; }
    static ETextDecoration initialTextDecoration() { return TDNONE; }
    static float initialZoom() { return 1.0f; }
    static int initialOutlineOffset() { return 0; }
    static float initialOpacity() { return 1.0f; }
    static EBoxAlignment initialBoxAlign() { return BSTRETCH; }
    static EBoxDirection initialBoxDirection() { return BNORMAL; }
    static EBoxLines initialBoxLines() { return SINGLE; }
    static EBoxOrient initialBoxOrient() { return HORIZONTAL; }
    static EBoxPack initialBoxPack() { return Start; }
    static float initialBoxFlex() { return 0.0f; }
    static int initialBoxFlexGroup() { return 1; }
    static int initialBoxOrdinalGroup() { return 1; }
    static EBoxSizing initialBoxSizing() { return CONTENT_BOX; }
    static StyleReflection* initialBoxReflect() { return 0; }
    static float initialFlexboxWidthPositiveFlex() { return 0; }
    static float initialFlexboxWidthNegativeFlex() { return 0; }
    static float initialFlexboxHeightPositiveFlex() { return 0; }
    static float initialFlexboxHeightNegativeFlex() { return 0; }
    static int initialFlexOrder() { return 0; }
    static EFlexPack initialFlexPack() { return PackStart; }
    static EFlexAlign initialFlexAlign() { return AlignStretch; }
    static EFlexAlign initialFlexItemAlign() { return AlignAuto; }
    static EFlexDirection initialFlexDirection() { return FlowRow; }
    static EFlexWrap initialFlexWrap() { return FlexNoWrap; }
    static int initialMarqueeLoopCount() { return -1; }
    static int initialMarqueeSpeed() { return 85; }
    static Length initialMarqueeIncrement() { return Length(6, Fixed); }
    static EMarqueeBehavior initialMarqueeBehavior() { return MSCROLL; }
    static EMarqueeDirection initialMarqueeDirection() { return MAUTO; }
    static EUserModify initialUserModify() { return READ_ONLY; }
    static EUserDrag initialUserDrag() { return DRAG_AUTO; }
    static EUserSelect initialUserSelect() { return SELECT_TEXT; }
    static TextOverflow initialTextOverflow() { return TextOverflowClip; }
    static EMarginCollapse initialMarginBeforeCollapse() { return MCOLLAPSE; }
    static EMarginCollapse initialMarginAfterCollapse() { return MCOLLAPSE; }
    static EWordBreak initialWordBreak() { return NormalWordBreak; }
    static EWordWrap initialWordWrap() { return NormalWordWrap; }
    static ENBSPMode initialNBSPMode() { return NBNORMAL; }
    static EKHTMLLineBreak initialKHTMLLineBreak() { return LBNORMAL; }
    static EMatchNearestMailBlockquoteColor initialMatchNearestMailBlockquoteColor() { return BCNORMAL; }
    static const AtomicString& initialHighlight() { return nullAtom; }
    static ESpeak initialSpeak() { return SpeakNormal; }
    static Hyphens initialHyphens() { return HyphensManual; }
    static short initialHyphenationLimitBefore() { return -1; }
    static short initialHyphenationLimitAfter() { return -1; }
    static short initialHyphenationLimitLines() { return -1; }
    static const AtomicString& initialHyphenationString() { return nullAtom; }
    static const AtomicString& initialLocale() { return nullAtom; }
    static EBorderFit initialBorderFit() { return BorderFitBorder; }
    static EResize initialResize() { return RESIZE_NONE; }
    static ControlPart initialAppearance() { return NoControlPart; }
    static bool initialHasAspectRatio() { return false; }
    static float initialAspectRatioDenominator() { return 1; }
    static float initialAspectRatioNumerator() { return 1; }
    static Order initialRTLOrdering() { return LogicalOrder; }
    static float initialTextStrokeWidth() { return 0; }
    static unsigned short initialColumnCount() { return 1; }
    static ColumnSpan initialColumnSpan() { return ColumnSpanOne; }
    static const TransformOperations& initialTransform() { DEFINE_STATIC_LOCAL(TransformOperations, ops, ()); return ops; }
    static Length initialTransformOriginX() { return Length(50.0, Percent); }
    static Length initialTransformOriginY() { return Length(50.0, Percent); }
    static EPointerEvents initialPointerEvents() { return PE_AUTO; }
    static float initialTransformOriginZ() { return 0; }
    static ETransformStyle3D initialTransformStyle3D() { return TransformStyle3DFlat; }
    static EBackfaceVisibility initialBackfaceVisibility() { return BackfaceVisibilityVisible; }
    static float initialPerspective() { return 0; }
    static Length initialPerspectiveOriginX() { return Length(50.0, Percent); }
    static Length initialPerspectiveOriginY() { return Length(50.0, Percent); }
    static Color initialBackgroundColor() { return Color::transparent; }
    static Color initialTextEmphasisColor() { return TextEmphasisFillFilled; }
    static TextEmphasisFill initialTextEmphasisFill() { return TextEmphasisFillFilled; }
    static TextEmphasisMark initialTextEmphasisMark() { return TextEmphasisMarkNone; }
    static const AtomicString& initialTextEmphasisCustomMark() { return nullAtom; }
    static TextEmphasisPosition initialTextEmphasisPosition() { return TextEmphasisPositionOver; }
    static LineBoxContain initialLineBoxContain() { return LineBoxContainBlock | LineBoxContainInline | LineBoxContainReplaced; }
    static EImageRendering initialImageRendering() { return ImageRenderingAuto; }
    static StyleImage* initialBorderImageSource() { return 0; }
    static StyleImage* initialMaskBoxImageSource() { return 0; }
    static PrintColorAdjust initialPrintColorAdjust() { return PrintColorAdjustEconomy; }

#if ENABLE(CSS_GRID_LAYOUT)
    // The initial value is 'none' for grid tracks.
    static Vector<Length> initialGridTrackValue()
    {
        DEFINE_STATIC_LOCAL(Vector<Length>, defaultLength, ());
        // We need to manually add the Length here as the Length(0) is 'auto'.
        if (!defaultLength.size())
            defaultLength.append(Length(Undefined));
        return defaultLength;
    }
    static Vector<Length> initialGridColumns() { return initialGridTrackValue(); }
    static Vector<Length> initialGridRows() { return initialGridTrackValue(); }
#endif

    static const AtomicString& initialLineGrid() { return nullAtom; }
    static LineGridSnap initialLineGridSnap() { return LineGridSnapNone; }

    static const AtomicString& initialFlowThread() { return nullAtom; }
    static const AtomicString& initialRegionThread() { return nullAtom; }
    static RegionOverflow initialRegionOverflow() { return AutoRegionOverflow; }

    static WrapFlow initialWrapFlow() { return WrapFlowAuto; }
    static WrapThrough initialWrapThrough() { return WrapThroughWrap; }

    // Keep these at the end.
    static LineClampValue initialLineClamp() { return LineClampValue(); }
    static bool initialTextSizeAdjust() { return true; }
    static ETextSecurity initialTextSecurity() { return TSNONE; }
#if ENABLE(TOUCH_EVENTS)
    static Color initialTapHighlightColor();
#endif
#if ENABLE(DASHBOARD_SUPPORT)
    static const Vector<StyleDashboardRegion>& initialDashboardRegions();
    static const Vector<StyleDashboardRegion>& noneDashboardRegions();
#endif
#if ENABLE(CSS_FILTERS)
    static const FilterOperations& initialFilter() { DEFINE_STATIC_LOCAL(FilterOperations, ops, ()); return ops; }
#endif
private:
    void setVisitedLinkColor(const Color& v) { SET_VAR(inherited, visitedLinkColor, v) }
    void setVisitedLinkBackgroundColor(const Color& v) { SET_VAR(rareNonInheritedData, m_visitedLinkBackgroundColor, v) }
    void setVisitedLinkBorderLeftColor(const Color& v) { SET_VAR(rareNonInheritedData, m_visitedLinkBorderLeftColor, v) }
    void setVisitedLinkBorderRightColor(const Color& v) { SET_VAR(rareNonInheritedData, m_visitedLinkBorderRightColor, v) }
    void setVisitedLinkBorderBottomColor(const Color& v) { SET_VAR(rareNonInheritedData, m_visitedLinkBorderBottomColor, v) }
    void setVisitedLinkBorderTopColor(const Color& v) { SET_VAR(rareNonInheritedData, m_visitedLinkBorderTopColor, v) }
    void setVisitedLinkOutlineColor(const Color& v) { SET_VAR(rareNonInheritedData, m_visitedLinkOutlineColor, v) }
    void setVisitedLinkColumnRuleColor(const Color& v) { SET_VAR(rareNonInheritedData.access()->m_multiCol, m_visitedLinkColumnRuleColor, v) }
    void setVisitedLinkTextEmphasisColor(const Color& v) { SET_VAR(rareInheritedData, visitedLinkTextEmphasisColor, v) }
    void setVisitedLinkTextFillColor(const Color& v) { SET_VAR(rareInheritedData, visitedLinkTextFillColor, v) }
    void setVisitedLinkTextStrokeColor(const Color& v) { SET_VAR(rareInheritedData, visitedLinkTextStrokeColor, v) }

    void inheritUnicodeBidiFrom(const RenderStyle* parent) { noninherited_flags._unicodeBidi = parent->noninherited_flags._unicodeBidi; }
    void getShadowExtent(const ShadowData*, LayoutUnit& top, LayoutUnit& right, LayoutUnit& bottom, LayoutUnit& left) const;
    void getShadowHorizontalExtent(const ShadowData*, LayoutUnit& left, LayoutUnit& right) const;
    void getShadowVerticalExtent(const ShadowData*, LayoutUnit& top, LayoutUnit& bottom) const;
    void getShadowInlineDirectionExtent(const ShadowData* shadow, LayoutUnit& logicalLeft, LayoutUnit& logicalRight) const
    {
        return isHorizontalWritingMode() ? getShadowHorizontalExtent(shadow, logicalLeft, logicalRight) : getShadowVerticalExtent(shadow, logicalLeft, logicalRight);
    }
    void getShadowBlockDirectionExtent(const ShadowData* shadow, LayoutUnit& logicalTop, LayoutUnit& logicalBottom) const
    {
        return isHorizontalWritingMode() ? getShadowVerticalExtent(shadow, logicalTop, logicalBottom) : getShadowHorizontalExtent(shadow, logicalTop, logicalBottom);
    }

    // Helpers for obtaining border image outsets for overflow.
    void getImageHorizontalOutsets(const NinePieceImage&, LayoutUnit& left, LayoutUnit& right) const;
    void getImageVerticalOutsets(const NinePieceImage&, LayoutUnit& top, LayoutUnit& bottom) const;
    void getImageInlineDirectionOutsets(const NinePieceImage& image, LayoutUnit& logicalLeft, LayoutUnit& logicalRight) const
    {
        return isHorizontalWritingMode() ? getImageHorizontalOutsets(image, logicalLeft, logicalRight) : getImageVerticalOutsets(image, logicalLeft, logicalRight);
    }
    void getImageBlockDirectionOutsets(const NinePieceImage& image, LayoutUnit& logicalTop, LayoutUnit& logicalBottom) const
    {
        return isHorizontalWritingMode() ? getImageVerticalOutsets(image, logicalTop, logicalBottom) : getImageHorizontalOutsets(image, logicalTop, logicalBottom);
    }

    // Color accessors are all private to make sure callers use visitedDependentColor instead to access them.
    const Color& invalidColor() const { static Color invalid; return invalid; }
    const Color& borderLeftColor() const { return surround->border.left().color(); }
    const Color& borderRightColor() const { return surround->border.right().color(); }
    const Color& borderTopColor() const { return surround->border.top().color(); }
    const Color& borderBottomColor() const { return surround->border.bottom().color(); }
    const Color& backgroundColor() const { return m_background->color(); }
    const Color& color() const { return inherited->color; }
    const Color& columnRuleColor() const { return rareNonInheritedData->m_multiCol->m_rule.color(); }
    const Color& outlineColor() const { return m_background->outline().color(); }
    const Color& textEmphasisColor() const { return rareInheritedData->textEmphasisColor; }
    const Color& textFillColor() const { return rareInheritedData->textFillColor; }
    const Color& textStrokeColor() const { return rareInheritedData->textStrokeColor; }
    const Color& visitedLinkColor() const { return inherited->visitedLinkColor; }
    const Color& visitedLinkBackgroundColor() const { return rareNonInheritedData->m_visitedLinkBackgroundColor; }
    const Color& visitedLinkBorderLeftColor() const { return rareNonInheritedData->m_visitedLinkBorderLeftColor; }
    const Color& visitedLinkBorderRightColor() const { return rareNonInheritedData->m_visitedLinkBorderRightColor; }
    const Color& visitedLinkBorderBottomColor() const { return rareNonInheritedData->m_visitedLinkBorderBottomColor; }
    const Color& visitedLinkBorderTopColor() const { return rareNonInheritedData->m_visitedLinkBorderTopColor; }
    const Color& visitedLinkOutlineColor() const { return rareNonInheritedData->m_visitedLinkOutlineColor; }
    const Color& visitedLinkColumnRuleColor() const { return rareNonInheritedData->m_multiCol->m_visitedLinkColumnRuleColor; }
    const Color& visitedLinkTextEmphasisColor() const { return rareInheritedData->visitedLinkTextEmphasisColor; }
    const Color& visitedLinkTextFillColor() const { return rareInheritedData->visitedLinkTextFillColor; }
    const Color& visitedLinkTextStrokeColor() const { return rareInheritedData->visitedLinkTextStrokeColor; }

    Color colorIncludingFallback(int colorProperty, bool visitedLink) const;

#if ENABLE(SVG)
    const Color& stopColor() const { return svgStyle()->stopColor(); }
    const Color& floodColor() const { return svgStyle()->floodColor(); }
    const Color& lightingColor() const { return svgStyle()->lightingColor(); }
#endif

    void appendContent(PassOwnPtr<ContentData>);
};

inline int adjustForAbsoluteZoom(int value, const RenderStyle* style)
{
    double zoomFactor = style->effectiveZoom();
    if (zoomFactor == 1)
        return value;
    // Needed because computeLengthInt truncates (rather than rounds) when scaling up.
    if (zoomFactor > 1) {
        if (value < 0)
            value--;
        else 
            value++;
    }

    return roundForImpreciseConversion<int, INT_MAX, INT_MIN>(value / zoomFactor);
}

inline float adjustFloatForAbsoluteZoom(float value, const RenderStyle* style)
{
    return value / style->effectiveZoom();
}

inline bool RenderStyle::setZoom(float f)
{
    if (compareEqual(visual->m_zoom, f))
        return false;
    visual.access()->m_zoom = f;
    setEffectiveZoom(effectiveZoom() * zoom());
    return true;
}

inline bool RenderStyle::setEffectiveZoom(float f)
{
    if (compareEqual(rareInheritedData->m_effectiveZoom, f))
        return false;
    rareInheritedData.access()->m_effectiveZoom = f;
    return true;
}

inline bool RenderStyle::setTextSizeAdjust(bool b)
{
    if (compareEqual(rareInheritedData->textSizeAdjust, b))
        return false;
    rareInheritedData.access()->textSizeAdjust = b;
    return true;
}

} // namespace WebCore

#endif // RenderStyle_h
