/*
    Copyright (C) 1999 Lars Knoll (knoll@kde.org)
    Copyright (C) 2006, 2008 Apple Inc. All rights reserved.

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

#ifndef LengthSize_h
#define LengthSize_h

#include "Length.h"

namespace WebCore {

struct LengthSize {
public:
    LengthSize()
    {
    }
    
    LengthSize(Length width, Length height)
        : m_width(width)
        , m_height(height)
    {
    }

    bool operator==(const LengthSize& o) const
    {
        return m_width == o.m_width && m_height == o.m_height;
    }

    void setWidth(Length width) { m_width = width; }
    Length width() const { return m_width; }

    void setHeight(Length height) { m_height = height; }
    Length height() const { return m_height; }

private:
    Length m_width;
    Length m_height;
};

} // namespace WebCore

#endif // LengthSize_h
