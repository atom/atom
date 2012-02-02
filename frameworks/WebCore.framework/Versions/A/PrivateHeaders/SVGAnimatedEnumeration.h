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

#ifndef SVGAnimatedEnumeration_h
#define SVGAnimatedEnumeration_h

#if ENABLE(SVG)
#include "SVGAnimatedEnumerationPropertyTearOff.h"
#include "SVGAnimatedPropertyMacros.h"

namespace WebCore {

typedef SVGAnimatedStaticPropertyTearOff<int> SVGAnimatedEnumeration;

// Helper macros to declare/define a SVGAnimatedEnumeration object
#define DECLARE_ANIMATED_ENUMERATION(UpperProperty, LowerProperty, EnumType) \
DECLARE_ANIMATED_PROPERTY(SVGAnimatedEnumerationPropertyTearOff<EnumType>, EnumType, UpperProperty, LowerProperty)

#define DEFINE_ANIMATED_ENUMERATION(OwnerType, DOMAttribute, UpperProperty, LowerProperty, EnumType) \
DEFINE_ANIMATED_PROPERTY(AnimatedEnumeration, OwnerType, DOMAttribute, DOMAttribute.localName(), UpperProperty, LowerProperty)

} // namespace WebCore

#endif // ENABLE(SVG)
#endif
