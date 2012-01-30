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

#ifndef SVGPropertyTearOff_h
#define SVGPropertyTearOff_h

#if ENABLE(SVG)
#include "SVGAnimatedProperty.h"
#include "SVGElement.h"
#include "SVGProperty.h"

namespace WebCore {

template<typename PropertyType>
class SVGPropertyTearOff : public SVGProperty {
public:
    typedef SVGPropertyTearOff<PropertyType> Self;

    // Used for child types (baseVal/animVal) of a SVGAnimated* property (for example: SVGAnimatedLength::baseVal()).
    // Also used for list tear offs (for example: text.x.baseVal.getItem(0)).
    static PassRefPtr<Self> create(SVGAnimatedProperty* animatedProperty, SVGPropertyRole role, PropertyType& value)
    {
        ASSERT(animatedProperty);
        return adoptRef(new Self(animatedProperty, role, value));
    }

    // Used for non-animated POD types (for example: SVGSVGElement::createSVGLength()).
    static PassRefPtr<Self> create(const PropertyType& initialValue)
    {
        return adoptRef(new Self(initialValue));
    }

    PropertyType& propertyReference() { return *m_value; }
    SVGAnimatedProperty* animatedProperty() const { return m_animatedProperty.get(); }

    // Used only by the list tear offs!
    void setValue(PropertyType& value)
    {
        if (m_valueIsCopy)
            delete m_value;
        m_valueIsCopy = false;
        m_value = &value;
    }

    void setAnimatedProperty(SVGAnimatedProperty* animatedProperty) { m_animatedProperty = animatedProperty; }

    SVGElement* contextElement() const
    {
        if (!m_animatedProperty || m_valueIsCopy)
            return 0;
        return m_animatedProperty->contextElement();
    }

    void detachWrapper()
    {
        if (m_valueIsCopy)
            return;

        // Switch from a live value, to a non-live value.
        // For example: <text x="50"/>
        // var item = text.x.baseVal.getItem(0);
        // text.setAttribute("x", "100");
        // item.value still has to report '50' and it has to be possible to modify 'item'
        // w/o changing the "new item" (with x=100) in the text element.
        // Whenever the XML DOM modifies the "x" attribute, all existing wrappers are detached, using this function.
        m_value = new PropertyType(*m_value);
        m_valueIsCopy = true;
        m_animatedProperty = 0;
    }

    virtual void commitChange()
    {
        if (!m_animatedProperty || m_valueIsCopy)
            return;
        m_animatedProperty->commitChange();
    }

    virtual SVGPropertyRole role() const { return m_role; }

    void updateAnimVal(PropertyType* value)
    {
        ASSERT(!m_valueIsCopy);
        ASSERT(m_role == AnimValRole);
        m_value = value;
    }

protected:
    SVGPropertyTearOff(SVGAnimatedProperty* animatedProperty, SVGPropertyRole role, PropertyType& value)
        : m_animatedProperty(animatedProperty)
        , m_role(role)
        , m_value(&value)
        , m_valueIsCopy(false)
    {
        // Using operator & is completly fine, as SVGAnimatedProperty owns this reference,
        // and we're guaranteed to live as long as SVGAnimatedProperty does.
    }

    SVGPropertyTearOff(const PropertyType& initialValue)
        : m_animatedProperty(0)
        , m_role(UndefinedRole)
        , m_value(new PropertyType(initialValue))
        , m_valueIsCopy(true)
    {
    }

    virtual ~SVGPropertyTearOff()
    {
        if (m_valueIsCopy)
            delete m_value;
    }

    RefPtr<SVGAnimatedProperty> m_animatedProperty;
    SVGPropertyRole m_role;
    PropertyType* m_value;
    bool m_valueIsCopy : 1;
};

}

#endif // ENABLE(SVG)
#endif // SVGPropertyTearOff_h
