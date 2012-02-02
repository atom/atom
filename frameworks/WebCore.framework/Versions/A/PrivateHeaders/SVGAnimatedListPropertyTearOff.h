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

#ifndef SVGAnimatedListPropertyTearOff_h
#define SVGAnimatedListPropertyTearOff_h

#if ENABLE(SVG)
#include "SVGAnimatedProperty.h"
#include "SVGListPropertyTearOff.h"
#include "SVGStaticListPropertyTearOff.h"

namespace WebCore {

template<typename PropertyType>
class SVGPropertyTearOff;

template<typename PropertyType>
class SVGAnimatedListPropertyTearOff : public SVGAnimatedProperty {
public:
    typedef typename SVGPropertyTraits<PropertyType>::ListItemType ListItemType;
    typedef SVGPropertyTearOff<ListItemType> ListItemTearOff;
    typedef Vector<RefPtr<ListItemTearOff> > ListWrapperCache;

    SVGProperty* baseVal()
    {
        if (!m_baseVal)
            m_baseVal = SVGListPropertyTearOff<PropertyType>::create(this, BaseValRole);
        return m_baseVal.get();
    }

    SVGProperty* animVal()
    {
        if (!m_animVal)
            m_animVal = SVGListPropertyTearOff<PropertyType>::create(this, AnimValRole);
        return m_animVal.get();
    }

    virtual bool isAnimatedListTearOff() const { return true; }

    int removeItemFromList(SVGProperty* property, bool shouldSynchronizeWrappers)
    {
        // This should ever be called for our baseVal, as animVal can't modify the list.
        typedef SVGPropertyTearOff<typename SVGPropertyTraits<PropertyType>::ListItemType> ListItemTearOff;
        return static_pointer_cast<SVGListPropertyTearOff<PropertyType> >(m_baseVal)->removeItemFromList(static_cast<ListItemTearOff*>(property), shouldSynchronizeWrappers);
    }

    void detachListWrappers(unsigned newListSize)
    {
        // See SVGPropertyTearOff::detachWrapper() for an explaination what's happening here.
        unsigned size = m_wrappers.size();
        ASSERT(size == m_values.size());
        for (unsigned i = 0; i < size; ++i) {
            RefPtr<ListItemTearOff>& item = m_wrappers.at(i);
            if (!item)
                continue;
            item->detachWrapper();
        }

        // Reinitialize the wrapper cache to be equal to the new values size, after the XML DOM changed the list.
        if (newListSize)
            m_wrappers.fill(0, newListSize);
        else
            m_wrappers.clear();
    }

    PropertyType& values() { return m_values; }
    ListWrapperCache& wrappers() { return m_wrappers; }

    // FIXME: animVal support.
    bool isAnimating() const { return false; }
    PropertyType& currentAnimatedValue() { return m_values; }

    static PassRefPtr<SVGAnimatedListPropertyTearOff<PropertyType> > create(SVGElement* contextElement, const QualifiedName& attributeName, PropertyType& values)
    {
        ASSERT(contextElement);
        return adoptRef(new SVGAnimatedListPropertyTearOff<PropertyType>(contextElement, attributeName, values));
    }

protected:
    SVGAnimatedListPropertyTearOff(SVGElement* contextElement, const QualifiedName& attributeName, PropertyType& values)
        : SVGAnimatedProperty(contextElement, attributeName)
        , m_values(values)
    {
        if (!values.isEmpty())
            m_wrappers.fill(0, values.size());
    }

    PropertyType& m_values;

    // FIXME: The list wrapper cache is shared between baseVal/animVal. If we implement animVal,
    // we need two seperated wrapper caches if the attribute gets animated.
    ListWrapperCache m_wrappers;

    RefPtr<SVGProperty> m_baseVal;
    RefPtr<SVGProperty> m_animVal;
};

}

#endif // ENABLE(SVG)
#endif // SVGAnimatedListPropertyTearOff_h
