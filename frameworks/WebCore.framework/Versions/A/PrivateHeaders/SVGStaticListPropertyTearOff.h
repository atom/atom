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

#ifndef SVGStaticListPropertyTearOff_h
#define SVGStaticListPropertyTearOff_h

#if ENABLE(SVG)
#include "SVGListProperty.h"

namespace WebCore {

template<typename PropertyType>
class SVGStaticListPropertyTearOff : public SVGListProperty<PropertyType> {
public:
    typedef SVGListProperty<PropertyType> Base;

    typedef typename SVGPropertyTraits<PropertyType>::ListItemType ListItemType;
    typedef SVGPropertyTearOff<ListItemType> ListItemTearOff;

    static PassRefPtr<SVGStaticListPropertyTearOff<PropertyType> > create(SVGElement* contextElement, PropertyType& values)
    {
        ASSERT(contextElement);
        return adoptRef(new SVGStaticListPropertyTearOff<PropertyType>(contextElement, values));
    }

    // SVGList API
    void clear(ExceptionCode& ec)
    {
        Base::clearValues(m_values, ec);
    }

    unsigned numberOfItems() const
    {
        return Base::numberOfItemsValues(m_values);
    }

    ListItemType initialize(const ListItemType& newItem, ExceptionCode& ec)
    {
        return Base::initializeValues(m_values, newItem, ec);
    }

    ListItemType getItem(unsigned index, ExceptionCode& ec)
    {
        return Base::getItemValues(m_values, index, ec);
    }

    ListItemType insertItemBefore(const ListItemType& newItem, unsigned index, ExceptionCode& ec)
    {
        return Base::insertItemBeforeValues(m_values, newItem, index, ec);
    }

    ListItemType replaceItem(const ListItemType& newItem, unsigned index, ExceptionCode& ec)
    {
        return Base::replaceItemValues(m_values, newItem, index, ec);
    }

    ListItemType removeItem(unsigned index, ExceptionCode& ec)
    {
        return Base::removeItemValues(m_values, index, ec);
    }

    ListItemType appendItem(const ListItemType& newItem, ExceptionCode& ec)
    {
        return Base::appendItemValues(m_values, newItem, ec);
    }

private:
    SVGStaticListPropertyTearOff(SVGElement* contextElement, PropertyType& values)
        : SVGListProperty<PropertyType>(UndefinedRole)
        , m_contextElement(contextElement)
        , m_values(values)
    {
    }

    virtual void commitChange()
    {
        m_values.commitChange(m_contextElement.get());
    }

    virtual void processIncomingListItemValue(const ListItemType&, unsigned*)
    {
        // no-op for static lists
    }

    virtual void processIncomingListItemWrapper(RefPtr<ListItemTearOff>&, unsigned*)
    {
        ASSERT_NOT_REACHED();
    }

private:
    RefPtr<SVGElement> m_contextElement;
    PropertyType& m_values;
};

}

#endif // ENABLE(SVG)
#endif // SVGStaticListPropertyTearOff_h
