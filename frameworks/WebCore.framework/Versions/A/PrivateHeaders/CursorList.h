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

#ifndef CursorList_h
#define CursorList_h

#include "CursorData.h"
#include <wtf/RefCounted.h>
#include <wtf/Vector.h>

namespace WebCore {

class CursorList : public RefCounted<CursorList> {
public:
    static PassRefPtr<CursorList> create()
    {
        return adoptRef(new CursorList);
    }

    const CursorData& operator[](int i) const { return m_vector[i]; }
    CursorData& operator[](int i) { return m_vector[i]; }
    const CursorData& at(size_t i) const { return m_vector.at(i); }
    CursorData& at(size_t i) { return m_vector.at(i); }

    bool operator==(const CursorList& o) const { return m_vector == o.m_vector; }
    bool operator!=(const CursorList& o) const { return m_vector != o.m_vector; }

    size_t size() const { return m_vector.size(); }
    void append(const CursorData& cursorData) { m_vector.append(cursorData); }

private:
    CursorList()
    {
    }

    Vector<CursorData> m_vector;
};

} // namespace WebCore

#endif // CursorList_h
