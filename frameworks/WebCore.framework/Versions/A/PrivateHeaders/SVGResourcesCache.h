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

#ifndef SVGResourcesCache_h
#define SVGResourcesCache_h

#if ENABLE(SVG)
#include "RenderStyleConstants.h"
#include <wtf/HashMap.h>

namespace WebCore {

class RenderObject;
class RenderStyle;
class RenderSVGResourceContainer;
class SVGResources;

class SVGResourcesCache {
    WTF_MAKE_NONCOPYABLE(SVGResourcesCache); WTF_MAKE_FAST_ALLOCATED;
public:
    SVGResourcesCache();
    ~SVGResourcesCache();

    void addResourcesFromRenderObject(RenderObject*, const RenderStyle*);
    void removeResourcesFromRenderObject(RenderObject*);
    static SVGResources* cachedResourcesForRenderObject(RenderObject*);

    // Called from all SVG renderers destroy() methods - except for RenderSVGResourceContainer.
    static void clientDestroyed(RenderObject*);

    // Called from all SVG renderers layout() methods.
    static void clientLayoutChanged(RenderObject*);

    // Called from all SVG renderers styleDidChange() methods.
    static void clientStyleChanged(RenderObject*, StyleDifference, const RenderStyle* newStyle);

    // Called from all SVG renderers updateFromElement() methods.
    static void clientUpdatedFromElement(RenderObject*, const RenderStyle* newStyle);

    // Called from RenderSVGResourceContainer::willBeDestroyed().
    static void resourceDestroyed(RenderSVGResourceContainer*);

private:
    HashMap<RenderObject*, SVGResources*> m_cache;
};

}

#endif
#endif
