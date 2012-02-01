/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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

#ifndef FilterOperation_h
#define FilterOperation_h

#if ENABLE(CSS_FILTERS)

#include "Color.h"
#include "Length.h"
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/text/AtomicString.h>

// Annoyingly, wingdi.h #defines this.
#ifdef PASSTHROUGH
#undef PASSTHROUGH
#endif

namespace WebCore {

// CSS Filters

class FilterOperation : public RefCounted<FilterOperation> {
public:
    enum OperationType {
        REFERENCE, // url(#somefilter)
        GRAYSCALE,
        SEPIA,
        SATURATE,
        HUE_ROTATE,
        INVERT,
        OPACITY,
        BRIGHTNESS,
        CONTRAST,
        BLUR,
        DROP_SHADOW,
#if ENABLE(CSS_SHADERS)
        CUSTOM,
#endif
        PASSTHROUGH,
        NONE
    };

    virtual ~FilterOperation() { }

    virtual bool operator==(const FilterOperation&) const = 0;
    bool operator!=(const FilterOperation& o) const { return !(*this == o); }

    virtual PassRefPtr<FilterOperation> blend(const FilterOperation* /*from*/, double /*progress*/, bool /*blendToPassthrough*/ = false) { return 0; }

    virtual OperationType getOperationType() const { return m_type; }
    virtual bool isSameType(const FilterOperation& o) const { return o.getOperationType() == m_type; }

protected:
    FilterOperation(OperationType type)
        : m_type(type)
    {
    }

    OperationType m_type;
};

class PassthroughFilterOperation : public FilterOperation {
public:
    static PassRefPtr<PassthroughFilterOperation> create()
    {
        return adoptRef(new PassthroughFilterOperation());
    }

private:

    virtual bool operator==(const FilterOperation& o) const
    {
        return isSameType(o);
    }

    PassthroughFilterOperation()
        : FilterOperation(PASSTHROUGH)
    {
    }
};

class ReferenceFilterOperation : public FilterOperation {
public:
    static PassRefPtr<ReferenceFilterOperation> create(const AtomicString& reference, OperationType type)
    {
        return adoptRef(new ReferenceFilterOperation(reference, type));
    }

    const AtomicString& reference() const { return m_reference; }

private:

    virtual bool operator==(const FilterOperation& o) const
    {
        if (!isSameType(o))
            return false;
        const ReferenceFilterOperation* other = static_cast<const ReferenceFilterOperation*>(&o);
        return m_reference == other->m_reference;
    }

    ReferenceFilterOperation(const AtomicString& reference, OperationType type)
        : FilterOperation(type)
        , m_reference(reference)
    {
    }

    AtomicString m_reference;
};

// GRAYSCALE, SEPIA, SATURATE and HUE_ROTATE are variations on a basic color matrix effect.
// For HUE_ROTATE, the angle of rotation is stored in m_amount.
class BasicColorMatrixFilterOperation : public FilterOperation {
public:
    static PassRefPtr<BasicColorMatrixFilterOperation> create(double amount, OperationType type)
    {
        return adoptRef(new BasicColorMatrixFilterOperation(amount, type));
    }

    double amount() const { return m_amount; }

    virtual PassRefPtr<FilterOperation> blend(const FilterOperation* from, double progress, bool blendToPassthrough = false);

private:
    virtual bool operator==(const FilterOperation& o) const
    {
        if (!isSameType(o))
            return false;
        const BasicColorMatrixFilterOperation* other = static_cast<const BasicColorMatrixFilterOperation*>(&o);
        return m_amount == other->m_amount;
    }
    
    double passthroughAmount() const;
    
    BasicColorMatrixFilterOperation(double amount, OperationType type)
        : FilterOperation(type)
        , m_amount(amount)
    {
    }

    double m_amount;
};

// INVERT, BRIGHTNESS, CONTRAST and OPACITY are variations on a basic component transfer effect.
class BasicComponentTransferFilterOperation : public FilterOperation {
public:
    static PassRefPtr<BasicComponentTransferFilterOperation> create(double amount, OperationType type)
    {
        return adoptRef(new BasicComponentTransferFilterOperation(amount, type));
    }

