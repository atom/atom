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

#ifndef StyleMarqueeData_h
#define StyleMarqueeData_h

#include "Length.h"
#include "RenderStyleConstants.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>

namespace WebCore {

class StyleMarqueeData : public RefCounted<StyleMarqueeData> {
public:
    static PassRefPtr<StyleMarqueeData> create() { return adoptRef(new StyleMarqueeData); }
    PassRefPtr<StyleMarqueeData> copy() const { return adoptRef(new StyleMarqueeData(*this)); }

    bool operator==(const StyleMarqueeData& o) const;
    bool operator!=(const StyleMarqueeData& o) const
    {
        return !(*this == o);
    }

    Length increment;
    int speed;

    int loops; // -1 means infinite.

    unsigned behavior : 2; // EMarqueeBehavior 
    EMarqueeDirection direction : 3; // not unsigned because EMarqueeDirection has negative values

private:
    StyleMarqueeData();
    StyleMarqueeData(const StyleMarqueeData&);
};

} // namespace WebCore

#endif // StyleMarqueeData_h
