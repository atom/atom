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

#ifndef SVGStaticPropertyWithParentTearOff_h
#define SVGStaticPropertyWithParentTearOff_h

#if ENABLE(SVG)
#include "SVGPropertyTearOff.h"

namespace WebCore {

#if COMPILER(MSVC)
// UpdateMethod is 12 bytes. We have to pack to a size greater than or equal to that to avoid an
// alignment warning (C4121). 16 is the next-largest size allowed for packing, so we use that.
#pragma pack(push, 16)
#endif
template<typename ParentType, typename PropertyType>
class SVGStaticPropertyWithParentTearOff : public SVGPropertyTearOff<PropertyType> {
public:
    typedef SVGStaticPropertyWithParentTearOff<ParentType, PropertyType> Self;
    typedef void (ParentType::*UpdateMethod)();

    // Used for non-animated POD types that are not associated with a SVGAnimatedProperty object, nor with a XML DOM attribute
    // and that contain a parent type that's exposed to the bindings via a SVGStaticPropertyTearOff object
    // (for example: SVGTransform::matrix).
    static PassRefPtr<Self> create(SVGProperty* parent, PropertyType& value, UpdateMethod update)
    {
        ASSERT(parent);
        return adoptRef(new Self(parent, value, update));
    }

    virtual void commitChange()
    {
        (static_cast<SVGPropertyTearOff<ParentType>*>(m_parent.get())->propertyReference().*m_update)();
        m_parent->commitChange();
    }

private:
    SVGStaticPropertyWithParentTearOff(SVGProperty* parent, PropertyType& value, UpdateMethod update)
        : SVGPropertyTearOff<PropertyType>(0, UndefinedRole, value)
        , m_update(update)
        , m_parent(parent)
    {
    }

    UpdateMethod m_update;
    RefPtr<SVGProperty> m_parent;
};
#if COMPILER(MSVC)
#pragma pack(pop)
#endif

}

#endif // ENABLE(SVG)
#endif // SVGStaticPropertyWithParentTearOff_h