    double amount() const { return m_amount; }

    virtual PassRefPtr<FilterOperation> blend(const FilterOperation* from, double progress, bool blendToPassthrough = false);

private:
    virtual bool operator==(const FilterOperation& o) const
    {
        if (!isSameType(o))
            return false;
        const BasicComponentTransferFilterOperation* other = static_cast<const BasicComponentTransferFilterOperation*>(&o);
        return m_amount == other->m_amount;
    }

    double passthroughAmount() const;

    BasicComponentTransferFilterOperation(double amount, OperationType type)
        : FilterOperation(type)
        , m_amount(amount)
    {
    }

    double m_amount;
};

class GammaFilterOperation : public FilterOperation {
public:
    static PassRefPtr<GammaFilterOperation> create(double amplitude, double exponent, double offset, OperationType type)
    {
        return adoptRef(new GammaFilterOperation(amplitude, exponent, offset, type));
    }

    double amplitude() const { return m_amplitude; }
    double exponent() const { return m_exponent; }
    double offset() const { return m_offset; }

    virtual PassRefPtr<FilterOperation> blend(const FilterOperation* from, double progress, bool blendToPassthrough = false);

private:
    virtual bool operator==(const FilterOperation& o) const
    {
        if (!isSameType(o))
            return false;
        const GammaFilterOperation* other = static_cast<const GammaFilterOperation*>(&o);
        return m_amplitude == other->m_amplitude && m_exponent == other->m_exponent && m_offset == other->m_offset;
    }

    GammaFilterOperation(double amplitude, double exponent, double offset, OperationType type)
        : FilterOperation(type)
        , m_amplitude(amplitude)
        , m_exponent(exponent)
        , m_offset(offset)
    {
    }

    double m_amplitude;
    double m_exponent;
    double m_offset;
};

class BlurFilterOperation : public FilterOperation {
public:
    static PassRefPtr<BlurFilterOperation> create(Length stdDeviation, OperationType type)
    {
        return adoptRef(new BlurFilterOperation(stdDeviation, type));
    }

    Length stdDeviation() const { return m_stdDeviation; }

    virtual PassRefPtr<FilterOperation> blend(const FilterOperation* from, double progress, bool blendToPassthrough = false);

private:
    virtual bool operator==(const FilterOperation& o) const
    {
        if (!isSameType(o))
            return false;
        const BlurFilterOperation* other = static_cast<const BlurFilterOperation*>(&o);
        return m_stdDeviation == other->m_stdDeviation;
    }

    BlurFilterOperation(Length stdDeviation, OperationType type)
        : FilterOperation(type)
        , m_stdDeviation(stdDeviation)
    {
    }

    Length m_stdDeviation;
};

class DropShadowFilterOperation : public FilterOperation {
public:
    static PassRefPtr<DropShadowFilterOperation> create(int x, int y, int stdDeviation, Color color, OperationType type)
    {
        return adoptRef(new DropShadowFilterOperation(x, y, stdDeviation, color, type));
    }

    int x() const { return m_x; }
    int y() const { return m_y; }
    int stdDeviation() const { return m_stdDeviation; }
    Color color() const { return m_color; }

    virtual PassRefPtr<FilterOperation> blend(const FilterOperation* from, double progress, bool blendToPassthrough = false);

private:

    virtual bool operator==(const FilterOperation& o) const
    {
        if (!isSameType(o))
            return false;
        const DropShadowFilterOperation* other = static_cast<const DropShadowFilterOperation*>(&o);
        return m_x == other->m_x && m_y == other->m_y && m_stdDeviation == other->m_stdDeviation && m_color == other->m_color;
    }

    DropShadowFilterOperation(int x, int y, int stdDeviation, Color color, OperationType type)
        : FilterOperation(type)
        , m_x(x)
        , m_y(y)
        , m_stdDeviation(stdDeviation)
        , m_color(color)
    {
    }

    int m_x; // FIXME: x and y should be Lengths?
    int m_y;
    int m_stdDeviation;
    Color m_color;
};

} // namespace WebCore

#endif // ENABLE(CSS_FILTERS)

#endif // FilterOperation_h
