/*
 * Copyright 2011 Adobe Systems Incorporated. All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER “AS IS” AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef CSSWrapShapes_h
#define CSSWrapShapes_h

#include "CSSPrimitiveValue.h"
#include "PlatformString.h"
#include "WindRule.h"
#include <wtf/RefPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

class CSSWrapShape : public RefCounted<CSSWrapShape> {
public:
    enum Type {
        CSS_WRAP_SHAPE_RECT = 1,
        CSS_WRAP_SHAPE_CIRCLE = 2,
        CSS_WRAP_SHAPE_ELLIPSE = 3,
        CSS_WRAP_SHAPE_POLYGON = 4,
        CSS_WRAP_SHAPE_PATH = 5
    };

    virtual Type type() = 0;
    virtual String cssText() const = 0;

public:
    virtual ~CSSWrapShape() { }

protected:
    CSSWrapShape() { }
};

class CSSWrapShapeRect : public CSSWrapShape {
public:
    static PassRefPtr<CSSWrapShapeRect> create() { return adoptRef(new CSSWrapShapeRect); }

    CSSPrimitiveValue* left() const { return m_left.get(); }
    CSSPrimitiveValue* top() const { return m_top.get(); }
    CSSPrimitiveValue* width() const { return m_width.get(); }
    CSSPrimitiveValue* height() const { return m_height.get(); }
    CSSPrimitiveValue* radiusX() const { return m_radiusX.get(); }
    CSSPrimitiveValue* radiusY() const { return m_radiusY.get(); }

    void setLeft(PassRefPtr<CSSPrimitiveValue> left) { m_left = left; }
    void setTop(PassRefPtr<CSSPrimitiveValue> top) { m_top = top; }
    void setWidth(PassRefPtr<CSSPrimitiveValue> width) { m_width = width; }
    void setHeight(PassRefPtr<CSSPrimitiveValue> height) { m_height = height; }
    void setRadiusX(PassRefPtr<CSSPrimitiveValue> radiusX) { m_radiusX = radiusX; }
    void setRadiusY(PassRefPtr<CSSPrimitiveValue> radiusY) { m_radiusY = radiusY; }

    virtual Type type() { return CSS_WRAP_SHAPE_RECT; }
    virtual String cssText() const;

private:
    CSSWrapShapeRect() { }

    RefPtr<CSSPrimitiveValue> m_top;
    RefPtr<CSSPrimitiveValue> m_left;
    RefPtr<CSSPrimitiveValue> m_width;
    RefPtr<CSSPrimitiveValue> m_height;
    RefPtr<CSSPrimitiveValue> m_radiusX;
    RefPtr<CSSPrimitiveValue> m_radiusY;
};

class CSSWrapShapeCircle : public CSSWrapShape {
public:
    static PassRefPtr<CSSWrapShapeCircle> create() { return adoptRef(new CSSWrapShapeCircle); }

    CSSPrimitiveValue* left() const { return m_left.get(); }
    CSSPrimitiveValue* top() const { return m_top.get(); }
    CSSPrimitiveValue* radius() const { return m_radius.get(); }

    void setLeft(PassRefPtr<CSSPrimitiveValue> left) { m_left = left; }
    void setTop(PassRefPtr<CSSPrimitiveValue> top) { m_top = top; }
    void setRadius(PassRefPtr<CSSPrimitiveValue> radius) { m_radius = radius; }

    virtual Type type() { return CSS_WRAP_SHAPE_CIRCLE; }
    virtual String cssText() const;

private:
    CSSWrapShapeCircle() { }

    RefPtr<CSSPrimitiveValue> m_top;
    RefPtr<CSSPrimitiveValue> m_left;
    RefPtr<CSSPrimitiveValue> m_radius;
};

class CSSWrapShapeEllipse : public CSSWrapShape {
public:
    static PassRefPtr<CSSWrapShapeEllipse> create() { return adoptRef(new CSSWrapShapeEllipse); }

    CSSPrimitiveValue* left() const { return m_left.get(); }
    CSSPrimitiveValue* top() const { return m_top.get(); }
    CSSPrimitiveValue* radiusX() const { return m_radiusX.get(); }
    CSSPrimitiveValue* radiusY() const { return m_radiusY.get(); }

    void setLeft(PassRefPtr<CSSPrimitiveValue> left) { m_left = left; }
    void setTop(PassRefPtr<CSSPrimitiveValue> top) { m_top = top; }
    void setRadiusX(PassRefPtr<CSSPrimitiveValue> radiusX) { m_radiusX = radiusX; }
    void setRadiusY(PassRefPtr<CSSPrimitiveValue> radiusY) { m_radiusY = radiusY; }

    virtual Type type() { return CSS_WRAP_SHAPE_ELLIPSE; }
    virtual String cssText() const;

private:
    CSSWrapShapeEllipse() { }

    RefPtr<CSSPrimitiveValue> m_top;
    RefPtr<CSSPrimitiveValue> m_left;
    RefPtr<CSSPrimitiveValue> m_radiusX;
    RefPtr<CSSPrimitiveValue> m_radiusY;
};

class CSSWrapShapePolygon : public CSSWrapShape {
public:
    static PassRefPtr<CSSWrapShapePolygon> create() { return adoptRef(new CSSWrapShapePolygon); }

    void appendPoint(PassRefPtr<CSSPrimitiveValue> x, PassRefPtr<CSSPrimitiveValue> y)
    {
        m_values.append(x);
        m_values.append(y);
    }

    PassRefPtr<CSSPrimitiveValue> getXAt(unsigned i) { return m_values.at(i * 2); }
    PassRefPtr<CSSPrimitiveValue> getYAt(unsigned i) { return m_values.at(i * 2 + 1); }

    void setWindRule(WindRule w) { m_windRule = w; }
    WindRule windRule() const { return m_windRule; }

    virtual Type type() { return CSS_WRAP_SHAPE_POLYGON; }
    virtual String cssText() const;

private:
    CSSWrapShapePolygon()
        : m_windRule(RULE_NONZERO)
    {
    }

    Vector<RefPtr<CSSPrimitiveValue> > m_values;
    WindRule m_windRule;
};

} // namespace WebCore

#endif // CSSWrapShapes_h
