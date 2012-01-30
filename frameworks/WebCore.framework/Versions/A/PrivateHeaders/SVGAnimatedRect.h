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

#ifndef SVGAnimatedRect_h
#define SVGAnimatedRect_h

#if ENABLE(SVG)
#include "SVGAnimatedPropertyMacros.h"
#include "SVGAnimatedPropertyTearOff.h"
#include "SVGAnimatedTypeAnimator.h"
#include "SVGRect.h"

namespace WebCore {

typedef SVGAnimatedPropertyTearOff<FloatRect> SVGAnimatedRect;

// Helper macros to declare/define a SVGAnimatedRect object
#define DECLARE_ANIMATED_RECT(UpperProperty, LowerProperty) \
DECLARE_ANIMATED_PROPERTY(SVGAnimatedRect, FloatRect, UpperProperty, LowerProperty)

#define DEFINE_ANIMATED_RECT(OwnerType, DOMAttribute, UpperProperty, LowerProperty) \
DEFINE_ANIMATED_PROPERTY(AnimatedRect, OwnerType, DOMAttribute, DOMAttribute.localName(), UpperProperty, LowerProperty)

class SVGAnimationElement;

class SVGAnimatedRectAnimator : public SVGAnimatedTypeAnimator {

public:
    SVGAnimatedRectAnimator(SVGAnimationElement*, SVGElement*);
    virtual ~SVGAnimatedRectAnimator() { }

    virtual PassOwnPtr<SVGAnimatedType> constructFromString(const String&);

    virtual void calculateFromAndToValues(OwnPtr<SVGAnimatedType>& fromValue, OwnPtr<SVGAnimatedType>& toValue, const String& fromString, const String& toString);
    virtual void calculateFromAndByValues(OwnPtr<SVGAnimatedType>& fromValue, OwnPtr<SVGAnimatedType>& toValue, const String& fromString, const String& byString);
    virtual void calculateAnimatedValue(float percentage, unsigned repeatCount,
                                        OwnPtr<SVGAnimatedType>& fromValue, OwnPtr<SVGAnimatedType>& toValue, OwnPtr<SVGAnimatedType>& animatedValue);
    virtual float calculateDistance(const String& fromString, const String& toString);

    static bool parseSVGRect(const String&, FloatRect&);
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif
