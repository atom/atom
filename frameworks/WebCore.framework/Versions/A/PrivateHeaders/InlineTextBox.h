/*
 * (C) 1999 Lars Knoll (knoll@kde.org)
 * (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2009, 2010, 2011 Apple Inc. All rights reserved.
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

#ifndef InlineTextBox_h
#define InlineTextBox_h

#include "InlineBox.h"
#include "RenderText.h" // so textRenderer() can be inline
#include "TextRun.h"
#include <wtf/text/StringBuilder.h>

namespace WebCore {

struct CompositionUnderline;
class DocumentMarker;

const unsigned short cNoTruncation = USHRT_MAX;
const unsigned short cFullTruncation = USHRT_MAX - 1;

class BufferForAppendingHyphen : public StringBuilder {
public:
    BufferForAppendingHyphen() { reserveCapacity(256); }
};

// Helper functions shared by InlineTextBox / SVGRootInlineBox
void updateGraphicsContext(GraphicsContext*, const Color& fillColor, const Color& strokeColor, float strokeThickness, ColorSpace);
Color correctedTextColor(Color textColor, Color backgroundColor);

class InlineTextBox : public InlineBox {
public:
    InlineTextBox(RenderObject* obj)
        : InlineBox(obj)
        , m_prevTextBox(0)
        , m_nextTextBox(0)
        , m_start(0)
        , m_len(0)
        , m_truncation(cNoTruncation)
    {
    }

    virtual void destroy(RenderArena*);

    InlineTextBox* prevTextBox() const { return m_prevTextBox; }
    InlineTextBox* nextTextBox() const { return m_nextTextBox; }
    void setNextTextBox(InlineTextBox* n) { m_nextTextBox = n; }
    void setPreviousTextBox(InlineTextBox* p) { m_prevTextBox = p; }

    unsigned start() const { return m_start; }
    unsigned end() const { return m_len ? m_start + m_len - 1 : m_start; }
    unsigned len() const { return m_len; }

    void setStart(unsigned start) { m_start = start; }
    void setLen(unsigned len) { m_len = len; }

    void offsetRun(int d) { m_start += d; }

    unsigned short truncation() { return m_truncation; }

    bool hasHyphen() const { return m_hasEllipsisBoxOrHyphen; }
    void setHasHyphen(bool hasHyphen) { m_hasEllipsisBoxOrHyphen = hasHyphen; }

    bool canHaveLeadingExpansion() const { return m_hasSelectedChildrenOrCanHaveLeadingExpansion; }
    void setCanHaveLeadingExpansion(bool canHaveLeadingExpansion) { m_hasSelectedChildrenOrCanHaveLeadingExpansion = canHaveLeadingExpansion; }

    static inline bool compareByStart(const InlineTextBox* first, const InlineTextBox* second) { return first->start() < second->start(); }

    virtual LayoutUnit baselinePosition(FontBaseline) const;
    virtual LayoutUnit lineHeight() const;

    bool getEmphasisMarkPosition(RenderStyle*, TextEmphasisPosition&) const;

    LayoutRect logicalOverflowRect() const;
    void setLogicalOverflowRect(const LayoutRect&);
    LayoutUnit logicalTopVisualOverflow() const { return logicalOverflowRect().y(); }
    LayoutUnit logicalBottomVisualOverflow() const { return logicalOverflowRect().maxY(); }
    LayoutUnit logicalLeftVisualOverflow() const { return logicalOverflowRect().x(); }
    LayoutUnit logicalRightVisualOverflow() const { return logicalOverflowRect().maxX(); }

#ifndef NDEBUG
    virtual void showBox(int = 0) const;
    virtual const char* boxName() const;
#endif
private:
    LayoutUnit selectionTop();
    LayoutUnit selectionBottom();
    LayoutUnit selectionHeight();

    TextRun constructTextRun(RenderStyle*, const Font&, BufferForAppendingHyphen* = 0) const;
    TextRun constructTextRun(RenderStyle*, const Font&, const UChar*, int length, int maximumLength, BufferForAppendingHyphen* = 0) const;

public:
    virtual FloatRect calculateBoundaries() const { return FloatRect(x(), y(), width(), height()); }

    virtual IntRect localSelectionRect(int startPos, int endPos);
    bool isSelected(int startPos, int endPos) const;
    void selectionStartEnd(int& sPos, int& ePos);

protected:
    virtual void paint(PaintInfo&, const LayoutPoint&, LayoutUnit lineTop, LayoutUnit lineBottom);
    virtual bool nodeAtPoint(const HitTestRequest&, HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset, LayoutUnit lineTop, LayoutUnit lineBottom);

public:
    RenderText* textRenderer() const;

private:
    virtual void deleteLine(RenderArena*);
    virtual void extractLine();
    virtual void attachLine();

public:
    virtual RenderObject::SelectionState selectionState();

private:
    virtual void clearTruncation() { m_truncation = cNoTruncation; }
    virtual float placeEllipsisBox(bool flowIsLTR, float visibleLeftEdge, float visibleRightEdge, float ellipsisWidth, bool& foundBox);

public:
    virtual bool isLineBreak() const;

    void setExpansion(int expansion) { m_logicalWidth -= m_expansion; m_expansion = expansion; m_logicalWidth += m_expansion; }

private:
    virtual bool isInlineTextBox() const { return true; }    

public:
    virtual int caretMinOffset() const;
    virtual int caretMaxOffset() const;

private:
    float textPos() const; // returns the x position relative to the left start of the text line.

public:
    virtual int offsetForPosition(float x, bool includePartialGlyphs = true) const;
    virtual float positionForOffset(int offset) const;

    bool containsCaretOffset(int offset) const; // false for offset after line break

    // Needs to be public, so the static paintTextWithShadows() function can use it.
    static FloatSize applyShadowToGraphicsContext(GraphicsContext*, const ShadowData*, const FloatRect& textRect, bool stroked, bool opaque, bool horizontal);

private:
    InlineTextBox* m_prevTextBox; // The previous box that also uses our RenderObject
    InlineTextBox* m_nextTextBox; // The next box that also uses our RenderObject

    int m_start;
    unsigned short m_len;

    unsigned short m_truncation; // Where to truncate when text overflow is applied.  We use special constants to
                      // denote no truncation (the whole run paints) and full truncation (nothing paints at all).

protected:
    void paintCompositionBackground(GraphicsContext*, const FloatPoint& boxOrigin, RenderStyle*, const Font&, int startPos, int endPos);
    void paintDocumentMarkers(GraphicsContext*, const FloatPoint& boxOrigin, RenderStyle*, const Font&, bool background);
    void paintCompositionUnderline(GraphicsContext*, const FloatPoint& boxOrigin, const CompositionUnderline&);
#if PLATFORM(MAC)
    void paintCustomHighlight(const LayoutPoint&, const AtomicString& type);
#endif

private:
    void paintDecoration(GraphicsContext*, const FloatPoint& boxOrigin, int decoration, const ShadowData*);
    void paintSelection(GraphicsContext*, const FloatPoint& boxOrigin, RenderStyle*, const Font&);
    void paintSpellingOrGrammarMarker(GraphicsContext*, const FloatPoint& boxOrigin, DocumentMarker*, RenderStyle*, const Font&, bool grammar);
    void paintTextMatchMarker(GraphicsContext*, const FloatPoint& boxOrigin, DocumentMarker*, RenderStyle*, const Font&);
    void computeRectForReplacementMarker(DocumentMarker*, RenderStyle*, const Font&);

    TextRun::ExpansionBehavior expansionBehavior() const
    {
        return (canHaveLeadingExpansion() ? TextRun::AllowLeadingExpansion : TextRun::ForbidLeadingExpansion)
            | (m_expansion && nextLeafChild() ? TextRun::AllowTrailingExpansion : TextRun::ForbidTrailingExpansion);
    }
};

inline InlineTextBox* toInlineTextBox(InlineBox* inlineBox)
{
    ASSERT(!inlineBox || inlineBox->isInlineTextBox());
    return static_cast<InlineTextBox*>(inlineBox);
}

inline const InlineTextBox* toInlineTextBox(const InlineBox* inlineBox)
{
    ASSERT(!inlineBox || inlineBox->isInlineTextBox());
    return static_cast<const InlineTextBox*>(inlineBox);
}

// This will catch anyone doing an unnecessary cast.
void toInlineTextBox(const InlineTextBox*);

inline RenderText* InlineTextBox::textRenderer() const
{
    return toRenderText(renderer());
}

} // namespace WebCore

#endif // InlineTextBox_h
