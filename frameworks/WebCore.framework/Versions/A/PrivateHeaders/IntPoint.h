/*
 * Copyright (C) 2004, 2005, 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef IntPoint_h
#define IntPoint_h

#include "IntSize.h"
#include <wtf/MathExtras.h>

#if PLATFORM(QT)
#include <QDataStream>
#endif

#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
typedef struct CGPoint CGPoint;
#endif


#if OS(DARWIN) && !PLATFORM(QT)
#ifdef NSGEOMETRY_TYPES_SAME_AS_CGGEOMETRY_TYPES
typedef struct CGPoint NSPoint;
#else
typedef struct _NSPoint NSPoint;
#endif
#endif

#if PLATFORM(WIN)
typedef struct tagPOINT POINT;
typedef struct tagPOINTS POINTS;
#elif PLATFORM(QT)
QT_BEGIN_NAMESPACE
class QPoint;
QT_END_NAMESPACE
#elif PLATFORM(GTK)
typedef struct _GdkPoint GdkPoint;
#elif PLATFORM(EFL)
typedef struct _Evas_Point Evas_Point;
#endif

#if PLATFORM(WX)
class wxPoint;
#endif

#if USE(SKIA)
struct SkPoint;
struct SkIPoint;
#endif

namespace WebCore {

class IntPoint {
public:
    IntPoint() : m_x(0), m_y(0) { }
    IntPoint(int x, int y) : m_x(x), m_y(y) { }
    explicit IntPoint(const IntSize& size) : m_x(size.width()), m_y(size.height()) { }

    static IntPoint zero() { return IntPoint(); }

    int x() const { return m_x; }
    int y() const { return m_y; }

    void setX(int x) { m_x = x; }
    void setY(int y) { m_y = y; }

    void move(const IntSize& s) { move(s.width(), s.height()); } 
    void moveBy(const IntPoint& offset) { move(offset.x(), offset.y()); }
    void move(int dx, int dy) { m_x += dx; m_y += dy; }
    void scale(float sx, float sy)
    {
        m_x = lroundf(static_cast<float>(m_x * sx));
        m_y = lroundf(static_cast<float>(m_y * sy));
    }
    
    IntPoint expandedTo(const IntPoint& other) const
    {
        return IntPoint(m_x > other.m_x ? m_x : other.m_x,
            m_y > other.m_y ? m_y : other.m_y);
    }

    IntPoint shrunkTo(const IntPoint& other) const
    {
        return IntPoint(m_x < other.m_x ? m_x : other.m_x,
            m_y < other.m_y ? m_y : other.m_y);
    }

    void clampNegativeToZero()
    {
        *this = expandedTo(zero());
    }

    IntPoint transposedPoint() const
    {
        return IntPoint(m_y, m_x);
    }

#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
    explicit IntPoint(const CGPoint&); // don't do this implicitly since it's lossy
    operator CGPoint() const;
#endif

#if OS(DARWIN) && !PLATFORM(QT) && !defined(NSGEOMETRY_TYPES_SAME_AS_CGGEOMETRY_TYPES)
    explicit IntPoint(const NSPoint&); // don't do this implicitly since it's lossy
    operator NSPoint() const;
#endif

#if PLATFORM(WIN)
    IntPoint(const POINT&);
    operator POINT() const;
    IntPoint(const POINTS&);
    operator POINTS() const;
#elif PLATFORM(QT)
    IntPoint(const QPoint&);
    operator QPoint() const;
#elif PLATFORM(GTK)
    IntPoint(const GdkPoint&);
    operator GdkPoint() const;
#elif PLATFORM(EFL)
    explicit IntPoint(const Evas_Point&);
    operator Evas_Point() const;
#endif

#if PLATFORM(WX)
    IntPoint(const wxPoint&);
    operator wxPoint() const;
#endif

#if USE(SKIA)
    IntPoint(const SkIPoint&);
    operator SkIPoint() const;
    operator SkPoint() const;
#endif

private:
    int m_x, m_y;
};

inline IntPoint& operator+=(IntPoint& a, const IntSize& b)
{
    a.move(b.width(), b.height());
    return a;
}

inline IntPoint& operator-=(IntPoint& a, const IntSize& b)
{
    a.move(-b.width(), -b.height());
    return a;
}

inline IntPoint operator+(const IntPoint& a, const IntSize& b)
{
    return IntPoint(a.x() + b.width(), a.y() + b.height());
}

inline IntPoint operator+(const IntPoint& a, const IntPoint& b)
{
    return IntPoint(a.x() + b.x(), a.y() + b.y());
}

inline IntSize operator-(const IntPoint& a, const IntPoint& b)
{
    return IntSize(a.x() - b.x(), a.y() - b.y());
}

inline IntPoint operator-(const IntPoint& a, const IntSize& b)
{
    return IntPoint(a.x() - b.width(), a.y() - b.height());
}

inline IntPoint operator-(const IntPoint& point)
{
    return IntPoint(-point.x(), -point.y());
}

inline bool operator==(const IntPoint& a, const IntPoint& b)
{
    return a.x() == b.x() && a.y() == b.y();
}

inline bool operator!=(const IntPoint& a, const IntPoint& b)
{
    return a.x() != b.x() || a.y() != b.y();
}

inline IntPoint toPoint(const IntSize& size)
{
    return IntPoint(size.width(), size.height());
}

inline IntSize toSize(const IntPoint& a)
{
    return IntSize(a.x(), a.y());
}

#if PLATFORM(QT)
inline QDataStream& operator<<(QDataStream& stream, const IntPoint& point)
{
    stream << point.x() << point.y();
    return stream;
}

inline QDataStream& operator>>(QDataStream& stream, IntPoint& point)
{
    int x, y;
    stream >> x >> y;
    point.setX(x);
    point.setY(y);
    return stream;
}
#endif

} // namespace WebCore

#endif // IntPoint_h
