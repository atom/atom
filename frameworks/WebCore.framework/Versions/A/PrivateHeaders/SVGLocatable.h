/*
 * Copyright (C) 2004, 2005 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005, 2007 Rob Buis <buis@kde.org>
 * Copyright (C) Research In Motion Limited 2010. All rights reserved.
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

#ifndef SVGLocatable_h
#define SVGLocatable_h

#if ENABLE(SVG)
#include "AffineTransform.h"

namespace WebCore {

class FloatRect;
class SVGElement;

typedef int ExceptionCode;

class SVGLocatable {
public:
    virtual ~SVGLocatable() { }

    // 'SVGLocatable' functions
    virtual SVGElement* nearestViewportElement() const = 0;
    virtual SVGElement* farthestViewportElement() const = 0;

    enum StyleUpdateStrategy { AllowStyleUpdate, DisallowStyleUpdate };
    
    virtual FloatRect getBBox(StyleUpdateStrategy) = 0;
    virtual AffineTransform getCTM(StyleUpdateStrategy) = 0;
    virtual AffineTransform getScreenCTM(StyleUpdateStrategy) = 0;
    AffineTransform getTransformToElement(SVGElement*, ExceptionCode&, StyleUpdateStrategy = AllowStyleUpdate);

    static SVGElement* nearestViewportElement(const SVGElement*);
    static SVGElement* farthestViewportElement(const SVGElement*);

    enum CTMScope {
        NearestViewportScope, // Used for getCTM()
        ScreenScope // Used for getScreenCTM()
    };

protected:
    virtual AffineTransform localCoordinateSpaceTransform(SVGLocatable::CTMScope) const { return AffineTransform(); }

    static FloatRect getBBox(SVGElement*, StyleUpdateStrategy);
    static AffineTransform computeCTM(SVGElement*, CTMScope, StyleUpdateStrategy);
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGLocatable_h
