/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
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

#ifndef SMILTime_h
#define SMILTime_h

#if ENABLE(SVG)

#include <algorithm>

namespace WebCore {

class SMILTime {
public:
    SMILTime() : m_time(0) { }
    SMILTime(double time) : m_time(time) { }
    SMILTime(const SMILTime& o) : m_time(o.m_time) { }
    
    static SMILTime unresolved() { return unresolvedValue; }
    static SMILTime indefinite() { return indefiniteValue; }
    
    SMILTime& operator=(const SMILTime& o) { m_time = o.m_time; return *this; }
    double value() const { return m_time; }
    
    bool isFinite() const { return m_time < indefiniteValue; }
    bool isIndefinite() const { return m_time == indefiniteValue; }
    bool isUnresolved() const { return m_time == unresolvedValue; }
    
private:
    static const double unresolvedValue;
    static const double indefiniteValue;

    double m_time;
};

inline bool operator==(const SMILTime& a, const SMILTime& b) { return a.isFinite() && a.value() == b.value(); }
inline bool operator!(const SMILTime& a) { return !a.isFinite() || !a.value(); }
inline bool operator!=(const SMILTime& a, const SMILTime& b) { return !operator==(a, b); }
inline bool operator>(const SMILTime& a, const SMILTime& b) { return a.value() > b.value(); }
inline bool operator<(const SMILTime& a, const SMILTime& b) { return a.value() < b.value(); }
inline bool operator>=(const SMILTime& a, const SMILTime& b) { return a.value() > b.value() || operator==(a, b); }
inline bool operator<=(const SMILTime& a, const SMILTime& b) { return a.value() < b.value() || operator==(a, b); }

SMILTime operator+(const SMILTime&, const SMILTime&);
SMILTime operator-(const SMILTime&, const SMILTime&);
// So multiplying times does not make too much sense but SMIL defines it for duration * repeatCount
SMILTime operator*(const SMILTime&, const SMILTime&);

}

#endif // ENABLE(SVG)
#endif // SMILTime_h
