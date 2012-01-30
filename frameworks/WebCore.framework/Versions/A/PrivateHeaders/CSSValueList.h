/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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
 */

#ifndef CSSValueList_h
#define CSSValueList_h

#include "CSSValue.h"
#include <wtf/PassRefPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

class CSSParserValueList;

class CSSValueList : public CSSValue {
public:
    static PassRefPtr<CSSValueList> createCommaSeparated()
    {
        return adoptRef(new CSSValueList(CommaSeparator));
    }
    static PassRefPtr<CSSValueList> createSpaceSeparated()
    {
        return adoptRef(new CSSValueList(SpaceSeparator));
    }
    static PassRefPtr<CSSValueList> createSlashSeparated()
    {
        return adoptRef(new CSSValueList(SlashSeparator));
    }
    static PassRefPtr<CSSValueList> createFromParserValueList(CSSParserValueList* list)
    {
        return adoptRef(new CSSValueList(list));
    }

    size_t length() const { return m_values.size(); }
    CSSValue* item(size_t index) { return index < m_values.size() ? m_values[index].get() : 0; }
    CSSValue* itemWithoutBoundsCheck(size_t index) { return m_values[index].get(); }

    void append(PassRefPtr<CSSValue>);
    void prepend(PassRefPtr<CSSValue>);
    bool removeAll(CSSValue*);
    bool hasValue(CSSValue*) const;
    PassRefPtr<CSSValueList> copy();

    String customCssText() const;

    void addSubresourceStyleURLs(ListHashSet<KURL>&, const CSSStyleSheet*);

protected:
    CSSValueList(ClassType, ValueListSeparator);

private:
    explicit CSSValueList(ValueListSeparator);
    explicit CSSValueList(CSSParserValueList*);

    Vector<RefPtr<CSSValue> > m_values;
};

// Objects of this class are intended to be stack-allocated and scoped to a single function.
// Please take care not to pass these around as they do hold onto a raw pointer.
class CSSValueListInspector {
public:
    CSSValueListInspector(CSSValue* value) : m_list((value && value->isValueList()) ? static_cast<CSSValueList*>(value) : 0) { }
    CSSValue* item(size_t index) const { ASSERT(index < length()); return m_list->itemWithoutBoundsCheck(index); }
    CSSValue* first() const { return item(0); }
    CSSValue* second() const { return item(1); }
    size_t length() const { return m_list ? m_list->length() : 0; }
private:
    CSSValueList* m_list;
};

// Wrapper that can be used to iterate over any CSSValue. Non-list values and 0 behave as zero-length lists.
// Objects of this class are intended to be stack-allocated and scoped to a single function.
// Please take care not to pass these around as they do hold onto a raw pointer.
class CSSValueListIterator {
public:
    CSSValueListIterator(CSSValue* value) : m_inspector(value), m_position(0) { }
    bool hasMore() const { return m_position < m_inspector.length(); }
    CSSValue* value() const { return m_inspector.item(m_position); }
    bool isPrimitiveValue() const { return value()->isPrimitiveValue(); }
    void advance() { m_position++; ASSERT(m_position <= m_inspector.length());}
    size_t index() const { return m_position; }
private:
    CSSValueListInspector m_inspector;
    size_t m_position;
};
} // namespace WebCore

#endif // CSSValueList_h
