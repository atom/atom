/*
    Copyright (C) 2004, 2005, 2007 Nikolas Zimmermann <zimmermann@kde.org>
                  2004, 2005 Rob Buis <buis@kde.org>
    Copyright (C) 2005, 2006 Apple Computer, Inc.
    Copyright (C) Research In Motion Limited 2010. All rights reserved.

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

#ifndef SVGRenderStyle_h
#define SVGRenderStyle_h

#if ENABLE(SVG)
#include "CSSValueList.h"
#include "DataRef.h"
#include "GraphicsTypes.h"
#include "Path.h"
#include "RenderStyleConstants.h"
#include "SVGPaint.h"
#include "SVGRenderStyleDefs.h"

namespace WebCore {

class FloatRect;
class IntRect;
class RenderObject;

class SVGRenderStyle : public RefCounted<SVGRenderStyle> {    
public:
    static PassRefPtr<SVGRenderStyle> create() { return adoptRef(new SVGRenderStyle); }
    PassRefPtr<SVGRenderStyle> copy() const { return adoptRef(new SVGRenderStyle(*this));}
    ~SVGRenderStyle();

    bool inheritedNotEqual(const SVGRenderStyle*) const;
    void inheritFrom(const SVGRenderStyle*);
    void copyNonInheritedFrom(const SVGRenderStyle*);

    StyleDifference diff(const SVGRenderStyle*) const;

    bool operator==(const SVGRenderStyle&) const;
    bool operator!=(const SVGRenderStyle& o) const { return !(*this == o); }

    // Initial values for all the properties
    static EAlignmentBaseline initialAlignmentBaseline() { return AB_AUTO; }
    static EDominantBaseline initialDominantBaseline() { return DB_AUTO; }
    static EBaselineShift initialBaselineShift() { return BS_BASELINE; }
    static EVectorEffect initialVectorEffect() { return VE_NONE; }
    static LineCap initialCapStyle() { return ButtCap; }
    static WindRule initialClipRule() { return RULE_NONZERO; }
    static EColorInterpolation initialColorInterpolation() { return CI_SRGB; }
    static EColorInterpolation initialColorInterpolationFilters() { return CI_LINEARRGB; }
    static EColorRendering initialColorRendering() { return CR_AUTO; }
    static WindRule initialFillRule() { return RULE_NONZERO; }
    static LineJoin initialJoinStyle() { return MiterJoin; }
    static EShapeRendering initialShapeRendering() { return SR_AUTO; }
    static ETextAnchor initialTextAnchor() { return TA_START; }
    static SVGWritingMode initialWritingMode() { return WM_LRTB; }
    static EGlyphOrientation initialGlyphOrientationHorizontal() { return GO_0DEG; }
    static EGlyphOrientation initialGlyphOrientationVertical() { return GO_AUTO; }
    static float initialFillOpacity() { return 1; }
    static SVGPaint::SVGPaintType initialFillPaintType() { return SVGPaint::SVG_PAINTTYPE_RGBCOLOR; }
    static Color initialFillPaintColor() { return Color::black; }
    static String initialFillPaintUri() { return String(); }
    static float initialStrokeOpacity() { return 1; }
    static SVGPaint::SVGPaintType initialStrokePaintType() { return SVGPaint::SVG_PAINTTYPE_NONE; }
    static Color initialStrokePaintColor() { return Color(); }
    static String initialStrokePaintUri() { return String(); }
    static Vector<SVGLength> initialStrokeDashArray() { return Vector<SVGLength>(); }
    static float initialStrokeMiterLimit() { return 4; }
    static float initialStopOpacity() { return 1; }
    static Color initialStopColor() { return Color(0, 0, 0); }
    static float initialFloodOpacity() { return 1; }
    static Color initialFloodColor() { return Color(0, 0, 0); }
    static Color initialLightingColor() { return Color(255, 255, 255); }
    static ShadowData* initialShadow() { return 0; }
    static String initialClipperResource() { return String(); }
    static String initialFilterResource() { return String(); }
    static String initialMaskerResource() { return String(); }
    static String initialMarkerStartResource() { return String(); }
    static String initialMarkerMidResource() { return String(); }
    static String initialMarkerEndResource() { return String(); }

    static SVGLength initialBaselineShiftValue()
    {
        SVGLength length;
        ExceptionCode ec = 0;
        length.newValueSpecifiedUnits(LengthTypeNumber, 0, ec);
        ASSERT(!ec);
        return length;
    }

    static SVGLength initialKerning()
    {
        SVGLength length;
        ExceptionCode ec = 0;
        length.newValueSpecifiedUnits(LengthTypeNumber, 0, ec);
        ASSERT(!ec);
        return length;
    }

    static SVGLength initialStrokeDashOffset()
    {
        SVGLength length;
        ExceptionCode ec = 0;
        length.newValueSpecifiedUnits(LengthTypeNumber, 0, ec);
        ASSERT(!ec);
        return length;
    }

    static SVGLength initialStrokeWidth()
    {
        SVGLength length;
        ExceptionCode ec = 0;
        length.newValueSpecifiedUnits(LengthTypeNumber, 1, ec);
        ASSERT(!ec);
        return length;
    }

    // SVG CSS Property setters
    void setAlignmentBaseline(EAlignmentBaseline val) { svg_noninherited_flags.f._alignmentBaseline = val; }
    void setDominantBaseline(EDominantBaseline val) { svg_noninherited_flags.f._dominantBaseline = val; }
    void setBaselineShift(EBaselineShift val) { svg_noninherited_flags.f._baselineShift = val; }
    void setVectorEffect(EVectorEffect val) { svg_noninherited_flags.f._vectorEffect = val; }
    void setCapStyle(LineCap val) { svg_inherited_flags._capStyle = val; }
    void setClipRule(WindRule val) { svg_inherited_flags._clipRule = val; }
    void setColorInterpolation(EColorInterpolation val) { svg_inherited_flags._colorInterpolation = val; }
    void setColorInterpolationFilters(EColorInterpolation val) { svg_inherited_flags._colorInterpolationFilters = val; }
    void setColorRendering(EColorRendering val) { svg_inherited_flags._colorRendering = val; }
    void setFillRule(WindRule val) { svg_inherited_flags._fillRule = val; }
    void setJoinStyle(LineJoin val) { svg_inherited_flags._joinStyle = val; }
    void setShapeRendering(EShapeRendering val) { svg_inherited_flags._shapeRendering = val; }
    void setTextAnchor(ETextAnchor val) { svg_inherited_flags._textAnchor = val; }
    void setWritingMode(SVGWritingMode val) { svg_inherited_flags._writingMode = val; }
    void setGlyphOrientationHorizontal(EGlyphOrientation val) { svg_inherited_flags._glyphOrientationHorizontal = val; }
    void setGlyphOrientationVertical(EGlyphOrientation val) { svg_inherited_flags._glyphOrientationVertical = val; }
    
    void setFillOpacity(float obj)
    {
        if (!(fill->opacity == obj))
            fill.access()->opacity = obj;
    }

    void setFillPaint(SVGPaint::SVGPaintType type, const Color& color, const String& uri, bool applyToRegularStyle = true, bool applyToVisitedLinkStyle = false)
    {
        if (applyToRegularStyle) {
            if (!(fill->paintType == type))
                fill.access()->paintType = type;
            if (!(fill->paintColor == color))
                fill.access()->paintColor = color;
            if (!(fill->paintUri == uri))
                fill.access()->paintUri = uri;
        }
        if (applyToVisitedLinkStyle) {
            if (!(fill->visitedLinkPaintType == type))
                fill.access()->visitedLinkPaintType = type;
            if (!(fill->visitedLinkPaintColor == color))
                fill.access()->visitedLinkPaintColor = color;
            if (!(fill->visitedLinkPaintUri == uri))
                fill.access()->visitedLinkPaintUri = uri;
        }
    }

    void setStrokeOpacity(float obj)
    {
        if (!(stroke->opacity == obj))
            stroke.access()->opacity = obj;
    }

    void setStrokePaint(SVGPaint::SVGPaintType type, const Color& color, const String& uri, bool applyToRegularStyle = true, bool applyToVisitedLinkStyle = false)
    {
        if (applyToRegularStyle) {
            if (!(stroke->paintType == type))
                stroke.access()->paintType = type;
            if (!(stroke->paintColor == color))
                stroke.access()->paintColor = color;
            if (!(stroke->paintUri == uri))
                stroke.access()->paintUri = uri;
        }
        if (applyToVisitedLinkStyle) {
            if (!(stroke->visitedLinkPaintType == type))
                stroke.access()->visitedLinkPaintType = type;
            if (!(stroke->visitedLinkPaintColor == color))
                stroke.access()->visitedLinkPaintColor = color;
            if (!(stroke->visitedLinkPaintUri == uri))
                stroke.access()->visitedLinkPaintUri = uri;
        }
    }

    void setStrokeDashArray(const Vector<SVGLength>& obj)
    {
        if (!(stroke->dashArray == obj))
            stroke.access()->dashArray = obj;
    }

    void setStrokeMiterLimit(float obj)
    {
        if (!(stroke->miterLimit == obj))
            stroke.access()->miterLimit = obj;
    }

    void setStrokeWidth(const SVGLength& obj)
    {
        if (!(stroke->width == obj))
            stroke.access()->width = obj;
    }

    void setStrokeDashOffset(const SVGLength& obj)
    {
        if (!(stroke->dashOffset == obj))
            stroke.access()->dashOffset = obj;
    }

    void setKerning(const SVGLength& obj)
    {
        if (!(text->kerning == obj))
            text.access()->kerning = obj;
    }

    void setStopOpacity(float obj)
    {
        if (!(stops->opacity == obj))
            stops.access()->opacity = obj;
    }

    void setStopColor(const Color& obj)
    {
        if (!(stops->color == obj))
            stops.access()->color = obj;
    }

    void setFloodOpacity(float obj)
    {
        if (!(misc->floodOpacity == obj))
            misc.access()->floodOpacity = obj;
    }

    void setFloodColor(const Color& obj)
    {
        if (!(misc->floodColor == obj))
            misc.access()->floodColor = obj;
    }

    void setLightingColor(const Color& obj)
    {
        if (!(misc->lightingColor == obj))
            misc.access()->lightingColor = obj;
    }

    void setBaselineShiftValue(const SVGLength& obj)
    {
        if (!(misc->baselineShiftValue == obj))
            misc.access()->baselineShiftValue = obj;
    }

    void setShadow(PassOwnPtr<ShadowData> obj) { shadowSVG.access()->shadow = obj; }

    // Setters for non-inherited resources
    void setClipperResource(const String& obj)
    {
        if (!(resources->clipper == obj))
            resources.access()->clipper = obj;
    }

    void setFilterResource(const String& obj)
    {
        if (!(resources->filter == obj))
            resources.access()->filter = obj;
    }

    void setMaskerResource(const String& obj)
    {
        if (!(resources->masker == obj))
            resources.access()->masker = obj;
    }

    // Setters for inherited resources
    void setMarkerStartResource(const String& obj)
    {
        if (!(inheritedResources->markerStart == obj))
            inheritedResources.access()->markerStart = obj;
    }

    void setMarkerMidResource(const String& obj)
    {
        if (!(inheritedResources->markerMid == obj))
            inheritedResources.access()->markerMid = obj;
    }

    void setMarkerEndResource(const String& obj)
    {
        if (!(inheritedResources->markerEnd == obj))
            inheritedResources.access()->markerEnd = obj;
    }

    // Read accessors for all the properties
    EAlignmentBaseline alignmentBaseline() const { return (EAlignmentBaseline) svg_noninherited_flags.f._alignmentBaseline; }
    EDominantBaseline dominantBaseline() const { return (EDominantBaseline) svg_noninherited_flags.f._dominantBaseline; }
    EBaselineShift baselineShift() const { return (EBaselineShift) svg_noninherited_flags.f._baselineShift; }
    EVectorEffect vectorEffect() const { return (EVectorEffect) svg_noninherited_flags.f._vectorEffect; }
    LineCap capStyle() const { return (LineCap) svg_inherited_flags._capStyle; }
    WindRule clipRule() const { return (WindRule) svg_inherited_flags._clipRule; }
    EColorInterpolation colorInterpolation() const { return (EColorInterpolation) svg_inherited_flags._colorInterpolation; }
    EColorInterpolation colorInterpolationFilters() const { return (EColorInterpolation) svg_inherited_flags._colorInterpolationFilters; }
    EColorRendering colorRendering() const { return (EColorRendering) svg_inherited_flags._colorRendering; }
    WindRule fillRule() const { return (WindRule) svg_inherited_flags._fillRule; }
    LineJoin joinStyle() const { return (LineJoin) svg_inherited_flags._joinStyle; }
    EShapeRendering shapeRendering() const { return (EShapeRendering) svg_inherited_flags._shapeRendering; }
    ETextAnchor textAnchor() const { return (ETextAnchor) svg_inherited_flags._textAnchor; }
    SVGWritingMode writingMode() const { return (SVGWritingMode) svg_inherited_flags._writingMode; }
    EGlyphOrientation glyphOrientationHorizontal() const { return (EGlyphOrientation) svg_inherited_flags._glyphOrientationHorizontal; }
    EGlyphOrientation glyphOrientationVertical() const { return (EGlyphOrientation) svg_inherited_flags._glyphOrientationVertical; }
    float fillOpacity() const { return fill->opacity; }
    const SVGPaint::SVGPaintType& fillPaintType() const { return fill->paintType; }
    const Color& fillPaintColor() const { return fill->paintColor; }
    const String& fillPaintUri() const { return fill->paintUri; }    
    float strokeOpacity() const { return stroke->opacity; }
    const SVGPaint::SVGPaintType& strokePaintType() const { return stroke->paintType; }
    const Color& strokePaintColor() const { return stroke->paintColor; }
    const String& strokePaintUri() const { return stroke->paintUri; }
    Vector<SVGLength> strokeDashArray() const { return stroke->dashArray; }
    float strokeMiterLimit() const { return stroke->miterLimit; }
    SVGLength strokeWidth() const { return stroke->width; }
    SVGLength strokeDashOffset() const { return stroke->dashOffset; }
    SVGLength kerning() const { return text->kerning; }
    float stopOpacity() const { return stops->opacity; }
    const Color& stopColor() const { return stops->color; }
    float floodOpacity() const { return misc->floodOpacity; }
    const Color& floodColor() const { return misc->floodColor; }
    const Color& lightingColor() const { return misc->lightingColor; }
    SVGLength baselineShiftValue() const { return misc->baselineShiftValue; }
    ShadowData* shadow() const { return shadowSVG->shadow.get(); }
    String clipperResource() const { return resources->clipper; }
    String filterResource() const { return resources->filter; }
    String maskerResource() const { return resources->masker; }
    String markerStartResource() const { return inheritedResources->markerStart; }
    String markerMidResource() const { return inheritedResources->markerMid; }
    String markerEndResource() const { return inheritedResources->markerEnd; }
    
    const SVGPaint::SVGPaintType& visitedLinkFillPaintType() const { return fill->visitedLinkPaintType; }
    const Color& visitedLinkFillPaintColor() const { return fill->visitedLinkPaintColor; }
    const String& visitedLinkFillPaintUri() const { return fill->visitedLinkPaintUri; }
    const SVGPaint::SVGPaintType& visitedLinkStrokePaintType() const { return stroke->visitedLinkPaintType; }
    const Color& visitedLinkStrokePaintColor() const { return stroke->visitedLinkPaintColor; }
    const String& visitedLinkStrokePaintUri() const { return stroke->visitedLinkPaintUri; }

    // convenience
    bool hasClipper() const { return !clipperResource().isEmpty(); }
    bool hasMasker() const { return !maskerResource().isEmpty(); }
    bool hasFilter() const { return !filterResource().isEmpty(); }
    bool hasMarkers() const { return !markerStartResource().isEmpty() || !markerMidResource().isEmpty() || !markerEndResource().isEmpty(); }
    bool hasStroke() const { return strokePaintType() != SVGPaint::SVG_PAINTTYPE_NONE; }
    bool hasFill() const { return fillPaintType() != SVGPaint::SVG_PAINTTYPE_NONE; }
    bool isVerticalWritingMode() const { return writingMode() == WM_TBRL || writingMode() == WM_TB; }

protected:
    // inherit
    struct InheritedFlags {
        bool operator==(const InheritedFlags& other) const
        {
            return (_colorRendering == other._colorRendering)
                && (_shapeRendering == other._shapeRendering)
                && (_clipRule == other._clipRule)
                && (_fillRule == other._fillRule)
                && (_capStyle == other._capStyle)
                && (_joinStyle == other._joinStyle)
                && (_textAnchor == other._textAnchor)
                && (_colorInterpolation == other._colorInterpolation)
                && (_colorInterpolationFilters == other._colorInterpolationFilters)
                && (_writingMode == other._writingMode)
                && (_glyphOrientationHorizontal == other._glyphOrientationHorizontal)
                && (_glyphOrientationVertical == other._glyphOrientationVertical);
        }

        bool operator!=(const InheritedFlags& other) const
        {
            return !(*this == other);
        }

        unsigned _colorRendering : 2; // EColorRendering
        unsigned _shapeRendering : 2; // EShapeRendering 
        unsigned _clipRule : 1; // WindRule
        unsigned _fillRule : 1; // WindRule
        unsigned _capStyle : 2; // LineCap
        unsigned _joinStyle : 2; // LineJoin
        unsigned _textAnchor : 2; // ETextAnchor
        unsigned _colorInterpolation : 2; // EColorInterpolation
        unsigned _colorInterpolationFilters : 2; // EColorInterpolation
        unsigned _writingMode : 3; // SVGWritingMode
        unsigned _glyphOrientationHorizontal : 3; // EGlyphOrientation
        unsigned _glyphOrientationVertical : 3; // EGlyphOrientation
    } svg_inherited_flags;

    // don't inherit
    struct NonInheritedFlags {
        // 32 bit non-inherited, don't add to the struct, or the operator will break.
        bool operator==(const NonInheritedFlags &other) const { return _niflags == other._niflags; }
        bool operator!=(const NonInheritedFlags &other) const { return _niflags != other._niflags; }

        union {
            struct {
                unsigned _alignmentBaseline : 4; // EAlignmentBaseline 
                unsigned _dominantBaseline : 4; // EDominantBaseline
                unsigned _baselineShift : 2; // EBaselineShift
                unsigned _vectorEffect: 1; // EVectorEffect
                // 21 bits unused
            } f;
            uint32_t _niflags;
        };
    } svg_noninherited_flags;

    // inherited attributes
    DataRef<StyleFillData> fill;
    DataRef<StyleStrokeData> stroke;
    DataRef<StyleTextData> text;
    DataRef<StyleInheritedResourceData> inheritedResources;

    // non-inherited attributes
    DataRef<StyleStopData> stops;
    DataRef<StyleMiscData> misc;
    DataRef<StyleShadowSVGData> shadowSVG;
    DataRef<StyleResourceData> resources;

private:
    enum CreateDefaultType { CreateDefault };
        
    SVGRenderStyle();
    SVGRenderStyle(const SVGRenderStyle&);
    SVGRenderStyle(CreateDefaultType); // Used to create the default style.

    void setBitDefaults()
    {
        svg_inherited_flags._clipRule = initialClipRule();
        svg_inherited_flags._colorRendering = initialColorRendering();
        svg_inherited_flags._fillRule = initialFillRule();
        svg_inherited_flags._shapeRendering = initialShapeRendering();
        svg_inherited_flags._textAnchor = initialTextAnchor();
        svg_inherited_flags._capStyle = initialCapStyle();
        svg_inherited_flags._joinStyle = initialJoinStyle();
        svg_inherited_flags._colorInterpolation = initialColorInterpolation();
        svg_inherited_flags._colorInterpolationFilters = initialColorInterpolationFilters();
        svg_inherited_flags._writingMode = initialWritingMode();
        svg_inherited_flags._glyphOrientationHorizontal = initialGlyphOrientationHorizontal();
        svg_inherited_flags._glyphOrientationVertical = initialGlyphOrientationVertical();

        svg_noninherited_flags._niflags = 0;
        svg_noninherited_flags.f._alignmentBaseline = initialAlignmentBaseline();
        svg_noninherited_flags.f._dominantBaseline = initialDominantBaseline();
        svg_noninherited_flags.f._baselineShift = initialBaselineShift();
        svg_noninherited_flags.f._vectorEffect = initialVectorEffect();
    }
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGRenderStyle_h
