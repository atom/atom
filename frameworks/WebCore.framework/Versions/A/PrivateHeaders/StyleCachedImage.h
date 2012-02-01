/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
 *           (C) 2000 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
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
 *
 */

#ifndef StyleCachedImage_h
#define StyleCachedImage_h

#include "CachedResourceHandle.h"
#include "StyleImage.h"

namespace WebCore {

class CachedImage;

class StyleCachedImage : public StyleImage {
public:
    static PassRefPtr<StyleCachedImage> create(CachedImage* image) { return adoptRef(new StyleCachedImage(image)); }
    virtual WrappedImagePtr data() const { return m_image.get(); }

    virtual PassRefPtr<CSSValue> cssValue() const;
    
    CachedImage* cachedImage() const { return m_image.get(); }

    virtual bool canRender(const RenderObject*, float multiplier) const;
    virtual bool isLoaded() const;
    virtual bool errorOccurred() const;
    virtual IntSize imageSize(const RenderObject*, float multiplier) const;
    virtual bool imageHasRelativeWidth() const;
    virtual bool imageHasRelativeHeight() const;
    virtual void computeIntrinsicDimensions(const RenderObject*, Length& intrinsicWidth, Length& intrinsicHeight, FloatSize& intrinsicRatio);
    virtual bool usesImageContainerSize() const;
    virtual void setContainerSizeForRenderer(const RenderObject*, const IntSize&, float);
    virtual void addClient(RenderObject*);
    virtual void removeClient(RenderObject*);
    virtual PassRefPtr<Image> image(RenderObject*, const IntSize&) const;
    
private:
    StyleCachedImage(CachedImage* image)
        : m_image(image)
    {
         m_isCachedImage = true;
    }
    
    CachedResourceHandle<CachedImage> m_image;
};

}
#endif
