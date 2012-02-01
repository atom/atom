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

#ifndef GraphicsLayer_h
#define GraphicsLayer_h

#if USE(ACCELERATED_COMPOSITING)

#include "Animation.h"
#include "Color.h"
#if ENABLE(CSS_FILTERS)
#include "FilterOperations.h"
#endif
#include "FloatPoint.h"
#include "FloatPoint3D.h"
#include "FloatSize.h"
#include "GraphicsLayerClient.h"
#include "IntRect.h"
#include "TransformationMatrix.h"
#include "TransformOperations.h"
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>

#if PLATFORM(MAC)
OBJC_CLASS CALayer;
typedef CALayer PlatformLayer;
#elif PLATFORM(WIN)
typedef struct _CACFLayer PlatformLayer;
#elif PLATFORM(QT)
#if USE(TEXTURE_MAPPER)
namespace WebCore {
class TextureMapperPlatformLayer;
typedef TextureMapperPlatformLayer PlatformLayer;
};
#else
QT_BEGIN_NAMESPACE
class QGraphicsObject;
QT_END_NAMESPACE
namespace WebCore {
typedef QGraphicsObject PlatformLayer;
}
#endif
#elif PLATFORM(CHROMIUM)
namespace WebCore {
class LayerChromium;
typedef LayerChromium PlatformLayer;
}
#elif PLATFORM(GTK)
#if USE(TEXTURE_MAPPER_CAIRO) || USE(TEXTURE_MAPPER_GL)
namespace WebCore {
class TextureMapperPlatformLayer;
typedef TextureMapperPlatformLayer PlatformLayer;
};
#elif USE(CLUTTER)
typedef struct _ClutterActor ClutterActor;
namespace WebCore {
typedef ClutterActor PlatformLayer;
};
#endif
#else
typedef void* PlatformLayer;
#endif

enum LayerTreeAsTextBehaviorFlags {
    LayerTreeAsTextBehaviorNormal = 0,
    LayerTreeAsTextDebug = 1 << 0, // Dump extra debugging info like layer addresses.
};
typedef unsigned LayerTreeAsTextBehavior;

namespace WebCore {

class FloatPoint3D;
class GraphicsContext;
class Image;
class TextStream;
class TimingFunction;

// Base class for animation values (also used for transitions). Here to
// represent values for properties being animated via the GraphicsLayer,
// without pulling in style-related data from outside of the platform directory.
class AnimationValue {
public:
    AnimationValue(float keyTime, PassRefPtr<TimingFunction> timingFunction = 0)
        : m_keyTime(keyTime)
    {
        if (timingFunction)
            m_timingFunction = timingFunction;
    }
    
    virtual ~AnimationValue() { }

    float keyTime() const { return m_keyTime; }
    const TimingFunction* timingFunction() const { return m_timingFunction.get(); }
    virtual AnimationValue* clone() const = 0;

private:
    float m_keyTime;
    RefPtr<TimingFunction> m_timingFunction;
};

// Used to store one float value of an animation.
class FloatAnimationValue : public AnimationValue {
public:
    FloatAnimationValue(float keyTime, float value, PassRefPtr<TimingFunction> timingFunction = 0)
        : AnimationValue(keyTime, timingFunction)
        , m_value(value)
    {
    }
    virtual AnimationValue* clone() const { return new FloatAnimationValue(*this); }

    float value() const { return m_value; }

private:
    float m_value;
};

// Used to store one transform value in a keyframe list.
class TransformAnimationValue : public AnimationValue {
public:
    TransformAnimationValue(float keyTime, const TransformOperations* value = 0, PassRefPtr<TimingFunction> timingFunction = 0)
        : AnimationValue(keyTime, timingFunction)
    {
        if (value)
            m_value = *value;
    }
    virtual AnimationValue* clone() const { return new TransformAnimationValue(*this); }

