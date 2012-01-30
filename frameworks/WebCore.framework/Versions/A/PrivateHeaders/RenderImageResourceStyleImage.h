/*
 * Copyright (C) 1999 Lars Knoll <knoll@kde.org>
 * Copyright (C) 1999 Antti Koivisto <koivisto@kde.org>
 * Copyright (C) 2006 Allan Sandfeld Jensen <kde@carewolf.com>
 * Copyright (C) 2006 Samuel Weinig <sam.weinig@gmail.com>
 * Copyright (C) 2004, 2005, 2006, 2007, 2009, 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2010 Patrick Gansterer <paroga@paroga.com>
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

#ifndef RenderImageResourceStyleImage_h
#define RenderImageResourceStyleImage_h

#include "RenderImageResource.h"
#include "StyleImage.h"
#include <wtf/RefPtr.h>

namespace WebCore {

class RenderObject;

class RenderImageResourceStyleImage : public RenderImageResource {
public:
    virtual ~RenderImageResourceStyleImage();

    static PassOwnPtr<RenderImageResource> create(StyleImage* styleImage)
    {
        return adoptPtr(new RenderImageResourceStyleImage(styleImage));
    }
    virtual void initialize(RenderObject*);
    virtual void shutdown();

    virtual bool hasImage() const { return true; }
    virtual PassRefPtr<Image> image(int width = 0, int height = 0) const;
    virtual bool errorOccurred() const { return m_styleImage->errorOccurred(); }

    virtual void setContainerSizeForRenderer(const IntSize&);
    virtual bool usesImageContainerSize() const { return m_styleImage->usesImageContainerSize(); }
    virtual bool imageHasRelativeWidth() const { return m_styleImage->imageHasRelativeWidth(); }
    virtual bool imageHasRelativeHeight() const { return m_styleImage->imageHasRelativeHeight(); }

    virtual IntSize imageSize(float multiplier) const { return m_styleImage->imageSize(m_renderer, multiplier); }

    virtual WrappedImagePtr imagePtr() const { return m_styleImage->data(); }

private:
    RenderImageResourceStyleImage(StyleImage*);
    RefPtr<StyleImage> m_styleImage;
};

} // namespace WebCore

#endif // RenderImageStyleImage_h
