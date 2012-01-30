/*
 * Copyright (C) Research In Motion Limited 2010. All rights reserved.
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
 */

#ifndef SVGMatrix_h
#define SVGMatrix_h

#if ENABLE(SVG)
#include "AffineTransform.h"
#include "SVGException.h"

namespace WebCore {

typedef int ExceptionCode;

// Only used in the bindings.
class SVGMatrix : public AffineTransform {
public:
    SVGMatrix() { }
    SVGMatrix(const AffineTransform& other)
        : AffineTransform(other)
    {
    }

    SVGMatrix(double a, double b, double c, double d, double e, double f)
        : AffineTransform(a, b, c, d, e, f)
    {
    }

    SVGMatrix translate(double tx, double ty)
    {
        AffineTransform copy = *this;
        copy.translate(tx, ty);
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix scale(double s)
    {
        AffineTransform copy = *this;
        copy.scale(s, s);
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix scaleNonUniform(double sx, double sy)
    {
        AffineTransform copy = *this;
        copy.scale(sx, sy);
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix rotate(double d)
    {
        AffineTransform copy = *this;
        copy.rotate(d);
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix flipX()
    {
        AffineTransform copy = *this;
        copy.flipX();
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix flipY()
    {
        AffineTransform copy = *this;
        copy.flipY();
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix skewX(double angle)
    {
        AffineTransform copy = *this;
        copy.skewX(angle);
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix skewY(double angle)
    {
        AffineTransform copy = *this;
        copy.skewY(angle);
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix multiply(const SVGMatrix& other)
    {
        AffineTransform copy = *this;
        copy *= static_cast<const AffineTransform&>(other);
        return static_cast<SVGMatrix>(copy);
    }

    SVGMatrix inverse(ExceptionCode& ec) const
    {
        AffineTransform transform = AffineTransform::inverse();
        if (!isInvertible())
            ec = SVGException::SVG_MATRIX_NOT_INVERTABLE;

        return transform;
    }

    SVGMatrix rotateFromVector(double x, double y, ExceptionCode& ec)
    {
        if (!x || !y)
            ec = SVGException::SVG_INVALID_VALUE_ERR;

        AffineTransform copy = *this;
        copy.rotateFromVector(x, y);
        return static_cast<SVGMatrix>(copy);
    }

};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif
