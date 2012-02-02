/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
 *           (C) 2000 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Graham Dennis (graham.dennis@gmail.com)
 * Copyright (C) 2009 Torch Mobile Inc. All rights reserved. (http://www.torchmobile.com/)
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

#ifndef RenderStyleConstants_h
#define RenderStyleConstants_h

namespace WebCore {

/*
 * WARNING:
 * --------
 *
 * The order of the values in the enums have to agree with the order specified
 * in CSSValueKeywords.in, otherwise some optimizations in the parser will fail,
 * and produce invalid results.
 */
static const size_t PrintColorAdjustBits = 1;
enum PrintColorAdjust {
    PrintColorAdjustEconomy,
    PrintColorAdjustExact
};

// The difference between two styles.  The following values are used:
// (1) StyleDifferenceEqual - The two styles are identical
// (2) StyleDifferenceRecompositeLayer - The layer needs its position and transform updated, but no repaint
// (3) StyleDifferenceRepaint - The object just needs to be repainted.
// (4) StyleDifferenceRepaintLayer - The layer and its descendant layers needs to be repainted.
// (5) StyleDifferenceLayoutPositionedMovementOnly - Only the position of this positioned object has been updated
// (6) StyleDifferenceSimplifiedLayout - Only overflow needs to be recomputed
// (7) StyleDifferenceSimplifiedLayoutAndPositionedMovement - Both positioned movement and simplified layout updates are required.
// (8) StyleDifferenceLayout - A full layout is required.
enum StyleDifference {
    StyleDifferenceEqual,
#if USE(ACCELERATED_COMPOSITING)
    StyleDifferenceRecompositeLayer,
#endif
    StyleDifferenceRepaint,
    StyleDifferenceRepaintLayer,
    StyleDifferenceLayoutPositionedMovementOnly,
    StyleDifferenceSimplifiedLayout,
    StyleDifferenceSimplifiedLayoutAndPositionedMovement,
    StyleDifferenceLayout
};

// When some style properties change, different amounts of work have to be done depending on
// context (e.g. whether the property is changing on an element which has a compositing layer).
// A simple StyleDifference does not provide enough information so we return a bit mask of
// StyleDifferenceContextSensitiveProperties from RenderStyle::diff() too.
enum StyleDifferenceContextSensitiveProperty {
    ContextSensitivePropertyNone = 0,
    ContextSensitivePropertyTransform = (1 << 0),
    ContextSensitivePropertyOpacity = (1 << 1)
};

// Static pseudo styles. Dynamic ones are produced on the fly.
enum PseudoId {
    // The order must be NOP ID, public IDs, and then internal IDs.
    NOPSEUDO, FIRST_LINE, FIRST_LETTER, BEFORE, AFTER, SELECTION, FIRST_LINE_INHERITED, SCROLLBAR,
    // Internal IDs follow:
    SCROLLBAR_THUMB, SCROLLBAR_BUTTON, SCROLLBAR_TRACK, SCROLLBAR_TRACK_PIECE, SCROLLBAR_CORNER, RESIZER,
    INPUT_LIST_BUTTON,
    AFTER_LAST_INTERNAL_PSEUDOID,
    FULL_SCREEN, FULL_SCREEN_DOCUMENT, FULL_SCREEN_ANCESTOR, ANIMATING_FULL_SCREEN_TRANSITION,
    FIRST_PUBLIC_PSEUDOID = FIRST_LINE,
    FIRST_INTERNAL_PSEUDOID = SCROLLBAR_THUMB,
    PUBLIC_PSEUDOID_MASK = ((1 << FIRST_INTERNAL_PSEUDOID) - 1) & ~((1 << FIRST_PUBLIC_PSEUDOID) - 1)
};

enum ColumnSpan { ColumnSpanOne = 0, ColumnSpanAll};

enum EBorderCollapse { BSEPARATE = 0, BCOLLAPSE = 1 };

// These have been defined in the order of their precedence for border-collapsing. Do
// not change this order!
enum EBorderStyle { BNONE, BHIDDEN, INSET, GROOVE, OUTSET, RIDGE, DOTTED, DASHED, SOLID, DOUBLE };

enum EBorderPrecedence { BOFF, BTABLE, BCOLGROUP, BCOL, BROWGROUP, BROW, BCELL };

enum OutlineIsAuto { AUTO_OFF = 0, AUTO_ON };

enum EPosition {
    StaticPosition, RelativePosition, AbsolutePosition, FixedPosition
};

enum EFloat {
    NoFloat, LeftFloat, RightFloat, PositionedFloat
};

enum EMarginCollapse { MCOLLAPSE, MSEPARATE, MDISCARD };

// Box attributes. Not inherited.

enum EBoxSizing { CONTENT_BOX, BORDER_BOX };

// Random visual rendering model attributes. Not inherited.

enum EOverflow {
    OVISIBLE, OHIDDEN, OSCROLL, OAUTO, OOVERLAY, OMARQUEE
};

enum EVerticalAlign {
    BASELINE, MIDDLE, SUB, SUPER, TEXT_TOP,
    TEXT_BOTTOM, TOP, BOTTOM, BASELINE_MIDDLE, LENGTH
};

enum EClear {
    CNONE = 0, CLEFT = 1, CRIGHT = 2, CBOTH = 3
};

enum ETableLayout {
    TAUTO, TFIXED
};

// CSS Text Layout Module Level 3: Vertical writing support
enum WritingMode {
    TopToBottomWritingMode, RightToLeftWritingMode, LeftToRightWritingMode, BottomToTopWritingMode
};

enum TextCombine {
    TextCombineNone, TextCombineHorizontal
};

enum EFillAttachment {
    ScrollBackgroundAttachment, LocalBackgroundAttachment, FixedBackgroundAttachment
};

enum EFillBox {
    BorderFillBox, PaddingFillBox, ContentFillBox, TextFillBox
};

enum EFillRepeat {
    RepeatFill, NoRepeatFill, RoundFill, SpaceFill
};

enum EFillLayerType {
    BackgroundFillLayer, MaskFillLayer
};

// CSS3 Background Values
enum EFillSizeType { Contain, Cover, SizeLength, SizeNone };

// CSS3 Marquee Properties

enum EMarqueeBehavior { MNONE, MSCROLL, MSLIDE, MALTERNATE };
enum EMarqueeDirection { MAUTO = 0, MLEFT = 1, MRIGHT = -1, MUP = 2, MDOWN = -2, MFORWARD = 3, MBACKWARD = -3 };

// Deprecated Flexible Box Properties

enum EBoxPack { Start, Center, End, Justify };
enum EBoxAlignment { BSTRETCH, BSTART, BCENTER, BEND, BBASELINE };
enum EBoxOrient { HORIZONTAL, VERTICAL };
enum EBoxLines { SINGLE, MULTIPLE };
enum EBoxDirection { BNORMAL, BREVERSE };

// CSS3 Flexbox Properties

enum EFlexPack { PackStart, PackEnd, PackCenter, PackJustify, PackDistribute };
enum EFlexAlign { AlignAuto, AlignStart, AlignEnd, AlignCenter, AlignStretch, AlignBaseline };
enum EFlexDirection { FlowRow, FlowRowReverse, FlowColumn, FlowColumnReverse };
enum EFlexWrap { FlexNoWrap, FlexWrap, FlexWrapReverse };

enum ETextSecurity {
    TSNONE, TSDISC, TSCIRCLE, TSSQUARE
};

// CSS3 User Modify Properties

enum EUserModify {
    READ_ONLY, READ_WRITE, READ_WRITE_PLAINTEXT_ONLY
};

// CSS3 User Drag Values

enum EUserDrag {
    DRAG_AUTO, DRAG_NONE, DRAG_ELEMENT
};

// CSS3 User Select Values

enum EUserSelect {
    SELECT_NONE, SELECT_TEXT
};

// Word Break Values. Matches WinIE, rather than CSS3

enum EWordBreak {
    NormalWordBreak, BreakAllWordBreak, BreakWordBreak
};

enum EWordWrap {
    NormalWordWrap, BreakWordWrap
};

enum ENBSPMode {
    NBNORMAL, SPACE
};

enum EKHTMLLineBreak {
    LBNORMAL, AFTER_WHITE_SPACE
};

enum EMatchNearestMailBlockquoteColor {
    BCNORMAL, MATCH
};

enum EResize {
    RESIZE_NONE, RESIZE_BOTH, RESIZE_HORIZONTAL, RESIZE_VERTICAL
};

// The order of this enum must match the order of the list style types in CSSValueKeywords.in. 
enum EListStyleType {
    Disc,
    Circle,
    Square,
    DecimalListStyle,
    DecimalLeadingZero,
    ArabicIndic,
    BinaryListStyle,
    Bengali,
    Cambodian,
    Khmer,
    Devanagari,
    Gujarati,
    Gurmukhi,
    Kannada,
    LowerHexadecimal,
    Lao,
    Malayalam,
    Mongolian,
    Myanmar,
    Octal,
    Oriya,
    Persian,
    Urdu,
    Telugu,
    Tibetan,
    Thai,
    UpperHexadecimal,
    LowerRoman,
    UpperRoman,
    LowerGreek,
    LowerAlpha,
    LowerLatin,
    UpperAlpha,
    UpperLatin,
    Afar,
    EthiopicHalehameAaEt,
    EthiopicHalehameAaEr,
    Amharic,
    EthiopicHalehameAmEt,
    AmharicAbegede,
    EthiopicAbegedeAmEt,
    CjkEarthlyBranch,
    CjkHeavenlyStem,
    Ethiopic,
    EthiopicHalehameGez,
    EthiopicAbegede,
    EthiopicAbegedeGez,
    HangulConsonant,
    Hangul,
    LowerNorwegian,
    Oromo,
    EthiopicHalehameOmEt,
    Sidama,
    EthiopicHalehameSidEt,
    Somali,
    EthiopicHalehameSoEt,
    Tigre,
    EthiopicHalehameTig,
    TigrinyaEr,
    EthiopicHalehameTiEr,
    TigrinyaErAbegede,
    EthiopicAbegedeTiEr,
    TigrinyaEt,
    EthiopicHalehameTiEt,
    TigrinyaEtAbegede,
    EthiopicAbegedeTiEt,
    UpperGreek,
    UpperNorwegian,
    Asterisks,
    Footnotes,
    Hebrew,
    Armenian,
    LowerArmenian,
    UpperArmenian,
    Georgian,
    CJKIdeographic,
    Hiragana,
    Katakana,
    HiraganaIroha,
    KatakanaIroha,
    NoneListStyle
};

enum StyleContentType {
    CONTENT_NONE, CONTENT_OBJECT, CONTENT_TEXT, CONTENT_COUNTER, CONTENT_QUOTE
};

enum QuoteType {
    OPEN_QUOTE, CLOSE_QUOTE, NO_OPEN_QUOTE, NO_CLOSE_QUOTE
};

enum EBorderFit { BorderFitBorder, BorderFitLines };

enum EAnimationFillMode { AnimationFillModeNone, AnimationFillModeForwards, AnimationFillModeBackwards, AnimationFillModeBoth };

enum EAnimPlayState {
    AnimPlayStatePlaying = 0x0,
    AnimPlayStatePaused = 0x1
};

enum EWhiteSpace {
    NORMAL, PRE, PRE_WRAP, PRE_LINE, NOWRAP, KHTML_NOWRAP
};

enum ETextAlign {
    TAAUTO, LEFT, RIGHT, CENTER, JUSTIFY, WEBKIT_LEFT, WEBKIT_RIGHT, WEBKIT_CENTER, TASTART, TAEND,
};

enum ETextTransform {
    CAPITALIZE, UPPERCASE, LOWERCASE, TTNONE
};

static const size_t ETextDecorationBits = 4;
enum ETextDecoration {
    TDNONE = 0x0 , UNDERLINE = 0x1, OVERLINE = 0x2, LINE_THROUGH= 0x4, BLINK = 0x8
};
inline ETextDecoration operator|(ETextDecoration a, ETextDecoration b) { return ETextDecoration(int(a) | int(b)); }
inline ETextDecoration& operator|=(ETextDecoration& a, ETextDecoration b) { return a = a | b; }

enum EPageBreak {
    PBAUTO, PBALWAYS, PBAVOID
};

enum EEmptyCell {
    SHOW, HIDE
};

enum ECaptionSide {
    CAPTOP, CAPBOTTOM, CAPLEFT, CAPRIGHT
};

enum EListStylePosition { OUTSIDE, INSIDE };

enum EVisibility { VISIBLE, HIDDEN, COLLAPSE };

enum ECursor {
    // The following must match the order in CSSValueKeywords.in.
    CURSOR_AUTO,
    CURSOR_CROSS,
    CURSOR_DEFAULT,
    CURSOR_POINTER,
    CURSOR_MOVE,
    CURSOR_VERTICAL_TEXT,
    CURSOR_CELL,
    CURSOR_CONTEXT_MENU,
    CURSOR_ALIAS,
    CURSOR_PROGRESS,
    CURSOR_NO_DROP,
    CURSOR_NOT_ALLOWED,
    CURSOR_WEBKIT_ZOOM_IN,
    CURSOR_WEBKIT_ZOOM_OUT,
    CURSOR_E_RESIZE,
    CURSOR_NE_RESIZE,
    CURSOR_NW_RESIZE,
    CURSOR_N_RESIZE,
    CURSOR_SE_RESIZE,
    CURSOR_SW_RESIZE,
    CURSOR_S_RESIZE,
    CURSOR_W_RESIZE,
    CURSOR_EW_RESIZE,
    CURSOR_NS_RESIZE,
    CURSOR_NESW_RESIZE,
    CURSOR_NWSE_RESIZE,
    CURSOR_COL_RESIZE,
    CURSOR_ROW_RESIZE,
    CURSOR_TEXT,
    CURSOR_WAIT,
    CURSOR_HELP,
    CURSOR_ALL_SCROLL,
    CURSOR_WEBKIT_GRAB,
    CURSOR_WEBKIT_GRABBING,

    // The following are handled as exceptions so don't need to match.
    CURSOR_COPY,
    CURSOR_NONE
};

enum EDisplay {
    INLINE, BLOCK, LIST_ITEM, RUN_IN, COMPACT, INLINE_BLOCK,
    TABLE, INLINE_TABLE, TABLE_ROW_GROUP,
    TABLE_HEADER_GROUP, TABLE_FOOTER_GROUP, TABLE_ROW,
    TABLE_COLUMN_GROUP, TABLE_COLUMN, TABLE_CELL,
    TABLE_CAPTION, BOX, INLINE_BOX, 
    FLEXBOX, INLINE_FLEXBOX,
#if ENABLE(CSS_GRID_LAYOUT)
    GRID, INLINE_GRID,
#endif
    NONE
};

enum EInsideLink {
    NotInsideLink, InsideUnvisitedLink, InsideVisitedLink
};
    
enum EPointerEvents {
    PE_NONE, PE_AUTO, PE_STROKE, PE_FILL, PE_PAINTED, PE_VISIBLE,
    PE_VISIBLE_STROKE, PE_VISIBLE_FILL, PE_VISIBLE_PAINTED, PE_ALL
};

enum ETransformStyle3D {
    TransformStyle3DFlat, TransformStyle3DPreserve3D
};

enum EBackfaceVisibility {
    BackfaceVisibilityVisible, BackfaceVisibilityHidden
};
    
enum ELineClampType { LineClampLineCount, LineClampPercentage };

enum Hyphens { HyphensNone, HyphensManual, HyphensAuto };

enum ESpeak { SpeakNone, SpeakNormal, SpeakSpellOut, SpeakDigits, SpeakLiteralPunctuation, SpeakNoPunctuation };

enum TextEmphasisFill { TextEmphasisFillFilled, TextEmphasisFillOpen };

enum TextEmphasisMark { TextEmphasisMarkNone, TextEmphasisMarkAuto, TextEmphasisMarkDot, TextEmphasisMarkCircle, TextEmphasisMarkDoubleCircle, TextEmphasisMarkTriangle, TextEmphasisMarkSesame, TextEmphasisMarkCustom };

enum TextEmphasisPosition { TextEmphasisPositionOver, TextEmphasisPositionUnder };

enum TextOverflow { TextOverflowClip = 0, TextOverflowEllipsis };

enum EImageRendering { ImageRenderingAuto, ImageRenderingOptimizeSpeed, ImageRenderingOptimizeQuality, ImageRenderingOptimizeContrast };

enum Order { LogicalOrder = 0, VisualOrder };

enum RegionOverflow { AutoRegionOverflow, BreakRegionOverflow };

enum ColumnAxis { HorizontalColumnAxis, VerticalColumnAxis, AutoColumnAxis };

enum LineGridSnap { LineGridSnapNone, LineGridSnapBaseline, LineGridSnapContain };

enum WrapFlow { WrapFlowAuto, WrapFlowBoth, WrapFlowLeft, WrapFlowRight, WrapFlowMaximum, WrapFlowClear };

enum WrapThrough { WrapThroughWrap, WrapThroughNone };

} // namespace WebCore

#endif // RenderStyleConstants_h
