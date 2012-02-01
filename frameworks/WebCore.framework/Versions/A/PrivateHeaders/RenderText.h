/*
 * (C) 1999 Lars Knoll (knoll@kde.org)
 * (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef RenderText_h
#define RenderText_h

#include "RenderObject.h"
#include <wtf/Forward.h>

namespace WebCore {

class InlineTextBox;

class RenderText : public RenderObject {
public:
    RenderText(Node*, PassRefPtr<StringImpl>);
#ifndef NDEBUG
    virtual ~RenderText();
#endif

    virtual const char* renderName() const;

    virtual bool isTextFragment() const;
    virtual bool isWordBreak() const;

    virtual PassRefPtr<StringImpl> originalText() const;

    void extractTextBox(InlineTextBox*);
    void attachTextBox(InlineTextBox*);
    void removeTextBox(InlineTextBox*);

    StringImpl* text() const { return m_text.impl(); }
    String textWithoutTranscoding() const;

    InlineTextBox* createInlineTextBox();
    void dirtyLineBoxes(bool fullLayout);

    virtual void absoluteRects(Vector<LayoutRect>&, const LayoutPoint& accumulatedOffset) const;
    void absoluteRectsForRange(Vector<LayoutRect>&, unsigned startOffset = 0, unsigned endOffset = UINT_MAX, bool useSelectionHeight = false, bool* wasFixed = 0);

    virtual void absoluteQuads(Vector<FloatQuad>&, bool* wasFixed) const;
    void absoluteQuadsForRange(Vector<FloatQuad>&, unsigned startOffset = 0, unsigned endOffset = UINT_MAX, bool useSelectionHeight = false, bool* wasFixed = 0);

    enum ClippingOption { NoClipping, ClipToEllipsis };
    void absoluteQuads(Vector<FloatQuad>&, bool* wasFixed = 0, ClippingOption = NoClipping) const;

    virtual VisiblePosition positionForPoint(const LayoutPoint&);

    const UChar* characters() const { return m_text.characters(); }
    unsigned textLength() const { return m_text.length(); } // non virtual implementation of length()
    void positionLineBox(InlineBox*);

    virtual float width(unsigned from, unsigned len, const Font&, float xPos, HashSet<const SimpleFontData*>* fallbackFonts = 0, GlyphOverflow* = 0) const;
    virtual float width(unsigned from, unsigned len, float xPos, bool firstLine = false, HashSet<const SimpleFontData*>* fallbackFonts = 0, GlyphOverflow* = 0) const;

    float minLogicalWidth() const;
    float maxLogicalWidth() const;

    void trimmedPrefWidths(float leadWidth,
                           float& beginMinW, bool& beginWS,
                           float& endMinW, bool& endWS,
                           bool& hasBreakableChar, bool& hasBreak,
                           float& beginMaxW, float& endMaxW,
                           float& minW, float& maxW, bool& stripFrontSpaces);

    virtual LayoutRect linesBoundingBox() const;
    LayoutRect linesVisualOverflowBoundingBox() const;

    FloatPoint firstRunOrigin() const;
    float firstRunX() const;
    float firstRunY() const;

    void setText(PassRefPtr<StringImpl>, bool force = false);
    void setTextWithOffset(PassRefPtr<StringImpl>, unsigned offset, unsigned len, bool force = false);

    virtual bool canBeSelectionLeaf() const { return true; }
    virtual void setSelectionState(SelectionState s);
    virtual LayoutRect selectionRectForRepaint(RenderBoxModelObject* repaintContainer, bool clipToVisibleContent = true);
    virtual LayoutRect localCaretRect(InlineBox*, int caretOffset, LayoutUnit* extraWidthToEndOfLine = 0);

    virtual LayoutUnit marginLeft() const { return style()->marginLeft().calcMinValue(0); }
    virtual LayoutUnit marginRight() const { return style()->marginRight().calcMinValue(0); }

    virtual LayoutRect clippedOverflowRectForRepaint(RenderBoxModelObject* repaintContainer) const;

    InlineTextBox* firstTextBox() const { return m_firstTextBox; }
    InlineTextBox* lastTextBox() const { return m_lastTextBox; }

    virtual int caretMinOffset() const;
    virtual int caretMaxOffset() const;
    virtual unsigned renderedTextLength() const;

    virtual int previousOffset(int current) const;
    virtual int previousOffsetForBackwardDeletion(int current) const;
    virtual int nextOffset(int current) const;

    bool containsReversedText() const { return m_containsReversedText; }

    bool isSecure() const { return style()->textSecurity() != TSNONE; }
    void momentarilyRevealLastTypedCharacter(unsigned lastTypedCharacterOffset);

    InlineTextBox* findNextInlineTextBox(int offset, int& pos) const;

    bool allowTabs() const { return !style()->collapseWhiteSpace(); }

    void checkConsistency() const;

    virtual void computePreferredLogicalWidths(float leadWidth);
    bool isAllCollapsibleWhitespace();
    
    bool knownToHaveNoOverflowAndNoFallbackFonts() const { return m_knownToHaveNoOverflowAndNoFallbackFonts; }

    void removeAndDestroyTextBoxes();

protected:
    virtual void willBeDestroyed();

    virtual void styleWillChange(StyleDifference, const RenderStyle*) { }
    virtual void styleDidChange(StyleDifference, const RenderStyle* oldStyle);

    virtual void setTextInternal(PassRefPtr<StringImpl>);
    virtual UChar previousCharacter() const;
    
    virtual InlineTextBox* createTextBox(); // Subclassed by SVG.

private:
    void computePreferredLogicalWidths(float leadWidth, HashSet<const SimpleFontData*>& fallbackFonts, GlyphOverflow&);

    // Make length() private so that callers that have a RenderText*
    // will use the more efficient textLength() instead, while
    // callers with a RenderObject* can continue to use length().
    virtual unsigned length() const { return textLength(); }

    virtual void paint(PaintInfo&, const LayoutPoint&) { ASSERT_NOT_REACHED(); }
    virtual void layout() { ASSERT_NOT_REACHED(); }
    virtual bool nodeAtPoint(const HitTestRequest&, HitTestResult&, const LayoutPoint&, const LayoutPoint&, HitTestAction) { ASSERT_NOT_REACHED(); return false; }

    void deleteTextBoxes();
    bool containsOnlyWhitespace(unsigned from, unsigned len) const;
    float widthFromCache(const Font&, int start, int len, float xPos, HashSet<const SimpleFontData*>* fallbackFonts, GlyphOverflow*) const;
    bool isAllASCII() const { return m_isAllASCII; }
    void updateNeedsTranscoding();

    inline void transformText(String&) const;
    void secureText(UChar mask);

    float m_minWidth; // here to minimize padding in 64-bit.

    String m_text;

    InlineTextBox* m_firstTextBox;
    InlineTextBox* m_lastTextBox;

    float m_maxWidth;
    float m_beginMinWidth;
    float m_endMinWidth;

    bool m_hasBreakableChar : 1; // Whether or not we can be broken into multiple lines.
    bool m_hasBreak : 1; // Whether or not we have a hard break (e.g., <pre> with '\n').
    bool m_hasTab : 1; // Whether or not we have a variable width tab character (e.g., <pre> with '\t').
    bool m_hasBeginWS : 1; // Whether or not we begin with WS (only true if we aren't pre)
    bool m_hasEndWS : 1; // Whether or not we end with WS (only true if we aren't pre)
    bool m_linesDirty : 1; // This bit indicates that the text run has already dirtied specific
                           // line boxes, and this hint will enable layoutInlineChildren to avoid
                           // just dirtying everything when character data is modified (e.g., appended/inserted
                           // or removed).
    bool m_containsReversedText : 1;
    bool m_isAllASCII : 1;
    mutable bool m_knownToHaveNoOverflowAndNoFallbackFonts : 1;
    bool m_needsTranscoding : 1;
};

inline RenderText* toRenderText(RenderObject* object)
{ 
    ASSERT(!object || object->isText());
    return static_cast<RenderText*>(object);
}

inline const RenderText* toRenderText(const RenderObject* object)
{ 
    ASSERT(!object || object->isText());
    return static_cast<const RenderText*>(object);
}

// This will catch anyone doing an unnecessary cast.
void toRenderText(const RenderText*);

#ifdef NDEBUG
inline void RenderText::checkConsistency() const
{
}
#endif

void applyTextTransform(const RenderStyle*, String&, UChar);

} // namespace WebCore

#endif // RenderText_h
