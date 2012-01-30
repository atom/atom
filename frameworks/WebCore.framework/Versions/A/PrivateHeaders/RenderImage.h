/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2006 Allan Sandfeld Jensen (kde@carewolf.com) 
 *           (C) 2006 Samuel Weinig (sam.weinig@gmail.com)
 * Copyright (C) 2004, 2005, 2006, 2007, 2009, 2010, 2011 Apple Inc. All rights reserved.
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

#ifndef RenderImage_h
#define RenderImage_h

#include "RenderImageResource.h"
#include "RenderReplaced.h"

namespace WebCore {

class HTMLAreaElement;
class HTMLMapElement;

class RenderImage : public RenderReplaced {
public:
    RenderImage(Node*);
    virtual ~RenderImage();

    void setImageResource(PassOwnPtr<RenderImageResource>);

    RenderImageResource* imageResource() { return m_imageResource.get(); }
    const RenderImageResource* imageResource() const { return m_imageResource.get(); }
    CachedImage* cachedImage() const { return m_imageResource ? m_imageResource->cachedImage() : 0; }

    bool setImageSizeForAltText(CachedImage* newImage = 0);

    void updateAltText();

    HTMLMapElement* imageMap() const;
    void areaElementFocusChanged(HTMLAreaElement*);

    void highQualityRepaintTimerFired(Timer<RenderImage>*);

    void setIsGeneratedContent(bool generated = true) { m_isGeneratedContent = generated; }

    bool isGeneratedContent() const { return m_isGeneratedContent; }

protected:
    virtual bool needsPreferredWidthsRecalculation() const;
    virtual RenderBox* embeddedContentBox() const;
    virtual void computeIntrinsicRatioInformation(FloatSize& intrinsicSize, double& intrinsicRatio, bool& isPercentageIntrinsicSize) const;

    virtual void styleDidChange(StyleDifference, const RenderStyle*);

    virtual void imageChanged(WrappedImagePtr, const IntRect* = 0);

    virtual void paintIntoRect(GraphicsContext*, const LayoutRect&);
    virtual void paint(PaintInfo&, const LayoutPoint&);

    virtual void intrinsicSizeChanged()
    {
        if (m_imageResource)
            imageChanged(m_imageResource->imagePtr());
    }

private:
    virtual const char* renderName() const { return "RenderImage"; }

    virtual bool isImage() const { return true; }
    virtual bool isRenderImage() const { return true; }

    virtual void paintReplaced(PaintInfo&, const LayoutPoint&);

    virtual bool backgroundIsObscured() const;

    virtual int minimumReplacedHeight() const;

    virtual void notifyFinished(CachedResource*);
    virtual bool nodeAtPoint(const HitTestRequest&, HitTestResult&, const LayoutPoint& pointInContainer, const LayoutPoint& accumulatedOffset, HitTestAction);

    virtual LayoutUnit computeReplacedLogicalWidth(bool includeMaxWidth = true) const;

    IntSize imageSizeForError(CachedImage*) const;
    void imageDimensionsChanged(bool imageSizeChanged, const IntRect* = 0);
    bool updateIntrinsicSizeIfNeeded(const LayoutSize&, bool imageSizeChanged);

    void paintAreaElementFocusRing(PaintInfo&);

    // Text to display as long as the image isn't available.
    String m_altText;
    OwnPtr<RenderImageResource> m_imageResource;
    bool m_needsToSetSizeForAltText;
    bool m_didIncrementVisuallyNonEmptyPixelCount;
    bool m_isGeneratedContent;

    friend class RenderImageScaleObserver;
};

inline RenderImage* toRenderImage(RenderObject* object)
{
    ASSERT(!object || object->isRenderImage());
    return static_cast<RenderImage*>(object);
}

inline const RenderImage* toRenderImage(const RenderObject* object)
{
    ASSERT(!object || object->isRenderImage());
    return static_cast<const RenderImage*>(object);
}

// This will catch anyone doing an unnecessary cast.
void toRenderImage(const RenderImage*);

} // namespace WebCore

#endif // RenderImage_h
