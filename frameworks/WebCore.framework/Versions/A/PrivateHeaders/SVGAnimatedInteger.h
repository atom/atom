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

#ifndef SVGAnimatedInteger_h
#define SVGAnimatedInteger_h

#if ENABLE(SVG)
#include "SVGAnimatedPropertyMacros.h"
#include "SVGAnimatedStaticPropertyTearOff.h"
#include "SVGAnimatedTypeAnimator.h"

namespace WebCore {

typedef SVGAnimatedStaticPropertyTearOff<long> SVGAnimatedInteger;

// Helper macros to declare/define a SVGAnimatedInteger object
#define DECLARE_ANIMATED_INTEGER(UpperProperty, LowerProperty) \
DECLARE_ANIMATED_PROPERTY(SVGAnimatedInteger, long, UpperProperty, LowerProperty)

#define DEFINE_ANIMATED_INTEGER(OwnerType, DOMAttribute, UpperProperty, LowerProperty) \
DEFINE_ANIMATED_PROPERTY(AnimatedInteger, OwnerType, DOMAttribute, DOMAttribute.localName(), UpperProperty, LowerProperty)

// FIXME: This currently animates as number-optional-number, instead of integer-optional-integer, which is missing.
#define DEFINE_ANIMATED_INTEGER_MULTIPLE_WRAPPERS(OwnerType, DOMAttribute, SVGDOMAttributeIdentifier, UpperProperty, LowerProperty) \
DEFINE_ANIMATED_PROPERTY(AnimatedNumberOptionalNumber, OwnerType, DOMAttribute, SVGDOMAttributeIdentifier, UpperProperty, LowerProperty)

class SVGAnimationElement;

class SVGAnimatedIntegerAnimator : public SVGAnimatedTypeAnimator {
    
public:
    SVGAnimatedIntegerAnimator(SVGAnimationElement*, SVGElement*);
    virtual ~SVGAnimatedIntegerAnimator() { }
    
    static void calculateAnimatedNumber(SVGAnimationElement*, float percentage, unsigned repeatCount, float& animatedNumber, float fromNumber, float toNumber);
    
    virtual PassOwnPtr<SVGAnimatedType> constructFromString(const String&);
    
    virtual void calculateFromAndToValues(OwnPtr<SVGAnimatedType>& fromValue, OwnPtr<SVGAnimatedType>& toValue, const String& fromString, const String& toString);
    virtual void calculateFromAndByValues(OwnPtr<SVGAnimatedType>& fromValue, OwnPtr<SVGAnimatedType>& toValue, const String& fromString, const String& byString);
    virtual void calculateAnimatedValue(float percentage, unsigned repeatCount,
                                        OwnPtr<SVGAnimatedType>& fromValue, OwnPtr<SVGAnimatedType>& toValue, OwnPtr<SVGAnimatedType>& animatedValue);
    virtual float calculateDistance(const String& fromString, const String& toString);
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif
