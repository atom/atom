/*
    Copyright (C) 1999 Lars Knoll (knoll@kde.org)
    Copyright (C) 2006, 2008 Apple Inc. All rights reserved.
    Copyright (C) 2011 Rik Cabanier (cabanier@adobe.com)

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

#ifndef Length_h
#define Length_h

#include "AnimationUtilities.h"
#include <wtf/Assertions.h>
#include <wtf/FastAllocBase.h>
#include <wtf/Forward.h>
#include <wtf/MathExtras.h>
#include <wtf/PassOwnArrayPtr.h>

namespace WebCore {

const int intMaxForLength = 0x7ffffff; // max value for a 28-bit int
const int intMinForLength = (-0x7ffffff - 1); // min value for a 28-bit int

enum LengthType { Auto, Relative, Percent, Fixed, Intrinsic, MinIntrinsic, Undefined };

struct Length {
    WTF_MAKE_FAST_ALLOCATED;
public:
    Length()
        :  m_intValue(0), m_quirk(false), m_type(Auto), m_isFloat(false)
    {
    }

    Length(LengthType t)
        : m_intValue(0), m_quirk(false), m_type(t), m_isFloat(false)
    {
    }

    Length(int v, LengthType t, bool q = false)
        : m_intValue(v), m_quirk(q), m_type(t), m_isFloat(false)
    {
    }
    
    Length(float v, LengthType t, bool q = false)
    : m_floatValue(v), m_quirk(q), m_type(t), m_isFloat(true)
    {
    }

    Length(double v, LengthType t, bool q = false)
        : m_quirk(q), m_type(t), m_isFloat(true)
    {
        m_floatValue = static_cast<float>(v);    
    }

    bool operator==(const Length& o) const { return (m_type == o.m_type) && (m_quirk == o.m_quirk) && (isUndefined() || (getFloatValue() == o.getFloatValue())); }
    bool operator!=(const Length& o) const { return !(*this == o); }

    const Length& operator*=(float v)
    {        
        if (m_isFloat)
            m_floatValue = static_cast<float>(m_floatValue * v);
        else        
            m_intValue = static_cast<int>(m_intValue * v);
        
        return *this;
    }
    
    int value() const
    {
        return getIntValue();
    }

    float percent() const
    {
        ASSERT(type() == Percent);
        return getFloatValue();
    }

    LengthType type() const { return static_cast<LengthType>(m_type); }
    bool quirk() const { return m_quirk; }

    void setQuirk(bool quirk)
    {
        m_quirk = quirk;
    }

    void setValue(LengthType t, int value)
    {
        m_type = t;
        m_intValue = value;
        m_isFloat = false;
    }

    void setValue(int value)
    {
        setValue(Fixed, value);
    }

    void setValue(LengthType t, float value)
    {
        m_type = t;
        m_floatValue = value;
        m_isFloat = true;    
    }

    void setValue(float value)
    {
        *this = Length(value, Fixed);
    }

    // Note: May only be called for Fixed, Percent and Auto lengths.
    // Other types will ASSERT in order to catch invalid length calculations.
    int calcValue(int maxValue, bool roundPercentages = false) const
    {
        switch (type()) {
            case Fixed:
            case Percent:
                return calcMinValue(maxValue, roundPercentages);
            case Auto:
                return maxValue;
            case Relative:
            case Intrinsic:
            case MinIntrinsic:
            case Undefined:
                ASSERT_NOT_REACHED();
                return 0;
        }
        ASSERT_NOT_REACHED();
        return 0;
    }

    int calcMinValue(int maxValue, bool roundPercentages = false) const
    {
        switch (type()) {
            case Fixed:
                return value();
            case Percent:
                if (roundPercentages)
                    return static_cast<int>(round(maxValue * percent() / 100.0f));
                // Don't remove the extra cast to float. It is needed for rounding on 32-bit Intel machines that use the FPU stack.
                return static_cast<int>(static_cast<float>(maxValue * percent() / 100.0f));
            case Auto:
                return 0;
            case Relative:
            case Intrinsic:
            case MinIntrinsic:
            case Undefined:
                ASSERT_NOT_REACHED();
                return 0;
        }
        ASSERT_NOT_REACHED();
        return 0;
    }

    float calcFloatValue(int maxValue) const
    {
        switch (type()) {
            case Fixed:
                return getFloatValue();
            case Percent:
                return static_cast<float>(maxValue * percent() / 100.0f);
            case Auto:
                return static_cast<float>(maxValue);
            case Relative:
            case Intrinsic:
            case MinIntrinsic:
            case Undefined:
                ASSERT_NOT_REACHED();
                return 0;
        }
        ASSERT_NOT_REACHED();
        return 0;
    }

    bool isUndefined() const { return type() == Undefined; }
    bool isZero() const 
    {
        ASSERT(!isUndefined());
        return m_isFloat ? !m_floatValue : !m_intValue;
    }
    
    bool isPositive() const { return isUndefined() ? false : getFloatValue() > 0; }
    bool isNegative() const { return isUndefined() ? false : getFloatValue() < 0; }

    bool isAuto() const { return type() == Auto; }
    bool isRelative() const { return type() == Relative; }
    bool isPercent() const { return type() == Percent; }
    bool isFixed() const { return type() == Fixed; }
    bool isIntrinsicOrAuto() const { return type() == Auto || type() == MinIntrinsic || type() == Intrinsic; }
    bool isSpecified() const { return type() == Fixed || type() == Percent; }

    Length blend(const Length& from, double progress) const
    {
        // Blend two lengths to produce a new length that is in between them.  Used for animation.
        if (!from.isZero() && !isZero() && from.type() != type())
            return *this;

        if (from.isZero() && isZero())
            return *this;
        
        LengthType resultType = type();
        if (isZero())
            resultType = from.type();
        
        if (resultType == Percent) {
            float fromPercent = from.isZero() ? 0 : from.percent();
            float toPercent = isZero() ? 0 : percent();
            return Length(WebCore::blend(fromPercent, toPercent, progress), Percent);
        } 

        float fromValue = from.isZero() ? 0 : from.value();
        float toValue = isZero() ? 0 : value();
        return Length(WebCore::blend(fromValue, toValue, progress), resultType);
    }

private:
    int getIntValue() const
    {
        ASSERT(!isUndefined());
        return m_isFloat ? static_cast<int>(m_floatValue) : m_intValue;
    }

    float getFloatValue() const
    {
        ASSERT(!isUndefined());
        return m_isFloat ? m_floatValue : m_intValue;
    }

    union {
        int m_intValue;
        float m_floatValue;
    };
    bool m_quirk;
    unsigned char m_type;
    bool m_isFloat;
};

PassOwnArrayPtr<Length> newCoordsArray(const String&, int& len);
PassOwnArrayPtr<Length> newLengthArray(const String&, int& len);

} // namespace WebCore

#endif // Length_h
