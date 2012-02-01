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

#ifndef StyleBackgroundData_h
#define StyleBackgroundData_h

#include "Color.h"
#include "FillLayer.h"
#include "OutlineValue.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>

namespace WebCore {

class StyleBackgroundData : public RefCounted<StyleBackgroundData> {
public:
    static PassRefPtr<StyleBackgroundData> create() { return adoptRef(new StyleBackgroundData); }
    PassRefPtr<StyleBackgroundData> copy() const { return adoptRef(new StyleBackgroundData(*this)); }
    ~StyleBackgroundData() { }

    bool operator==(const StyleBackgroundData& o) const;
    bool operator!=(const StyleBackgroundData& o) const
    {
        return !(*this == o);
    }

    const FillLayer& background() const { return m_background; }
    const Color& color() const { return m_color; }
    const OutlineValue& outline() const { return m_outline; }

private:
    friend class RenderStyle;

    StyleBackgroundData();
    StyleBackgroundData(const StyleBackgroundData&); 

    FillLayer m_background;
    Color m_color;
    OutlineValue m_outline;
};

} // namespace WebCore

#endif // StyleBackgroundData_h
