/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef PlatformCALayerClient_h
#define PlatformCALayerClient_h

#if USE(ACCELERATED_COMPOSITING)

#include "GraphicsContext.h"
#include "GraphicsLayer.h"
#include "PlatformCAAnimation.h"
#include "PlatformString.h"
#include <wtf/HashMap.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RetainPtr.h>
#include <wtf/Vector.h>
#include <wtf/text/StringHash.h>

namespace WebCore {

class PlatformCALayer;

class PlatformCALayerClient {
public:
    virtual void platformCALayerLayoutSublayersOfLayer(PlatformCALayer*) = 0;
    virtual bool platformCALayerRespondsToLayoutChanges() const = 0;

    virtual void platformCALayerAnimationStarted(CFTimeInterval beginTime) = 0;
    virtual GraphicsLayer::CompositingCoordinatesOrientation platformCALayerContentsOrientation() const = 0;
    virtual void platformCALayerPaintContents(GraphicsContext&, const IntRect& inClip) = 0;
    virtual bool platformCALayerShowDebugBorders() const = 0;
    virtual bool platformCALayerShowRepaintCounter() const = 0;
    virtual int platformCALayerIncrementRepaintCount() = 0;
    
    virtual bool platformCALayerContentsOpaque() const = 0;
    virtual bool platformCALayerDrawsContent() const = 0;
    virtual void platformCALayerLayerDidDisplay(PlatformLayer*) = 0;

protected:
    virtual ~PlatformCALayerClient() {}
};

}

#endif // USE(ACCELERATED_COMPOSITING)

#endif // PlatformCALayerClient_h
