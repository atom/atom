/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005 Rob Buis <buis@kde.org>
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

#ifndef SVGAnimatedPropertyDescription_h
#define SVGAnimatedPropertyDescription_h

#if ENABLE(SVG)
#include <wtf/HashMap.h>
#include <wtf/text/AtomicString.h>

namespace WebCore {

class SVGElement;

struct SVGAnimatedPropertyDescription {            
    // Empty value
    SVGAnimatedPropertyDescription()
        : m_element(0)
        , m_attributeName(0)
    {
    }

    // Deleted value
    SVGAnimatedPropertyDescription(WTF::HashTableDeletedValueType)
        : m_element(reinterpret_cast<SVGElement*>(-1))
    {
    }

    bool isHashTableDeletedValue() const
    {
        return m_element == reinterpret_cast<SVGElement*>(-1);
    }

    SVGAnimatedPropertyDescription(SVGElement* element, const AtomicString& attributeName)
        : m_element(element)
        , m_attributeName(attributeName.impl())
    {
        ASSERT(m_element);
        ASSERT(m_attributeName);
    }

    bool operator==(const SVGAnimatedPropertyDescription& other) const
    {
        return m_element == other.m_element && m_attributeName == other.m_attributeName;
    }

    SVGElement* m_element;
    AtomicStringImpl* m_attributeName;
};

struct SVGAnimatedPropertyDescriptionHash {
    static unsigned hash(const SVGAnimatedPropertyDescription& key)
    {
        return StringHasher::hashMemory<sizeof(SVGAnimatedPropertyDescription)>(&key);
    }

    static bool equal(const SVGAnimatedPropertyDescription& a, const SVGAnimatedPropertyDescription& b)
    {
        return a == b;
    }

    static const bool safeToCompareToEmptyOrDeleted = true;
};

struct SVGAnimatedPropertyDescriptionHashTraits : WTF::SimpleClassHashTraits<SVGAnimatedPropertyDescription> { };
 
}

#endif // ENABLE(SVG)
#endif // SVGAnimatedPropertyDescription_h
