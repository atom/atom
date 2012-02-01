/*
 * Copyright (C) 2006 Rob Buis <buis@kde.org>
 * Copyright (C) 2008 Apple Inc. All right reserved.
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

#ifndef CSSCursorImageValue_h
#define CSSCursorImageValue_h

#include "CSSImageValue.h"
#include "IntPoint.h"
#include <wtf/HashSet.h>

namespace WebCore {

class Element;
class SVGElement;

class CSSCursorImageValue : public CSSImageValue {
public:
    static PassRefPtr<CSSCursorImageValue> create(const String& url, const IntPoint& hotSpot)
    {
        return adoptRef(new CSSCursorImageValue(url, hotSpot));
    }

    ~CSSCursorImageValue();

    IntPoint hotSpot() const { return m_hotSpot; }

    bool updateIfSVGCursorIsUsed(Element*);
    StyleCachedImage* cachedImage(CachedResourceLoader*);

#if ENABLE(SVG)
    void removeReferencedElement(SVGElement*);
#endif

private:
    CSSCursorImageValue(const String& url, const IntPoint& hotSpot);

    IntPoint m_hotSpot;

#if ENABLE(SVG)
    HashSet<SVGElement*> m_referencedElements;
#endif
};

} // namespace WebCore

#endif // CSSCursorImageValue_h
