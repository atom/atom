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

#ifndef SVGAnimatedTransformList_h
#define SVGAnimatedTransformList_h

#if ENABLE(SVG)
#include "SVGAnimatedTransformListPropertyTearOff.h"

namespace WebCore {

typedef SVGAnimatedTransformListPropertyTearOff SVGAnimatedTransformList;

// Helper macros to declare/define a SVGAnimatedTransformList object
#define DECLARE_ANIMATED_TRANSFORM_LIST(UpperProperty, LowerProperty) \
DECLARE_ANIMATED_LIST_PROPERTY(SVGAnimatedTransformList, SVGTransformList, UpperProperty, LowerProperty)

#define DEFINE_ANIMATED_TRANSFORM_LIST(OwnerType, DOMAttribute, UpperProperty, LowerProperty) \
DEFINE_ANIMATED_PROPERTY(AnimatedTransformList, OwnerType, DOMAttribute, DOMAttribute.localName(), UpperProperty, LowerProperty)

} // namespace WebCore

#endif // ENABLE(SVG)
#endif
