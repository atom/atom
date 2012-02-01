/*
 * Copyright (C) 2004, 2005, 2008 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005 Rob Buis <buis@kde.org>
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

#ifndef SVGTransformList_h
#define SVGTransformList_h

#if ENABLE(SVG)
#include "SVGPropertyTraits.h"
#include "SVGTransform.h"
#include <wtf/Vector.h>

namespace WebCore {

class SVGTransformList : public Vector<SVGTransform> {
public:
    SVGTransformList() { }

    SVGTransform createSVGTransformFromMatrix(const SVGMatrix&) const;
    SVGTransform consolidate();

    // Internal use only
    bool concatenate(AffineTransform& result) const;
 
    String valueAsString() const;
};

template<>
struct SVGPropertyTraits<SVGTransformList> {
    static SVGTransformList initialValue() { return SVGTransformList(); }
    static String toString(const SVGTransformList& type) { return type.valueAsString(); }
    typedef SVGTransform ListItemType;
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGTransformList_h
