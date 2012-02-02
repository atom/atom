/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
 *           (C) 2000 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Graham Dennis (graham.dennis@gmail.com)
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

#ifndef OutlineValue_h
#define OutlineValue_h

#include "BorderValue.h"

namespace WebCore {

class OutlineValue : public BorderValue {
friend class RenderStyle;
public:
    OutlineValue()
        : m_offset(0)
    {
    }
    
    bool operator==(const OutlineValue& o) const
    {
        return m_width == o.m_width && m_style == o.m_style && m_color == o.m_color && m_offset == o.m_offset && m_isAuto == o.m_isAuto;
    }
    
    bool operator!=(const OutlineValue& o) const
    {
        return !(*this == o);
    }
    
    int offset() const { return m_offset; }
    OutlineIsAuto isAuto() const { return static_cast<OutlineIsAuto>(m_isAuto); }

private:
    int m_offset;
};

} // namespace WebCore

#endif // OutlineValue_h