    const TransformOperations* value() const { return &m_value; }

private:
    TransformOperations m_value;
};

// Used to store a series of values in a keyframe list. Values will all be of the same type,
// which can be inferred from the property.
class KeyframeValueList {
public:

    KeyframeValueList(AnimatedPropertyID property)
        : m_property(property)
    {
    }

    KeyframeValueList(const KeyframeValueList& other)
        : m_property(other.property())
    {
        for (size_t i = 0; i < other.m_values.size(); ++i)
            m_values.append(other.m_values[i]->clone());
    }

    ~KeyframeValueList()
    {
        deleteAllValues(m_values);
    }

    KeyframeValueList& operator=(const KeyframeValueList& other)
    {
        KeyframeValueList copy(other);
        swap(copy);
        return *this;
    }

    void swap(KeyframeValueList& other)
    {
        std::swap(m_property, other.m_property);
        m_values.swap(other.m_values);
    }

    AnimatedPropertyID property() const { return m_property; }

    size_t size() const { return m_values.size(); }
    const AnimationValue* at(size_t i) const { return m_values.at(i); }
    
    // Insert, sorted by keyTime. Takes ownership of the pointer.
    void insert(const AnimationValue*);
    
protected:
    Vector<const AnimationValue*> m_values;
    AnimatedPropertyID m_property;
};



// GraphicsLayer is an abstraction for a rendering surface with backing store,
// which may have associated transformation and animations.

class GraphicsLayer {
    WTF_MAKE_NONCOPYABLE(GraphicsLayer); WTF_MAKE_FAST_ALLOCATED;
public:
    static PassOwnPtr<GraphicsLayer> create(GraphicsLayerClient*);
    
    virtual ~GraphicsLayer();

    GraphicsLayerClient* client() const { return m_client; }

    // Layer name. Only used to identify layers in debug output
    const String& name() const { return m_name; }
    virtual void setName(const String& name) { m_name = name; }

    GraphicsLayer* parent() const { return m_parent; };
    void setParent(GraphicsLayer*); // Internal use only.
    
    // Returns true if the layer has the given layer as an ancestor (excluding self).
    bool hasAncestor(GraphicsLayer*) const;
    
    const Vector<GraphicsLayer*>& children() const { return m_children; }
    // Returns true if the child list changed.
    virtual bool setChildren(const Vector<GraphicsLayer*>&);

    // Add child layers. If the child is already parented, it will be removed from its old parent.
    virtual void addChild(GraphicsLayer*);
    virtual void addChildAtIndex(GraphicsLayer*, int index);
    virtual void addChildAbove(GraphicsLayer* layer, GraphicsLayer* sibling);
    virtual void addChildBelow(GraphicsLayer* layer, GraphicsLayer* sibling);
    virtual bool replaceChild(GraphicsLayer* oldChild, GraphicsLayer* newChild);

    void removeAllChildren();
    virtual void removeFromParent();

    GraphicsLayer* maskLayer() const { return m_maskLayer; }
    virtual void setMaskLayer(GraphicsLayer* layer) { m_maskLayer = layer; }
    
    // The given layer will replicate this layer and its children; the replica renders behind this layer.
    virtual void setReplicatedByLayer(GraphicsLayer*);
    // Whether this layer is being replicated by another layer.
    bool isReplicated() const { return m_replicaLayer; }
    // The layer that replicates this layer (if any).
    GraphicsLayer* replicaLayer() const { return m_replicaLayer; }

    const FloatPoint& replicatedLayerPosition() const { return m_replicatedLayerPosition; }
    void setReplicatedLayerPosition(const FloatPoint& p) { m_replicatedLayerPosition = p; }

    // Offset is origin of the renderer minus origin of the graphics layer (so either zero or negative).
    IntSize offsetFromRenderer() const { return m_offsetFromRenderer; }
    void setOffsetFromRenderer(const IntSize&);

