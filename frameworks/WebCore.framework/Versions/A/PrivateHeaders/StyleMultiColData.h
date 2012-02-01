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

#ifndef StyleMultiColData_h
#define StyleMultiColData_h

#include "BorderValue.h"
#include "Length.h"
#include "RenderStyleConstants.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>

namespace WebCore {

// CSS3 Multi Column Layout

class StyleMultiColData : public RefCounted<StyleMultiColData> {
public:
    static PassRefPtr<StyleMultiColData> create() { return adoptRef(new StyleMultiColData); }
    PassRefPtr<StyleMultiColData> copy() const { return adoptRef(new StyleMultiColData(*this)); }
    
    bool operator==(const StyleMultiColData& o) const;
    bool operator!=(const StyleMultiColData &o) const
    {
        return !(*this == o);
    }

    unsigned short ruleWidth() const
    {
        if (m_rule.style() == BNONE || m_rule.style() == BHIDDEN)
            return 0; 
        return m_rule.width();
    }

    float m_width;
    unsigned short m_count;
    float m_gap;
    BorderValue m_rule;
    Color m_visitedLinkColumnRuleColor;

    bool m_autoWidth : 1;
    bool m_autoCount : 1;
    bool m_normalGap : 1;
    unsigned m_columnSpan : 1;
    unsigned m_breakBefore : 2; // EPageBreak
    unsigned m_breakAfter : 2; // EPageBreak
    unsigned m_breakInside : 2; // EPageBreak
    unsigned m_axis : 2; // ColumnAxis

private:
    StyleMultiColData();
    StyleMultiColData(const StyleMultiColData&);
};

} // namespace WebCore

#endif // StyleMultiColData_h
