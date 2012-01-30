/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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

#ifndef GraphicsLayerClient_h
#define GraphicsLayerClient_h

#if USE(ACCELERATED_COMPOSITING)

namespace WebCore {

class GraphicsContext;
class GraphicsLayer;
class IntPoint;
class IntRect;
class FloatPoint;

enum GraphicsLayerPaintingPhase {
    GraphicsLayerPaintBackground = (1 << 0),
    GraphicsLayerPaintForeground = (1 << 1),
    GraphicsLayerPaintMask = (1 << 2),
    GraphicsLayerPaintAll = (GraphicsLayerPaintBackground | GraphicsLayerPaintForeground | GraphicsLayerPaintMask)
};

enum AnimatedPropertyID {
    AnimatedPropertyInvalid,
    AnimatedPropertyWebkitTransform,
    AnimatedPropertyOpacity,
    AnimatedPropertyBackgroundColor
};

class GraphicsLayerClient {
public:
    virtual ~GraphicsLayerClient() {}

    virtual bool shouldUseTileCache(const GraphicsLayer*) const { return false; }
    
    // Callback for when hardware-accelerated animation started.
    virtual void notifyAnimationStarted(const GraphicsLayer*, double time) = 0;

    // Notification that a layer property changed that requires a subsequent call to syncCompositingState()
    // to appear on the screen.
    virtual void notifySyncRequired(const GraphicsLayer*) = 0;
    
    virtual void paintContents(const GraphicsLayer*, GraphicsContext&, GraphicsLayerPaintingPhase, const IntRect& inClip) = 0;
    virtual void didCommitChangesForLayer(const GraphicsLayer*) const { }

    // Multiplier for backing store size, related to high DPI.
    virtual float deviceScaleFactor() const { return 1; }
    // Page scale factor.
    virtual float pageScaleFactor() const { return 1; }

    virtual bool showDebugBorders(const GraphicsLayer*) const = 0;
    virtual bool showRepaintCounter(const GraphicsLayer*) const = 0;
};

} // namespace WebCore

#endif // USE(ACCELERATED_COMPOSITING)

#endif // GraphicsLayerClient_h
