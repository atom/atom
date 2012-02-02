/*
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

#ifndef SVGAnimatedPropertySynchronizer_h
#define SVGAnimatedPropertySynchronizer_h

#if ENABLE(SVG)
#include "SVGElement.h"

namespace WebCore {

// Helper template used for synchronizing SVG <-> XML properties
template<bool isDerivedFromSVGElement>
struct SVGAnimatedPropertySynchronizer;

template<>
struct SVGAnimatedPropertySynchronizer<true> {
    static void synchronize(SVGElement* ownerElement, const QualifiedName& attrName, const AtomicString& value)
    {
        // If the attribute already exists on the element, we change the
        // Attribute directly to avoid a call to Element::attributeChanged
        // that could cause the SVGElement to erroneously reset its properties.
        // svg/dom/SVGStringList-basics.xhtml exercises this behavior.
        NamedNodeMap* namedAttrMap = ownerElement->attributes(false);
        Attribute* old = namedAttrMap->getAttributeItem(attrName);
        if (old && value.isNull())
            namedAttrMap->removeAttribute(old->name());
        else if (!old && !value.isNull())
            namedAttrMap->addAttribute(ownerElement->createAttribute(attrName, value));
        else if (old && !value.isNull())
            old->setValue(value);

    }
};

template<>
struct SVGAnimatedPropertySynchronizer<false> {
    static void synchronize(void*, const QualifiedName&, const AtomicString&)
    {
        // no-op, for types not inheriting from Element, thus nothing to synchronize
    }
};

};

#endif
#endif
