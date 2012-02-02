/*
    Copyright (C) 1998 Lars Knoll (knoll@mpi-hd.mpg.de)
    Copyright (C) 2001 Dirk Mueller <mueller@kde.org>
    Copyright (C) 2006 Samuel Weinig (sam.weinig@gmail.com)
    Copyright (C) 2004, 2005, 2006, 2007 Apple Inc. All rights reserved.

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this library; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

#ifndef CachedImage_h
#define CachedImage_h

#include "CachedResource.h"
#include "CachedResourceClient.h"
#include "SVGImageCache.h"
#include "ImageObserver.h"
#include "IntRect.h"
#include "Timer.h"
#include <wtf/Vector.h>

namespace WebCore {

class CachedResourceLoader;
class FloatSize;
class MemoryCache;
class RenderObject;
struct Length;

class CachedImage : public CachedResource, public ImageObserver {
    friend class MemoryCache;

public:
    CachedImage(const ResourceRequest&);
    CachedImage(Image*);
    virtual ~CachedImage();
    
    virtual void load(CachedResourceLoader*, const ResourceLoaderOptions&);

    Image* image(); // Returns the nullImage() if the image is not available yet.
    Image* imageForRenderer(const RenderObject*); // Returns the nullImage() if the image is not available yet.
    bool hasImage() const { return m_image.get(); }

    std::pair<Image*, float> brokenImage(float deviceScaleFactor) const; // Returns an image and the image's resolution scale factor.
    bool willPaintBrokenImage() const; 

    bool canRender(const RenderObject* renderer, float multiplier) { return !errorOccurred() && !imageSizeForRenderer(renderer, multiplier).isEmpty(); }

    void setContainerSizeForRenderer(const RenderObject*, const IntSize&, float);
    bool usesImageContainerSize() const;
    bool imageHasRelativeWidth() const;
    bool imageHasRelativeHeight() const;
    
    // This method takes a zoom multiplier that can be used to increase the natural size of the image by the zoom.
    IntSize imageSizeForRenderer(const RenderObject*, float multiplier); // returns the size of the complete image.
    void computeIntrinsicDimensions(Length& intrinsicWidth, Length& intrinsicHeight, FloatSize& intrinsicRatio);

    void removeClientForRenderer(RenderObject*);
    virtual void didAddClient(CachedResourceClient*);
    
    virtual void allClientsRemoved();
    virtual void destroyDecodedData();

    virtual void data(PassRefPtr<SharedBuffer> data, bool allDataReceived);
    virtual void error(CachedResource::Status);
    virtual void setResponse(const ResourceResponse&);
    
    // For compatibility, images keep loading even if there are HTTP errors.
    virtual bool shouldIgnoreHTTPStatusCodeErrors() const { return true; }

    virtual bool isImage() const { return true; }
    bool stillNeedsLoad() const { return !errorOccurred() && status() == Unknown && !isLoading(); }
    void load();

    // ImageObserver
    virtual void decodedSizeChanged(const Image* image, int delta);
    virtual void didDraw(const Image*);

    virtual bool shouldPauseAnimation(const Image*);
    virtual void animationAdvanced(const Image*);
    virtual void changedInRect(const Image*, const IntRect&);

private:
    Image* lookupOrCreateImageForRenderer(const RenderObject*);

    void clear();

    void createImage();
    size_t maximumDecodedImageSize();
    // If not null, changeRect is the changed part of the image.
    void notifyObservers(const IntRect* changeRect = 0);
    void decodedDataDeletionTimerFired(Timer<CachedImage>*);
    virtual PurgePriority purgePriority() const { return PurgeFirst; }
    void checkShouldPaintBrokenImage();

    RefPtr<Image> m_image;
#if ENABLE(SVG)
    OwnPtr<SVGImageCache> m_svgImageCache;
#endif
    Timer<CachedImage> m_decodedDataDeletionTimer;
    bool m_shouldPaintBrokenImage;
};

class CachedImageClient : public CachedResourceClient {
public:
    virtual ~CachedImageClient() { }
    static CachedResourceClientType expectedType() { return ImageType; }
    virtual CachedResourceClientType resourceClientType() { return expectedType(); }

    // Called whenever a frame of an image changes, either because we got more data from the network or
    // because we are animating. If not null, the IntRect is the changed rect of the image.
    virtual void imageChanged(CachedImage*, const IntRect* = 0) { }

    // Called to find out if this client wants to actually display the image. Used to tell when we
    // can halt animation. Content nodes that hold image refs for example would not render the image,
    // but RenderImages would (assuming they have visibility: visible and their render tree isn't hidden
    // e.g., in the b/f cache or in a background tab).
    virtual bool willRenderImage(CachedImage*) { return false; }
};

}

#endif