    // The position of the layer (the location of its top-left corner in its parent)
    const FloatPoint& position() const { return m_position; }
    virtual void setPosition(const FloatPoint& p) { m_position = p; }
    
    // Anchor point: (0, 0) is top left, (1, 1) is bottom right. The anchor point
    // affects the origin of the transforms.
    const FloatPoint3D& anchorPoint() const { return m_anchorPoint; }
    virtual void setAnchorPoint(const FloatPoint3D& p) { m_anchorPoint = p; }

    // The size of the layer.
    const FloatSize& size() const { return m_size; }
    virtual void setSize(const FloatSize& size) { m_size = size; }

    // The boundOrigin affects the offset at which content is rendered, and sublayers are positioned.
    const FloatPoint& boundsOrigin() const { return m_boundsOrigin; }
    virtual void setBoundsOrigin(const FloatPoint& origin) { m_boundsOrigin = origin; }

    const TransformationMatrix& transform() const { return m_transform; }
    virtual void setTransform(const TransformationMatrix& t) { m_transform = t; }

    const TransformationMatrix& childrenTransform() const { return m_childrenTransform; }
    virtual void setChildrenTransform(const TransformationMatrix& t) { m_childrenTransform = t; }

    bool preserves3D() const { return m_preserves3D; }
    virtual void setPreserves3D(bool b) { m_preserves3D = b; }
    
    bool masksToBounds() const { return m_masksToBounds; }
    virtual void setMasksToBounds(bool b) { m_masksToBounds = b; }
    
    bool drawsContent() const { return m_drawsContent; }
    virtual void setDrawsContent(bool b) { m_drawsContent = b; }

    bool contentsAreVisible() const { return m_contentsVisible; }
    virtual void setContentsVisible(bool b) { m_contentsVisible = b; }

    bool acceleratesDrawing() const { return m_acceleratesDrawing; }
    virtual void setAcceleratesDrawing(bool b) { m_acceleratesDrawing = b; }

    // The color used to paint the layer backgrounds
    const Color& backgroundColor() const { return m_backgroundColor; }
    virtual void setBackgroundColor(const Color&);
    virtual void clearBackgroundColor();
    bool backgroundColorSet() const { return m_backgroundColorSet; }

    // opaque means that we know the layer contents have no alpha
    bool contentsOpaque() const { return m_contentsOpaque; }
    virtual void setContentsOpaque(bool b) { m_contentsOpaque = b; }

    bool backfaceVisibility() const { return m_backfaceVisibility; }
    virtual void setBackfaceVisibility(bool b) { m_backfaceVisibility = b; }

    float opacity() const { return m_opacity; }
    virtual void setOpacity(float opacity) { m_opacity = opacity; }

#if ENABLE(CSS_FILTERS)
    const FilterOperations& filters() const { return m_filters; }
    
    // Returns true if filter can be rendered by the compositor
    virtual bool setFilters(const FilterOperations& filters) { m_filters = filters; return true; }
#endif

    // Some GraphicsLayers paint only the foreground or the background content
    GraphicsLayerPaintingPhase paintingPhase() const { return m_paintingPhase; }
    void setPaintingPhase(GraphicsLayerPaintingPhase phase) { m_paintingPhase = phase; }

    virtual void setNeedsDisplay() = 0;
    // mark the given rect (in layer coords) as needing dispay. Never goes deep.
    virtual void setNeedsDisplayInRect(const FloatRect&) = 0;
    
    virtual void setContentsNeedsDisplay() { };

    // Set that the position/size of the contents (image or video).
    IntRect contentsRect() const { return m_contentsRect; }
    virtual void setContentsRect(const IntRect& r) { m_contentsRect = r; }
    
    // Transitions are identified by a special animation name that cannot clash with a keyframe identifier.
    static String animationNameForTransition(AnimatedPropertyID);
    
