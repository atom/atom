/*
 * Copyright (C) 2010, 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef Region_h
#define Region_h

#include "IntRect.h"
#include <wtf/Vector.h>

namespace WebCore {

class Region {
public:
    Region();
    Region(const IntRect&);

    IntRect bounds() const { return m_bounds; }
    bool isEmpty() const { return m_bounds.isEmpty(); }

    Vector<IntRect> rects() const;

    void unite(const Region&);
    void intersect(const Region&);
    void subtract(const Region&);

    void translate(const IntSize&);

#ifndef NDEBUG
    void dump() const;
#endif

private:
    struct Span {
        Span(int y, size_t segmentIndex)
            : y(y), segmentIndex(segmentIndex)
        {
        }

        int y;
        size_t segmentIndex;
    };

    class Shape {
    public:
        Shape();
        Shape(const IntRect&);

        IntRect bounds() const;
        bool isEmpty() const { return m_spans.isEmpty(); }

        typedef const Span* SpanIterator;
        SpanIterator spans_begin() const;
        SpanIterator spans_end() const;
        
        typedef const int* SegmentIterator;
        SegmentIterator segments_begin(SpanIterator) const;
        SegmentIterator segments_end(SpanIterator) const;

        static Shape unionShapes(const Shape& shape1, const Shape& shape2);
        static Shape intersectShapes(const Shape& shape1, const Shape& shape2);
        static Shape subtractShapes(const Shape& shape1, const Shape& shape2);

        void translate(const IntSize&);
        void swap(Shape&);

#ifndef NDEBUG
        void dump() const;
#endif

    private:
        struct UnionOperation;
        struct IntersectOperation;
        struct SubtractOperation;
        
        template<typename Operation>
        static Shape shapeOperation(const Shape& shape1, const Shape& shape2);

        void appendSegment(int x);
        void appendSpan(int y);
        void appendSpan(int y, SegmentIterator begin, SegmentIterator end);
        void appendSpans(const Shape&, SpanIterator begin, SpanIterator end);

        bool canCoalesce(SegmentIterator begin, SegmentIterator end);

        // FIXME: These vectors should have inline sizes. Figure out a good optimal value.
        Vector<int> m_segments;
        Vector<Span> m_spans;        
    };

    IntRect m_bounds;
    Shape m_shape;
};

static inline Region intersect(const Region& a, const Region& b)
{
    Region result(a);
    result.intersect(b);

    return result;
}
    
static inline Region subtract(const Region& a, const Region& b)
{
    Region result(a);
    result.subtract(b);

    return result;
}

static inline Region translate(const Region& region, const IntSize& offset)
{
    Region result(region);
    result.translate(offset);

    return result;
}

} // namespace WebCore

#endif // Region_h
