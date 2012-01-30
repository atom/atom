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

#ifndef SVGAnimatedProperty_h
#define SVGAnimatedProperty_h

#if ENABLE(SVG)
#include "SVGAnimatedPropertyDescription.h"
#include "SVGElement.h"
#include "SVGPropertyInfo.h"
#include <wtf/RefCounted.h>

namespace WebCore {

class SVGElement;

class SVGAnimatedProperty : public RefCounted<SVGAnimatedProperty> {
public:
    SVGElement* contextElement() const { return m_contextElement.get(); }
    const QualifiedName& attributeName() const { return m_attributeName; }

    void commitChange()
    {
        ASSERT(m_contextElement);
        m_contextElement->invalidateSVGAttributes();
        m_contextElement->svgAttributeChanged(m_attributeName);
    }

    virtual bool isAnimatedListTearOff() const { return false; }
    virtual void updateAnimVal(void*) { ASSERT_NOT_REACHED(); }

    // Caching facilities.
    typedef HashMap<SVGAnimatedPropertyDescription, RefPtr<SVGAnimatedProperty>, SVGAnimatedPropertyDescriptionHash, SVGAnimatedPropertyDescriptionHashTraits> Cache;

    virtual ~SVGAnimatedProperty()
    {
        // Remove wrapper from cache.
        Cache* cache = animatedPropertyCache();
        const Cache::const_iterator end = cache->end();
        for (Cache::const_iterator it = cache->begin(); it != end; ++it) {
            if (it->second == this) {
                cache->remove(it->first);
                break;
            }
        }
    }

    // lookupOrCreateWrapper & helper methods.
    template<typename TearOffType, typename PropertyType, bool isDerivedFromSVGElement>
    struct LookupOrCreateHelper;

    template<typename TearOffType, typename PropertyType>
    struct LookupOrCreateHelper<TearOffType, PropertyType, false> {
        static PassRefPtr<TearOffType> lookupOrCreateWrapper(void*, const SVGPropertyInfo*, PropertyType&)
        {
            ASSERT_NOT_REACHED();
            return PassRefPtr<TearOffType>();
        }
    };

    template<typename TearOffType, typename PropertyType>
    struct LookupOrCreateHelper<TearOffType, PropertyType, true> {
        static PassRefPtr<TearOffType> lookupOrCreateWrapper(SVGElement* element, const SVGPropertyInfo* info, PropertyType& property)
        {
            ASSERT(info);
            SVGAnimatedPropertyDescription key(element, info->propertyIdentifier);
            RefPtr<SVGAnimatedProperty> wrapper = animatedPropertyCache()->get(key);
            if (!wrapper) {
                wrapper = TearOffType::create(element, info->attributeName, property);
                animatedPropertyCache()->set(key, wrapper);
            }
            return static_pointer_cast<TearOffType>(wrapper).release();
        }
    };

    template<typename OwnerType, typename TearOffType, typename PropertyType, bool isDerivedFromSVGElement>
    static PassRefPtr<TearOffType> lookupOrCreateWrapper(OwnerType* element, const SVGPropertyInfo* info, PropertyType& property)
    {
        return LookupOrCreateHelper<TearOffType, PropertyType, isDerivedFromSVGElement>::lookupOrCreateWrapper(element, info, property);
    }

    // lookupWrapper & helper methods.
    template<typename TearOffType, bool isDerivedFromSVGElement>
    struct LookupHelper;

    template<typename TearOffType>
    struct LookupHelper<TearOffType, false> {
        static TearOffType* lookupWrapper(const void*, const SVGPropertyInfo*)
        {
            return 0;
        }
    };

    template<typename TearOffType>
    struct LookupHelper<TearOffType, true> {
        static TearOffType* lookupWrapper(const SVGElement* element, const SVGPropertyInfo* info)
        {
            ASSERT(info);
            SVGAnimatedPropertyDescription key(const_cast<SVGElement*>(element), info->propertyIdentifier);
            return static_pointer_cast<TearOffType>(animatedPropertyCache()->get(key)).get();
        }
    };

    template<typename OwnerType, typename TearOffType, bool isDerivedFromSVGElement>
    static TearOffType* lookupWrapper(const OwnerType* element, const SVGPropertyInfo* info)
    {
        return LookupHelper<TearOffType, isDerivedFromSVGElement>::lookupWrapper(element, info);
    }

protected:
    SVGAnimatedProperty(SVGElement* contextElement, const QualifiedName& attributeName)
        : m_contextElement(contextElement)
        , m_attributeName(attributeName)
    {
    }

private:
    static Cache* animatedPropertyCache()
    {
        static Cache* s_cache = new Cache;                
        return s_cache;
    }

    RefPtr<SVGElement> m_contextElement;
    const QualifiedName& m_attributeName;
};

}

#endif // ENABLE(SVG)
#endif // SVGAnimatedProperty_h
