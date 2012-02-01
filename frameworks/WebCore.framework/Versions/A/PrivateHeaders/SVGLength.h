/*
 * Copyright (C) 2004, 2005, 2006, 2008 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005, 2006 Rob Buis <buis@kde.org>
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

#ifndef SVGLength_h
#define SVGLength_h

#if ENABLE(SVG)
#include "AnimationUtilities.h"
#include "SVGLengthContext.h"
#include "SVGParsingError.h"
#include "SVGPropertyTraits.h"

namespace WebCore {

class CSSPrimitiveValue;
class QualifiedName;

typedef int ExceptionCode;

enum SVGLengthNegativeValuesMode {
    AllowNegativeLengths,
    ForbidNegativeLengths
};

class SVGLength {
public:
    // Forward declare these enums in the w3c naming scheme, for IDL generation
    enum {
        SVG_LENGTHTYPE_UNKNOWN = LengthTypeUnknown,
        SVG_LENGTHTYPE_NUMBER = LengthTypeNumber,
        SVG_LENGTHTYPE_PERCENTAGE = LengthTypePercentage,
        SVG_LENGTHTYPE_EMS = LengthTypeEMS,
        SVG_LENGTHTYPE_EXS = LengthTypeEXS,
        SVG_LENGTHTYPE_PX = LengthTypePX,
        SVG_LENGTHTYPE_CM = LengthTypeCM,
        SVG_LENGTHTYPE_MM = LengthTypeMM,
        SVG_LENGTHTYPE_IN = LengthTypeIN,
        SVG_LENGTHTYPE_PT = LengthTypePT,
        SVG_LENGTHTYPE_PC = LengthTypePC
    };

    SVGLength(SVGLengthMode = LengthModeOther, const String& valueAsString = String());
    SVGLength(const SVGLengthContext&, float, SVGLengthMode = LengthModeOther, SVGLengthType = LengthTypeNumber);
    SVGLength(const SVGLength&);

    SVGLengthType unitType() const;
    SVGLengthMode unitMode() const;

    bool operator==(const SVGLength&) const;
    bool operator!=(const SVGLength&) const;

    static SVGLength construct(SVGLengthMode, const String&, SVGParsingError&, SVGLengthNegativeValuesMode = AllowNegativeLengths);

    float value(const SVGLengthContext&) const;
    float value(const SVGLengthContext&, ExceptionCode&) const;
    void setValue(float, const SVGLengthContext&, ExceptionCode&);
    void setValue(const SVGLengthContext&, float, SVGLengthMode, SVGLengthType, ExceptionCode&);

    float valueInSpecifiedUnits() const { return m_valueInSpecifiedUnits; }
    void setValueInSpecifiedUnits(float value) { m_valueInSpecifiedUnits = value; }

    float valueAsPercentage() const;

    String valueAsString() const;
    void setValueAsString(const String&, ExceptionCode&);
    void setValueAsString(const String&, SVGLengthMode, ExceptionCode&);
    
    void newValueSpecifiedUnits(unsigned short, float valueInSpecifiedUnits, ExceptionCode&);
    void convertToSpecifiedUnits(unsigned short, const SVGLengthContext&, ExceptionCode&);

    // Helper functions
    inline bool isRelative() const
    {
        SVGLengthType type = unitType();
        return type == LengthTypePercentage || type == LengthTypeEMS || type == LengthTypeEXS;
    }

    bool isZero() const 
    { 
        return !m_valueInSpecifiedUnits;
    }

    static SVGLength fromCSSPrimitiveValue(CSSPrimitiveValue*);
    static PassRefPtr<CSSPrimitiveValue> toCSSPrimitiveValue(const SVGLength&);
    static SVGLengthMode lengthModeForAnimatedLengthAttribute(const QualifiedName&);

    SVGLength blend(const SVGLength& from, float progress) const
    {
        SVGLengthType toType = unitType();
        SVGLengthType fromType = from.unitType();
        if ((from.isZero() && isZero())
            || fromType == LengthTypeUnknown
            || toType == LengthTypeUnknown
            || (!from.isZero() && fromType != LengthTypePercentage && toType == LengthTypePercentage)
            || (!isZero() && fromType == LengthTypePercentage && toType != LengthTypePercentage)
            || (!from.isZero() && !isZero() && (fromType == LengthTypeEMS || fromType == LengthTypeEXS) && fromType != toType))
            return *this;

        SVGLength length;
        ExceptionCode ec = 0;

        if (fromType == LengthTypePercentage || toType == LengthTypePercentage) {
            float fromPercent = from.valueAsPercentage() * 100;
            float toPercent = valueAsPercentage() * 100;
            length.newValueSpecifiedUnits(LengthTypePercentage, WebCore::blend(fromPercent, toPercent, progress), ec);
            if (ec)
                return SVGLength();
            return length;
        }

        if (fromType == toType || from.isZero() || isZero() || fromType == LengthTypeEMS || fromType == LengthTypeEXS) {
            float fromValue = from.valueInSpecifiedUnits();
            float toValue = valueInSpecifiedUnits();
            if (isZero())
                length.newValueSpecifiedUnits(fromType, WebCore::blend(fromValue, toValue, progress), ec);
            else
                length.newValueSpecifiedUnits(toType, WebCore::blend(fromValue, toValue, progress), ec);
            if (ec)
                return SVGLength();
            return length;
        }

        ASSERT(!isRelative());
        ASSERT(!from.isRelative());

        SVGLengthContext nonRelativeLengthContext(0);
        float fromValueInUserUnits = nonRelativeLengthContext.convertValueToUserUnits(from.valueInSpecifiedUnits(), from.unitMode(), fromType, ec);
        if (ec)
            return SVGLength();

        float fromValue = nonRelativeLengthContext.convertValueFromUserUnits(fromValueInUserUnits, unitMode(), toType, ec);
        if (ec)
            return SVGLength();

        float toValue = valueInSpecifiedUnits();
        length.newValueSpecifiedUnits(toType, WebCore::blend(fromValue, toValue, progress), ec);

        if (ec)
            return SVGLength();
        return length;
    }

private:
    float m_valueInSpecifiedUnits;
    unsigned int m_unit;
};

template<>
struct SVGPropertyTraits<SVGLength> {
    static SVGLength initialValue() { return SVGLength(); }
    static String toString(const SVGLength& type) { return type.valueAsString(); }
};


} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGLength_h
