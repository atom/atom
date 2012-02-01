/*
 * Copyright (C) 2007, 2008, 2010, 2011, 2012 Apple Inc. All rights reserved.
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
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#ifndef SpaceSplitString_h
#define SpaceSplitString_h

#include <wtf/RefCounted.h>
#include <wtf/Vector.h>
#include <wtf/text/AtomicString.h>

namespace WebCore {

    class SpaceSplitStringData : public RefCounted<SpaceSplitStringData> {
    public:
        static PassRefPtr<SpaceSplitStringData> create(const AtomicString&);
        static PassRefPtr<SpaceSplitStringData> createUnique(const SpaceSplitStringData&);

        ~SpaceSplitStringData();

        bool contains(const AtomicString& string)
        {
            size_t size = m_vector.size();
            for (size_t i = 0; i < size; ++i) {
                if (m_vector[i] == string)
                    return true;
            }
            return false;
        }

        bool containsAll(SpaceSplitStringData&);

        void add(const AtomicString&);
        void remove(const AtomicString&);

        size_t size() const { return m_vector.size(); }
        const AtomicString& operator[](size_t i) { ASSERT(i < size()); return m_vector[i]; }

    private:
        SpaceSplitStringData(const AtomicString&);
        SpaceSplitStringData(const SpaceSplitStringData&);

        void createVector(const String&);

        AtomicString m_keyString;
        Vector<AtomicString, 4> m_vector;
    };

    class SpaceSplitString {
    public:
        SpaceSplitString() { }
        SpaceSplitString(const AtomicString& string, bool shouldFoldCase) { set(string, shouldFoldCase); }

        void set(const AtomicString&, bool shouldFoldCase);
        void clear() { m_data.clear(); }

        bool contains(const AtomicString& string) const { return m_data && m_data->contains(string); }
        bool containsAll(const SpaceSplitString& names) const { return !names.m_data || (m_data && m_data->containsAll(*names.m_data)); }
        void add(const AtomicString&);
        void remove(const AtomicString&);

        size_t size() const { return m_data ? m_data->size() : 0; }
        bool isNull() const { return !m_data; }
        const AtomicString& operator[](size_t i) const { ASSERT(i < size()); return (*m_data)[i]; }

    private:
        void ensureUnique()
        {
            if (m_data && !m_data->hasOneRef())
                m_data = SpaceSplitStringData::createUnique(*m_data);
        }

        RefPtr<SpaceSplitStringData> m_data;
    };

} // namespace WebCore

#endif // SpaceSplitString_h
