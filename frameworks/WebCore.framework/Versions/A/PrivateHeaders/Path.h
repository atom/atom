/*
 * Copyright (C) 2003, 2006, 2009 Apple Inc. All rights reserved.
 *               2006 Rob Buis <buis@kde.org>
 * Copyright (C) 2007-2008 Torch Mobile, Inc.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
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

#ifndef Path_h
#define Path_h

#include "RoundedRect.h"
#include "WindRule.h"
#include <wtf/FastAllocBase.h>
#include <wtf/Forward.h>

#if USE(CG)
typedef struct CGPath PlatformPath;
#elif PLATFORM(OPENVG)
namespace WebCore {
class PlatformPathOpenVG;
}
typedef WebCore::PlatformPathOpenVG PlatformPath;
#elif PLATFORM(QT)
#include <qpainterpath.h>
typedef QPainterPath PlatformPath;
#elif PLATFORM(WX) && USE(WXGC)
class wxGraphicsPath;
typedef wxGraphicsPath PlatformPath;
#elif USE(CAIRO)
namespace WebCore {
class CairoPath;
}
typedef WebCore::CairoPath PlatformPath;
#elif USE(SKIA)
class SkPath;
typedef SkPath PlatformPath;
#elif OS(WINCE)
namespace WebCore {
    class PlatformPath;
}
typedef WebCore::PlatformPath PlatformPath;
#else
typedef void PlatformPath;
#endif

#if PLATFORM(QT)
/* QPainterPath is valued based */
typedef PlatformPath PlatformPathPtr;
#else
typedef PlatformPath* PlatformPathPtr;
#endif

namespace WebCore {

    class AffineTransform;
    class FloatPoint;
    class FloatRect;
    class FloatSize;
    class GraphicsContext;
    class StrokeStyleApplier;

    enum PathElementType {
        PathElementMoveToPoint, // The points member will contain 1 value.
        PathElementAddLineToPoint, // The points member will contain 1 value.
        PathElementAddQuadCurveToPoint, // The points member will contain 2 values.
        PathElementAddCurveToPoint, // The points member will contain 3 values.
        PathElementCloseSubpath // The points member will contain no values.
    };

    // The points in the sturcture are the same as those that would be used with the
    // add... method. For example, a line returns the endpoint, while a cubic returns
    // two tangent points and the endpoint.
    struct PathElement {
        PathElementType type;
        FloatPoint* points;
    };

    typedef void (*PathApplierFunction)(void* info, const PathElement*);

    class Path {
        WTF_MAKE_FAST_ALLOCATED;
    public:
        Path();
        ~Path();

        Path(const Path&);
        Path& operator=(const Path&);

        bool contains(const FloatPoint&, WindRule rule = RULE_NONZERO) const;
        bool strokeContains(StrokeStyleApplier*, const FloatPoint&) const;
        // fastBoundingRect() should equal or contain boundingRect(); boundingRect()
        // should perfectly bound the points within the path.
        FloatRect boundingRect() const;
        FloatRect fastBoundingRect() const;
        FloatRect strokeBoundingRect(StrokeStyleApplier* = 0) const;
        
        float length() const;
        FloatPoint pointAtLength(float length, bool& ok) const;
        float normalAngleAtLength(float length, bool& ok) const;

        void clear();
        bool isEmpty() const;
        // Gets the current point of the current path, which is conceptually the final point reached by the path so far.
        // Note the Path can be empty (isEmpty() == true) and still have a current point.
        bool hasCurrentPoint() const;
        FloatPoint currentPoint() const;

        void moveTo(const FloatPoint&);
        void addLineTo(const FloatPoint&);
        void addQuadCurveTo(const FloatPoint& controlPoint, const FloatPoint& endPoint);
        void addBezierCurveTo(const FloatPoint& controlPoint1, const FloatPoint& controlPoint2, const FloatPoint& endPoint);
        void addArcTo(const FloatPoint&, const FloatPoint&, float radius);
        void closeSubpath();

        void addArc(const FloatPoint&, float radius, float startAngle, float endAngle, bool anticlockwise);
        void addRect(const FloatRect&);
        void addEllipse(const FloatRect&);
        void addRoundedRect(const FloatRect&, const FloatSize& roundingRadii);
        void addRoundedRect(const FloatRect&, const FloatSize& topLeftRadius, const FloatSize& topRightRadius, const FloatSize& bottomLeftRadius, const FloatSize& bottomRightRadius);
        void addRoundedRect(const RoundedRect&);

        void translate(const FloatSize&);

        PlatformPathPtr platformPath() const { return m_path; }

        void apply(void* info, PathApplierFunction) const;
        void transform(const AffineTransform&);

    private:
        void addBeziersForRoundedRect(const FloatRect&, const FloatSize& topLeftRadius, const FloatSize& topRightRadius, const FloatSize& bottomLeftRadius, const FloatSize& bottomRightRadius);

        PlatformPathPtr m_path;
    };

}

#endif
