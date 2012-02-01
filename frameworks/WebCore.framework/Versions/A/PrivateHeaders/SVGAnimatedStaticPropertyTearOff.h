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

#ifndef SVGAnimatedStaticPropertyTearOff_h
#define SVGAnimatedStaticPropertyTearOff_h

#if ENABLE(SVG)
#include "SVGAnimatedProperty.h"

namespace WebCore {

template<typename PropertyType>
class SVGAnimatedStaticPropertyTearOff : public SVGAnimatedProperty {
public:
    PropertyType& baseVal()
    {
        return m_property;
    }

    PropertyType& animVal()
    {
        // FIXME: No animVal support.
        return m_property;
    }

    virtual void setBaseVal(const PropertyType& property, ExceptionCode&)
    {
        m_property = property;
        commitChange();
    }

    // FIXME: No animVal support.
    bool isAnimating() const { return false; }
    PropertyType& currentAnimatedValue() { return m_property; }

    static PassRefPtr<SVGAnimatedStaticPropertyTearOff<PropertyType> > create(SVGElement* contextElement, const QualifiedName& attributeName, PropertyType& property)
    {
        ASSERT(contextElement);
        return adoptRef(new SVGAnimatedStaticPropertyTearOff<PropertyType>(contextElement, attributeName, property));
    }

protected:
    SVGAnimatedStaticPropertyTearOff(SVGElement* contextElement, const QualifiedName& attributeName, PropertyType& property)
        : SVGAnimatedProperty(contextElement, attributeName)
        , m_property(property)
    {
    }

    virtual ~SVGAnimatedStaticPropertyTearOff() { }

private:
    PropertyType& m_property;
};

}

#endif // ENABLE(SVG)
#endif // SVGAnimatedStaticPropertyTearOff_h
