/*
 * Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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
 *
 */

#ifndef RenderOverflow_h
#define RenderOverflow_h

#include "LayoutTypes.h"

namespace WebCore
{
// RenderOverflow is a class for tracking content that spills out of a box.  This class is used by RenderBox and
// InlineFlowBox.
//
// There are two types of overflow: layout overflow (which is expected to be reachable via scrolling mechanisms) and
// visual overflow (which is not expected to be reachable via scrolling mechanisms).
//
// Layout overflow examples include other boxes that spill out of our box,  For example, in the inline case a tall image
// could spill out of a line box. 
    
// Examples of visual overflow are shadows, text stroke (and eventually outline and border-image).

// This object is allocated only when some of these fields have non-default values in the owning box.
class RenderOverflow {
    WTF_MAKE_NONCOPYABLE(RenderOverflow); WTF_MAKE_FAST_ALLOCATED;
public:
    RenderOverflow(const LayoutRect& layoutRect, const LayoutRect& visualRect) 
        : m_minYLayoutOverflow(layoutRect.y())
        , m_maxYLayoutOverflow(layoutRect.maxY())
        , m_minXLayoutOverflow(layoutRect.x())
        , m_maxXLayoutOverflow(layoutRect.maxX())
        , m_minYVisualOverflow(visualRect.y())
        , m_maxYVisualOverflow(visualRect.maxY())
        , m_minXVisualOverflow(visualRect.x())
        , m_maxXVisualOverflow(visualRect.maxX())
    {
    }
   
    LayoutUnit minYLayoutOverflow() const { return m_minYLayoutOverflow; }
    LayoutUnit maxYLayoutOverflow() const { return m_maxYLayoutOverflow; }
    LayoutUnit minXLayoutOverflow() const { return m_minXLayoutOverflow; }
    LayoutUnit maxXLayoutOverflow() const { return m_maxXLayoutOverflow; }
    LayoutRect layoutOverflowRect() const;

    LayoutUnit minYVisualOverflow() const { return m_minYVisualOverflow; }
    LayoutUnit maxYVisualOverflow() const { return m_maxYVisualOverflow; }
    LayoutUnit minXVisualOverflow() const { return m_minXVisualOverflow; }
    LayoutUnit maxXVisualOverflow() const { return m_maxXVisualOverflow; }
    LayoutRect visualOverflowRect() const;

    void setMinYLayoutOverflow(LayoutUnit overflow) { m_minYLayoutOverflow = overflow; }
    void setMaxYLayoutOverflow(LayoutUnit overflow) { m_maxYLayoutOverflow = overflow; }
    void setMinXLayoutOverflow(LayoutUnit overflow) { m_minXLayoutOverflow = overflow; }
    void setMaxXLayoutOverflow(LayoutUnit overflow) { m_maxXLayoutOverflow = overflow; }
    
    void setMinYVisualOverflow(LayoutUnit overflow) { m_minYVisualOverflow = overflow; }
    void setMaxYVisualOverflow(LayoutUnit overflow) { m_maxYVisualOverflow = overflow; }
    void setMinXVisualOverflow(LayoutUnit overflow) { m_minXVisualOverflow = overflow; }
    void setMaxXVisualOverflow(LayoutUnit overflow) { m_maxXVisualOverflow = overflow; }
    
    void move(LayoutUnit dx, LayoutUnit dy);
    
    void addLayoutOverflow(const LayoutRect&);
    void addVisualOverflow(const LayoutRect&);

    void setLayoutOverflow(const LayoutRect&);
    void setVisualOverflow(const LayoutRect&);

    void resetLayoutOverflow(const LayoutRect& defaultRect);

private:
    LayoutUnit m_minYLayoutOverflow;
    LayoutUnit m_maxYLayoutOverflow;
    LayoutUnit m_minXLayoutOverflow;
    LayoutUnit m_maxXLayoutOverflow;

    LayoutUnit m_minYVisualOverflow;
    LayoutUnit m_maxYVisualOverflow;
    LayoutUnit m_minXVisualOverflow;
    LayoutUnit m_maxXVisualOverflow;
};

inline LayoutRect RenderOverflow::layoutOverflowRect() const
{
    return LayoutRect(m_minXLayoutOverflow, m_minYLayoutOverflow, m_maxXLayoutOverflow - m_minXLayoutOverflow, m_maxYLayoutOverflow - m_minYLayoutOverflow);
}

inline LayoutRect RenderOverflow::visualOverflowRect() const
{
    return LayoutRect(m_minXVisualOverflow, m_minYVisualOverflow, m_maxXVisualOverflow - m_minXVisualOverflow, m_maxYVisualOverflow - m_minYVisualOverflow);
}

inline void RenderOverflow::move(LayoutUnit dx, LayoutUnit dy)
{
    m_minYLayoutOverflow += dy;
    m_maxYLayoutOverflow += dy;
    m_minXLayoutOverflow += dx;
    m_maxXLayoutOverflow += dx;
    
    m_minYVisualOverflow += dy;
    m_maxYVisualOverflow += dy;
    m_minXVisualOverflow += dx;
    m_maxXVisualOverflow += dx;
}

inline void RenderOverflow::addLayoutOverflow(const LayoutRect& rect)
{
    m_minYLayoutOverflow = std::min(rect.y(), m_minYLayoutOverflow);
    m_maxYLayoutOverflow = std::max(rect.maxY(), m_maxYLayoutOverflow);
    m_minXLayoutOverflow = std::min(rect.x(), m_minXLayoutOverflow);
    m_maxXLayoutOverflow = std::max(rect.maxX(), m_maxXLayoutOverflow);
}

inline void RenderOverflow::addVisualOverflow(const LayoutRect& rect)
{
    m_minYVisualOverflow = std::min(rect.y(), m_minYVisualOverflow);
    m_maxYVisualOverflow = std::max(rect.maxY(), m_maxYVisualOverflow);
    m_minXVisualOverflow = std::min(rect.x(), m_minXVisualOverflow);
    m_maxXVisualOverflow = std::max(rect.maxX(), m_maxXVisualOverflow);
}

inline void RenderOverflow::setLayoutOverflow(const LayoutRect& rect)
{
    m_minYLayoutOverflow = rect.y();
    m_maxYLayoutOverflow = rect.maxY();
    m_minXLayoutOverflow = rect.x();
    m_maxXLayoutOverflow = rect.maxX();
}

inline void RenderOverflow::setVisualOverflow(const LayoutRect& rect)
{
    m_minYVisualOverflow = rect.y();
    m_maxYVisualOverflow = rect.maxY();
    m_minXVisualOverflow = rect.x();
    m_maxXVisualOverflow = rect.maxX();
}

inline void RenderOverflow::resetLayoutOverflow(const LayoutRect& rect)
{
    m_minYLayoutOverflow = rect.y();
    m_maxYLayoutOverflow = rect.maxY();
    m_minXLayoutOverflow = rect.x();
    m_maxXLayoutOverflow = rect.maxX();
}

} // namespace WebCore

#endif // RenderOverflow_h
