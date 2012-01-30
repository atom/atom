/*
 * Copyright (C) Research In Motion Limited 2011. All rights reserved.
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

#ifndef SVGLengthContext_h
#define SVGLengthContext_h

#if ENABLE(SVG)
#include "FloatRect.h"
#include "SVGUnitTypes.h"

namespace WebCore {

class SVGElement;
class SVGLength;

typedef int ExceptionCode;

enum SVGLengthType {
    LengthTypeUnknown = 0,
    LengthTypeNumber,
    LengthTypePercentage,
    LengthTypeEMS,
    LengthTypeEXS,
    LengthTypePX,
    LengthTypeCM,
    LengthTypeMM,
    LengthTypeIN,
    LengthTypePT,
    LengthTypePC
};

enum SVGLengthMode {
    LengthModeWidth = 0,
    LengthModeHeight,
    LengthModeOther
};

class SVGLengthContext {
public:
    explicit SVGLengthContext(const SVGElement*);

    template<typename T>
    static FloatRect resolveRectangle(const T* context, SVGUnitTypes::SVGUnitType type, const FloatRect& viewport)
    {
        return SVGLengthContext::resolveRectangle(context, type, viewport, context->x(), context->y(), context->width(), context->height());
    }

    static FloatRect resolveRectangle(const SVGElement*, SVGUnitTypes::SVGUnitType, const FloatRect& viewport, const SVGLength& x, const SVGLength& y, const SVGLength& width, const SVGLength& height);
    static FloatPoint resolvePoint(const SVGElement*, SVGUnitTypes::SVGUnitType, const SVGLength& x, const SVGLength& y);
    static float resolveLength(const SVGElement*, SVGUnitTypes::SVGUnitType, const SVGLength&);

    float convertValueToUserUnits(float, SVGLengthMode, SVGLengthType fromUnit, ExceptionCode&) const;
    float convertValueFromUserUnits(float, SVGLengthMode, SVGLengthType toUnit, ExceptionCode&) const;

private:
    SVGLengthContext(const SVGElement*, const FloatRect& viewport);

    float convertValueFromUserUnitsToPercentage(float value, SVGLengthMode, ExceptionCode&) const;
    float convertValueFromPercentageToUserUnits(float value, SVGLengthMode, ExceptionCode&) const;

    float convertValueFromUserUnitsToEMS(float value, ExceptionCode&) const;
    float convertValueFromEMSToUserUnits(float value, ExceptionCode&) const;

    float convertValueFromUserUnitsToEXS(float value, ExceptionCode&) const;
    float convertValueFromEXSToUserUnits(float value, ExceptionCode&) const;

    bool determineViewport(float& width, float& height) const;

    const SVGElement* m_context;
    FloatRect m_overridenViewport;
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGLengthContext_h
