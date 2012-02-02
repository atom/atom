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

#ifndef StyleReflection_h
#define StyleReflection_h

#include "CSSReflectionDirection.h"
#include "Length.h"
#include "NinePieceImage.h"
#include <wtf/RefCounted.h>

namespace WebCore {

class StyleReflection : public RefCounted<StyleReflection> {
public:
    static PassRefPtr<StyleReflection> create()
    {
        return adoptRef(new StyleReflection);
    }

    bool operator==(const StyleReflection& o) const
    {
        return m_direction == o.m_direction && m_offset == o.m_offset && m_mask == o.m_mask;
    }
    bool operator!=(const StyleReflection& o) const { return !(*this == o); }

    CSSReflectionDirection direction() const { return m_direction; }
    Length offset() const { return m_offset; }
    const NinePieceImage& mask() const { return m_mask; }

    void setDirection(CSSReflectionDirection dir) { m_direction = dir; }
    void setOffset(const Length& l) { m_offset = l; }
    void setMask(const NinePieceImage& image) { m_mask = image; }

private:
    StyleReflection()
        : m_direction(ReflectionBelow)
        , m_offset(0, Fixed)
    {
         m_mask.setMaskDefaults();
    }
    
    CSSReflectionDirection m_direction;
    Length m_offset;
    NinePieceImage m_mask;
};

} // namespace WebCore

#endif // StyleReflection_h
