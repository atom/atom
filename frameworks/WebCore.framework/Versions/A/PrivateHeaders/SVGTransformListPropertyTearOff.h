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

#ifndef SVGTransformListPropertyTearOff_h
#define SVGTransformListPropertyTearOff_h

#if ENABLE(SVG)
#include "SVGListPropertyTearOff.h"
#include "SVGTransformList.h"

namespace WebCore {

// SVGTransformList contains two additional methods, that can be exposed to the bindings.
class SVGTransformListPropertyTearOff : public SVGListPropertyTearOff<SVGTransformList> {
public:
    typedef SVGAnimatedListPropertyTearOff<SVGTransformList> AnimatedListPropertyTearOff;
    typedef SVGAnimatedListPropertyTearOff<SVGTransformList>::ListWrapperCache ListWrapperCache;

    static PassRefPtr<SVGListPropertyTearOff<SVGTransformList> > create(AnimatedListPropertyTearOff* animatedProperty, SVGPropertyRole role)
    {
        ASSERT(animatedProperty);
        return adoptRef(new SVGTransformListPropertyTearOff(animatedProperty, role));
    }

    PassRefPtr<SVGPropertyTearOff<SVGTransform> > createSVGTransformFromMatrix(SVGPropertyTearOff<SVGMatrix>* matrix, ExceptionCode& ec)
    {
        if (!matrix) {
            ec = TYPE_MISMATCH_ERR;
            return 0;
        }
        SVGTransformList& values = m_animatedProperty->values();
        return SVGPropertyTearOff<SVGTransform>::create(values.createSVGTransformFromMatrix(matrix->propertyReference()));
    }

    PassRefPtr<SVGPropertyTearOff<SVGTransform> > consolidate(ExceptionCode& ec)
    {
        if (!canAlterList(ec))
            return 0;

        SVGTransformList& values = m_animatedProperty->values();
        ListWrapperCache& wrappers = m_animatedProperty->wrappers();
        ASSERT(values.size() == wrappers.size());

        // Spec: If the list was empty, then a value of null is returned.
        if (values.isEmpty())
            return 0;

        m_animatedProperty->detachListWrappers(0);
        RefPtr<SVGPropertyTearOff<SVGTransform> > wrapper = SVGPropertyTearOff<SVGTransform>::create(values.consolidate());
        wrappers.append(wrapper);

        ASSERT(values.size() == wrappers.size());
        return wrapper.release();
    }

private:
    SVGTransformListPropertyTearOff(AnimatedListPropertyTearOff* animatedProperty, SVGPropertyRole role)
        : SVGListPropertyTearOff<SVGTransformList>(animatedProperty, role)
    {
    }

};

}

#endif // ENABLE(SVG)
#endif // SVGListPropertyTearOff_h
