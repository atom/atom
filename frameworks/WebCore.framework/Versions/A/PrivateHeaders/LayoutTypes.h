/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// These typedefs are being used to abstract layout and hit testing off
// of integers and eventually replace them with floats. Once this transition
// is complete, these types will be removed. Progress can be tracked at
// https://bugs.webkit.org/show_bug.cgi?id=60318

#ifndef LayoutTypes_h
#define LayoutTypes_h

#include "FloatRect.h"
#include "IntRect.h"

namespace WebCore {

typedef int LayoutUnit;
typedef IntPoint LayoutPoint;
typedef IntSize LayoutSize;
typedef IntRect LayoutRect;

inline LayoutRect enclosingLayoutRect(const FloatRect& rect)
{
    return enclosingIntRect(rect);
}

inline LayoutSize roundedLayoutSize(const FloatSize& s)
{
    return roundedIntSize(s);
}

inline LayoutPoint roundedLayoutPoint(const FloatPoint& p)
{
    return roundedIntPoint(p);
}

inline LayoutPoint flooredLayoutPoint(const FloatPoint& p)
{
    return flooredIntPoint(p);
}

inline LayoutPoint flooredLayoutPoint(const FloatSize& s)
{
    return flooredIntPoint(s);
}

inline LayoutSize flooredLayoutSize(const FloatPoint& p)
{
    return LayoutSize(static_cast<int>(p.x()), static_cast<int>(p.y()));
}

inline LayoutUnit roundedLayoutUnit(float value)
{
    return lroundf(value);
}

inline LayoutUnit ceiledLayoutUnit(float value)
{
    return ceilf(value);
}

inline LayoutSize toLayoutSize(const LayoutPoint& p)
{
    return LayoutSize(p.x(), p.y());
}

inline LayoutPoint toLayoutPoint(const LayoutSize& p)
{
    return LayoutPoint(p.width(), p.height());
}

inline LayoutUnit layoutMod(const LayoutUnit& numerator, const LayoutUnit& denominator)
{
    return numerator % denominator;
}

} // namespace WebCore

#endif // LayoutTypes_h
