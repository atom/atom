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

#ifndef SVGAnimatedPropertyTearOff_h
#define SVGAnimatedPropertyTearOff_h

#if ENABLE(SVG)
#include "SVGAnimatedProperty.h"
#include "SVGPropertyTearOff.h"

namespace WebCore {

template<typename PropertyType>
class SVGAnimatedPropertyTearOff : public SVGAnimatedProperty {
public:
    SVGProperty* baseVal()
    {
        if (!m_baseVal)
            m_baseVal = SVGPropertyTearOff<PropertyType>::create(this, BaseValRole, m_property);
        return m_baseVal.get();
    }

    SVGProperty* animVal()
    {
        if (!m_animVal)
            m_animVal = SVGPropertyTearOff<PropertyType>::create(this, AnimValRole, m_property);
        return m_animVal.get();
    }

    static PassRefPtr<SVGAnimatedPropertyTearOff<PropertyType> > create(SVGElement* contextElement, const QualifiedName& attributeName, PropertyType& property)
    {
        ASSERT(contextElement);
        return adoptRef(new SVGAnimatedPropertyTearOff<PropertyType>(contextElement, attributeName, property));
    }

    bool isAnimating() const { return m_isAnimating; }

    PropertyType& currentAnimatedValue()
    {
        ASSERT(m_animVal);
        ASSERT(m_isAnimating);
        return static_cast<SVGPropertyTearOff<PropertyType>*>(m_animVal.get())->propertyReference();
    }

    virtual void updateAnimVal(void* value)
    {
        if (value) {
            static_cast<SVGPropertyTearOff<PropertyType>*>(animVal())->updateAnimVal(reinterpret_cast<PropertyType*>(value));
            m_isAnimating = true;
            return;
        }

        static_cast<SVGPropertyTearOff<PropertyType>*>(animVal())->updateAnimVal(&m_property);
        m_isAnimating = false;
    }

private:
    SVGAnimatedPropertyTearOff(SVGElement* contextElement, const QualifiedName& attributeName, PropertyType& property)
        : SVGAnimatedProperty(contextElement, attributeName)
        , m_property(property)
        , m_isAnimating(false)
    {
    }

    PropertyType& m_property;
    bool m_isAnimating;
    RefPtr<SVGProperty> m_baseVal;
    RefPtr<SVGProperty> m_animVal;
};

}

#endif // ENABLE(SVG)
#endif // SVGAnimatedPropertyTearOff_h
