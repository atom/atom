/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005 Rob Buis <buis@kde.org>
 * Copyright (C) Research In Motion Limited 2010-2011. All rights reserved.
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

#ifndef SVGAnimatedPropertyMacros_h
#define SVGAnimatedPropertyMacros_h

#if ENABLE(SVG)
#include "SVGAttributeToPropertyMap.h"
#include "SVGPropertyTraits.h"
#include <wtf/StdLibExtras.h>

namespace WebCore {

// IsDerivedFromSVGElement implementation
template<typename OwnerType>
struct IsDerivedFromSVGElement {
    static const bool value = true;
};

class SVGTests;
template<>
struct IsDerivedFromSVGElement<SVGTests> {
    static const bool value = false;
};

class SVGViewSpec;
template<>
struct IsDerivedFromSVGElement<SVGViewSpec> {
    static const bool value = false;
};

// SVGSynchronizableAnimatedProperty implementation
template<typename PropertyType>
struct SVGSynchronizableAnimatedProperty {
    SVGSynchronizableAnimatedProperty()
        : value(SVGPropertyTraits<PropertyType>::initialValue())
        , shouldSynchronize(false)
    {
    }

    template<typename ConstructorParameter1>
    SVGSynchronizableAnimatedProperty(const ConstructorParameter1& value1)
        : value(value1)
        , shouldSynchronize(false)
    {
    }

    template<typename ConstructorParameter1, typename ConstructorParameter2>
    SVGSynchronizableAnimatedProperty(const ConstructorParameter1& value1, const ConstructorParameter2& value2)
        : value(value1, value2)
        , shouldSynchronize(false)
    {
    }

    PropertyType value;
    bool shouldSynchronize : 1;
};

// Property registration helpers
#define BEGIN_REGISTER_ANIMATED_PROPERTIES(OwnerType) \
SVGAttributeToPropertyMap& OwnerType::attributeToPropertyMap() \
{ \
    DEFINE_STATIC_LOCAL(SVGAttributeToPropertyMap, s_attributeToPropertyMap, ()); \
    return s_attributeToPropertyMap; \
} \
\
static void registerAnimatedPropertiesFor##OwnerType() \
{ \
    SVGAttributeToPropertyMap& map = OwnerType::attributeToPropertyMap(); \
    if (!map.isEmpty()) \
        return; \
    typedef OwnerType UseOwnerType;

#define REGISTER_LOCAL_ANIMATED_PROPERTY(LowerProperty) \
     map.addProperty(UseOwnerType::LowerProperty##PropertyInfo());

#define REGISTER_PARENT_ANIMATED_PROPERTIES(ClassName) \
     map.addProperties(ClassName::attributeToPropertyMap()); \

#define END_REGISTER_ANIMATED_PROPERTIES }

// Property definition helpers (used in SVG*.cpp files)
#define DEFINE_ANIMATED_PROPERTY(AnimatedPropertyTypeEnum, OwnerType, DOMAttribute, SVGDOMAttributeIdentifier, UpperProperty, LowerProperty) \
const SVGPropertyInfo* OwnerType::LowerProperty##PropertyInfo() { \
    DEFINE_STATIC_LOCAL(const SVGPropertyInfo, s_propertyInfo, \
                        (AnimatedPropertyTypeEnum, \
                         DOMAttribute, \
                         SVGDOMAttributeIdentifier, \
                         &OwnerType::synchronize##UpperProperty, \
                         &OwnerType::lookupOrCreate##UpperProperty##Wrapper)); \
    return &s_propertyInfo; \
} 

// Property declaration helpers (used in SVG*.h files)
#define BEGIN_DECLARE_ANIMATED_PROPERTIES(OwnerType) \
public: \
    static SVGAttributeToPropertyMap& attributeToPropertyMap(); \
    virtual SVGAttributeToPropertyMap& localAttributeToPropertyMap() \
    { \
        return attributeToPropertyMap(); \
    } \
    typedef OwnerType UseOwnerType;

#define DECLARE_ANIMATED_PROPERTY(TearOffType, PropertyType, UpperProperty, LowerProperty) \
public: \
    static const SVGPropertyInfo* LowerProperty##PropertyInfo(); \
    PropertyType& LowerProperty() const \
    { \
        if (TearOffType* wrapper = SVGAnimatedProperty::lookupWrapper<UseOwnerType, TearOffType, IsDerivedFromSVGElement<UseOwnerType>::value>(this, LowerProperty##PropertyInfo())) { \
            if (wrapper->isAnimating()) \
                return wrapper->currentAnimatedValue(); \
        } \
        return m_##LowerProperty.value; \
    } \
\
    PropertyType& LowerProperty##BaseValue() const \
    { \
        return m_##LowerProperty.value; \
    } \
\
    void set##UpperProperty##BaseValue(const PropertyType& type) \
    { \
        m_##LowerProperty.value = type; \
    } \
\
    PassRefPtr<TearOffType> LowerProperty##Animated() \
    { \
        m_##LowerProperty.shouldSynchronize = true; \
        return static_pointer_cast<TearOffType>(lookupOrCreate##UpperProperty##Wrapper(this)); \
    } \
\
private: \
    void synchronize##UpperProperty() \
    { \
        if (!m_##LowerProperty.shouldSynchronize) \
            return; \
        AtomicString value(SVGPropertyTraits<PropertyType>::toString(m_##LowerProperty.value)); \
        SVGAnimatedPropertySynchronizer<IsDerivedFromSVGElement<UseOwnerType>::value>::synchronize(this, LowerProperty##PropertyInfo()->attributeName, value); \
    } \
\
    static PassRefPtr<SVGAnimatedProperty> lookupOrCreate##UpperProperty##Wrapper(void* maskedOwnerType) \
    { \
        ASSERT(maskedOwnerType); \
        UseOwnerType* ownerType = static_cast<UseOwnerType*>(maskedOwnerType); \
        return SVGAnimatedProperty::lookupOrCreateWrapper<UseOwnerType, TearOffType, PropertyType, IsDerivedFromSVGElement<UseOwnerType>::value>(ownerType, LowerProperty##PropertyInfo(), ownerType->m_##LowerProperty.value); \
    } \
\
    static void synchronize##UpperProperty(void* maskedOwnerType) \
    { \
        ASSERT(maskedOwnerType); \
        UseOwnerType* ownerType = static_cast<UseOwnerType*>(maskedOwnerType); \
        ownerType->synchronize##UpperProperty(); \
    } \
\
    mutable SVGSynchronizableAnimatedProperty<PropertyType> m_##LowerProperty;

#define END_DECLARE_ANIMATED_PROPERTIES 

// List specific definition/declaration helpers
#define DECLARE_ANIMATED_LIST_PROPERTY(TearOffType, PropertyType, UpperProperty, LowerProperty) \
DECLARE_ANIMATED_PROPERTY(TearOffType, PropertyType, UpperProperty, LowerProperty) \
void detachAnimated##UpperProperty##ListWrappers(unsigned newListSize) \
{ \
    if (TearOffType* wrapper = SVGAnimatedProperty::lookupWrapper<UseOwnerType, TearOffType, IsDerivedFromSVGElement<UseOwnerType>::value>(this, LowerProperty##PropertyInfo())) \
        wrapper->detachListWrappers(newListSize); \
}

}

#endif // ENABLE(SVG)
#endif // SVGAnimatedPropertyMacros_h
