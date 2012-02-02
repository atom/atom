/*
 * Copyright (C) 2004, 2005, 2007, 2008 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005, 2006 Rob Buis <buis@kde.org>
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

#ifndef SVGAngle_h
#define SVGAngle_h

#if ENABLE(SVG)
#include "SVGPropertyTraits.h"

namespace WebCore {

typedef int ExceptionCode;

class SVGAngle {
public:
    SVGAngle();

    enum SVGAngleType {
        SVG_ANGLETYPE_UNKNOWN = 0,
        SVG_ANGLETYPE_UNSPECIFIED = 1,
        SVG_ANGLETYPE_DEG = 2,
        SVG_ANGLETYPE_RAD = 3,
        SVG_ANGLETYPE_GRAD = 4
    };

    SVGAngleType unitType() const { return m_unitType; }

    void setValue(float);
    float value() const;

    void setValueInSpecifiedUnits(float valueInSpecifiedUnits) { m_valueInSpecifiedUnits = valueInSpecifiedUnits; }
    float valueInSpecifiedUnits() const { return m_valueInSpecifiedUnits; }

    void setValueAsString(const String&, ExceptionCode&);
    String valueAsString() const;

    void newValueSpecifiedUnits(unsigned short unitType, float valueInSpecifiedUnits, ExceptionCode&);
    void convertToSpecifiedUnits(unsigned short unitType, ExceptionCode&);

private:
    SVGAngleType m_unitType;
    float m_valueInSpecifiedUnits;
};

template<>
struct SVGPropertyTraits<SVGAngle> {
    static SVGAngle initialValue() { return SVGAngle(); }
    static String toString(const SVGAngle& type) { return type.valueAsString(); }
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGAngle_h