    // Return true if the animation is handled by the compositing system. If this returns
    // false, the animation will be run by AnimationController.
    // These methods handle both transitions and keyframe animations.
    virtual bool addAnimation(const KeyframeValueList&, const IntSize& /*boxSize*/, const Animation*, const String& /*animationName*/, double /*timeOffset*/)  { return false; }
    virtual void pauseAnimation(const String& /*animationName*/, double /*timeOffset*/) { }
    virtual void removeAnimation(const String& /*animationName*/) { }

    virtual void suspendAnimations(double time);
    virtual void resumeAnimations();
    
    // Layer contents
    virtual void setContentsToImage(Image*) { }
    virtual void setContentsToMedia(PlatformLayer*) { } // video or plug-in
    virtual void setContentsToBackgroundColor(const Color&) { }
    virtual void setContentsToCanvas(PlatformLayer*) { }
    virtual bool hasContentsLayer() const { return false; }

    // Callback from the underlying graphics system to draw layer contents.
    void paintGraphicsLayerContents(GraphicsContext&, const IntRect& clip);
    // Callback from the underlying graphics system when the layer has been displayed
    virtual void layerDidDisplay(PlatformLayer*) { }
    
    // For hosting this GraphicsLayer in a native layer hierarchy.
    virtual PlatformLayer* platformLayer() const { return 0; }
    
    void dumpLayer(TextStream&, int indent = 0, LayerTreeAsTextBehavior = LayerTreeAsTextBehaviorNormal) const;

    int repaintCount() const { return m_repaintCount; }
    int incrementRepaintCount() { return ++m_repaintCount; }

    enum CompositingCoordinatesOrientation { CompositingCoordinatesTopDown, CompositingCoordinatesBottomUp };

    // Flippedness of the contents of this layer. Does not affect sublayer geometry.
    virtual void setContentsOrientation(CompositingCoordinatesOrientation orientation) { m_contentsOrientation = orientation; }
    CompositingCoordinatesOrientation contentsOrientation() const { return m_contentsOrientation; }

    bool showDebugBorders() const { return m_client ? m_client->showDebugBorders(this) : false; }
    bool showRepaintCounter() const { return m_client ? m_client->showRepaintCounter(this) : false; }
    
    void updateDebugIndicators();
    
    virtual void setDebugBackgroundColor(const Color&) { }
    virtual void setDebugBorder(const Color&, float /*borderWidth*/) { }
    // z-position is the z-equivalent of position(). It's only used for debugging purposes.
    virtual float zPosition() const { return m_zPosition; }
    virtual void setZPosition(float);

    virtual void distributeOpacity(float);
    virtual float accumulatedOpacity() const;

    virtual void setMaintainsPixelAlignment(bool maintainsAlignment) { m_maintainsPixelAlignment = maintainsAlignment; }
    virtual bool maintainsPixelAlignment() const { return m_maintainsPixelAlignment; }
    
    void setAppliesPageScale(bool appliesScale = true) { m_appliesPageScale = appliesScale; }
    bool appliesPageScale() const { return m_appliesPageScale; }

    float pageScaleFactor() const { return m_client ? m_client->pageScaleFactor() : 1; }
    float deviceScaleFactor() const { return m_client ? m_client->deviceScaleFactor() : 1; }

    virtual void deviceOrPageScaleFactorChanged() { }
    void noteDeviceOrPageScaleFactorChangedIncludingDescendants();

    // Some compositing systems may do internal batching to synchronize compositing updates
    // with updates drawn into the window. These methods flush internal batched state on this layer
    // and descendant layers, and this layer only.
    virtual void syncCompositingState(const FloatRect& /* clipRect */) { }
    virtual void syncCompositingStateForThisLayerOnly() { }
    
    // Return a string with a human readable form of the layer tree, If debug is true 
    // pointers for the layers and timing data will be included in the returned string.
    String layerTreeAsText(LayerTreeAsTextBehavior = LayerTreeAsTextBehaviorNormal) const;

