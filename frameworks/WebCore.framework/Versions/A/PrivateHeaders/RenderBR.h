/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
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

#ifndef RenderBR_h
#define RenderBR_h

#include "RenderText.h"

/*
 * The whole class here is a hack to get <br> working, as long as we don't have support for
 * CSS2 :before and :after pseudo elements
 */
namespace WebCore {

class Position;

class RenderBR : public RenderText {
public:
    RenderBR(Node*);
    virtual ~RenderBR();

    virtual const char* renderName() const { return "RenderBR"; }
 
    virtual LayoutRect selectionRectForRepaint(RenderBoxModelObject* /*repaintContainer*/, bool /*clipToVisibleContent*/) { return LayoutRect(); }

    virtual float width(unsigned /*from*/, unsigned /*len*/, const Font&, float /*xPos*/, HashSet<const SimpleFontData*>* = 0 /*fallbackFonts*/ , GlyphOverflow* = 0) const { return 0; }
    virtual float width(unsigned /*from*/, unsigned /*len*/, float /*xpos*/, bool = false /*firstLine*/, HashSet<const SimpleFontData*>* = 0 /*fallbackFonts*/, GlyphOverflow* = 0) const { return 0; }

    int lineHeight(bool firstLine) const;

    // overrides
    virtual bool isBR() const { return true; }

    virtual int caretMinOffset() const;
    virtual int caretMaxOffset() const;

    virtual VisiblePosition positionForPoint(const LayoutPoint&);

protected:
    virtual void styleDidChange(StyleDifference, const RenderStyle* oldStyle);

private:
    mutable int m_lineHeight;
};


inline RenderBR* toRenderBR(RenderObject* object)
{ 
    ASSERT(!object || object->isBR());
    return static_cast<RenderBR*>(object);
}

inline const RenderBR* toRenderBR(const RenderObject* object)
{ 
    ASSERT(!object || object->isBR());
    return static_cast<const RenderBR*>(object);
}

// This will catch anyone doing an unnecessary cast.
void toRenderBR(const RenderBR*);

} // namespace WebCore

#endif // RenderBR_h
