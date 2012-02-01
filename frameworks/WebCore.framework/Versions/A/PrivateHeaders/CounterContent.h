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

#ifndef CounterContent_h
#define CounterContent_h

#include "RenderStyleConstants.h"
#include <wtf/text/AtomicString.h>

namespace WebCore {

class CounterContent {
    WTF_MAKE_FAST_ALLOCATED;
public:
    CounterContent(const AtomicString& identifier, EListStyleType style, const AtomicString& separator)
        : m_identifier(identifier)
        , m_listStyle(style)
        , m_separator(separator)
    {
    }

    const AtomicString& identifier() const { return m_identifier; }
    EListStyleType listStyle() const { return m_listStyle; }
    const AtomicString& separator() const { return m_separator; }

private:
    AtomicString m_identifier;
    EListStyleType m_listStyle;
    AtomicString m_separator;
};

static inline bool operator==(const CounterContent& a, const CounterContent& b)
{
    return a.identifier() == b.identifier()
        && a.listStyle() == b.listStyle()
        && a.separator() == b.separator();
}


} // namespace WebCore

#endif // CounterContent_h