    bool usingTiledLayer() const { return m_usingTiledLayer; }

#if PLATFORM(QT) || PLATFORM(GTK)
    // This allows several alternative GraphicsLayer implementations in the same port,
    // e.g. if a different GraphicsLayer implementation is needed in WebKit1 vs. WebKit2.
    typedef PassOwnPtr<GraphicsLayer> GraphicsLayerFactory(GraphicsLayerClient*);
    static void setGraphicsLayerFactory(GraphicsLayerFactory);
#endif

protected:
#if ENABLE(CSS_FILTERS)
    // This method is used by platform GraphicsLayer classes to clear the filters
    // when compositing is not done in hardware. It is not virtual, so the caller
    // needs to notifiy the change to the platform layer as needed.
    void clearFilters() { m_filters.clear(); }
#endif

    typedef Vector<TransformOperation::OperationType> TransformOperationList;
    // Given a list of TransformAnimationValues, return an array of transform operations.
    // On return, if hasBigRotation is true, functions contain rotations of >= 180 degrees
    static void fetchTransformOperationList(const KeyframeValueList&, TransformOperationList&, bool& isValid, bool& hasBigRotation);

    virtual void setOpacityInternal(float) { }

    // The layer being replicated.
    GraphicsLayer* replicatedLayer() const { return m_replicatedLayer; }
    virtual void setReplicatedLayer(GraphicsLayer* layer) { m_replicatedLayer = layer; }

    GraphicsLayer(GraphicsLayerClient*);

    void dumpProperties(TextStream&, int indent, LayerTreeAsTextBehavior) const;

    GraphicsLayerClient* m_client;
    String m_name;
    
    // Offset from the owning renderer
    IntSize m_offsetFromRenderer;
    
    // Position is relative to the parent GraphicsLayer
    FloatPoint m_position;
    FloatPoint3D m_anchorPoint;
    FloatSize m_size;
    FloatPoint m_boundsOrigin;

    TransformationMatrix m_transform;
    TransformationMatrix m_childrenTransform;

    Color m_backgroundColor;
    float m_opacity;
    float m_zPosition;
    
#if ENABLE(CSS_FILTERS)
    FilterOperations m_filters;
#endif

    bool m_backgroundColorSet : 1;
    bool m_contentsOpaque : 1;
    bool m_preserves3D: 1;
    bool m_backfaceVisibility : 1;
    bool m_usingTiledLayer : 1;
    bool m_masksToBounds : 1;
    bool m_drawsContent : 1;
    bool m_contentsVisible : 1;
    bool m_acceleratesDrawing : 1;
    bool m_maintainsPixelAlignment : 1;
    bool m_appliesPageScale : 1; // Set for the layer which has the page scale applied to it.

    GraphicsLayerPaintingPhase m_paintingPhase;
    CompositingCoordinatesOrientation m_contentsOrientation; // affects orientation of layer contents

    Vector<GraphicsLayer*> m_children;
    GraphicsLayer* m_parent;

    GraphicsLayer* m_maskLayer; // Reference to mask layer. We don't own this.

    GraphicsLayer* m_replicaLayer; // A layer that replicates this layer. We only allow one, for now.
                                   // The replica is not parented; this is the primary reference to it.
    GraphicsLayer* m_replicatedLayer; // For a replica layer, a reference to the original layer.
    FloatPoint m_replicatedLayerPosition; // For a replica layer, the position of the replica.

    IntRect m_contentsRect;

    int m_repaintCount;

#if PLATFORM(QT) || PLATFORM(GTK)
    static GraphicsLayer::GraphicsLayerFactory* s_graphicsLayerFactory;
#endif
};


} // namespace WebCore

#ifndef NDEBUG
// Outside the WebCore namespace for ease of invocation from gdb.
void showGraphicsLayerTree(const WebCore::GraphicsLayer* layer);
#endif

#endif // USE(ACCELERATED_COMPOSITING)

#endif // GraphicsLayer_h

