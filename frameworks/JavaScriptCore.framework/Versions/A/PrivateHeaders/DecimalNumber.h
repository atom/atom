/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef DecimalNumber_h
#define DecimalNumber_h

#include <math.h>
#include <wtf/dtoa.h>
#include <wtf/MathExtras.h>
#include <wtf/text/WTFString.h>

namespace WTF {

enum RoundingSignificantFiguresType { RoundingSignificantFigures };
enum RoundingDecimalPlacesType { RoundingDecimalPlaces };

class DecimalNumber {
public:
    DecimalNumber(double d)
    {
        ASSERT(isfinite(d));
        dtoa(m_significand, d, m_sign, m_exponent, m_precision);

        ASSERT(m_precision);
        // Zero should always have exponent 0.
        ASSERT(m_significand[0] != '0' || !m_exponent);
        // No values other than zero should have a leading zero.
        ASSERT(m_significand[0] != '0' || m_precision == 1);
        // No values other than zero should have trailing zeros.
        ASSERT(m_significand[0] == '0' || m_significand[m_precision - 1] != '0');
    }

    DecimalNumber(double d, RoundingSignificantFiguresType, unsigned significantFigures)
    {
        ASSERT(isfinite(d));
        dtoaRoundSF(m_significand, d, significantFigures, m_sign, m_exponent, m_precision);

        ASSERT(significantFigures && significantFigures <= sizeof(DtoaBuffer));
        while (m_precision < significantFigures)
            m_significand[m_precision++] = '0';

        ASSERT(m_precision);
        // Zero should always have exponent 0.
        ASSERT(m_significand[0] != '0' || !m_exponent);
    }

    DecimalNumber(double d, RoundingDecimalPlacesType, unsigned decimalPlaces)
    {
        ASSERT(isfinite(d));
        dtoaRoundDP(m_significand, d, decimalPlaces, m_sign, m_exponent, m_precision);

        unsigned significantFigures = 1 + m_exponent + decimalPlaces;
        ASSERT(significantFigures && significantFigures <= sizeof(DtoaBuffer));
        while (m_precision < significantFigures)
            m_significand[m_precision++] = '0';

        ASSERT(m_precision);
        // Zero should always have exponent 0.
        ASSERT(m_significand[0] != '0' || !m_exponent);
    }

    WTF_EXPORT_PRIVATE unsigned bufferLengthForStringDecimal() const;
    WTF_EXPORT_PRIVATE unsigned bufferLengthForStringExponential() const;

    WTF_EXPORT_PRIVATE unsigned toStringDecimal(UChar* buffer, unsigned bufferLength) const;
    WTF_EXPORT_PRIVATE unsigned toStringExponential(UChar* buffer, unsigned bufferLength) const;

    bool sign() const { return m_sign; }
    int exponent() const { return m_exponent; }
    const char* significand() const { return m_significand; } // significand contains precision characters, is not null-terminated.
    unsigned precision() const { return m_precision; }

private:
    bool m_sign;
    int m_exponent;
    DtoaBuffer m_significand;
    unsigned m_precision;
};

} // namespace WTF

using WTF::DecimalNumber;
using WTF::RoundingSignificantFigures;
using WTF::RoundingDecimalPlaces;

#endif // DecimalNumber_h
