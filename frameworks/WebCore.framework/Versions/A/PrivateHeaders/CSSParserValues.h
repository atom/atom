/*
 * Copyright (C) 2003 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef CSSParserValues_h
#define CSSParserValues_h

#include "CSSSelector.h"
#include "CSSValueList.h"
#include <wtf/text/AtomicString.h>

namespace WebCore {

class CSSValue;
class QualifiedName;

struct CSSParserString {
    UChar* characters;
    int length;

    void lower();

    operator String() const { return String(characters, length); }
    operator AtomicString() const { return AtomicString(characters, length); }
};

struct CSSParserFunction;

struct CSSParserValue {
    int id;
    bool isInt;
    union {
        double fValue;
        int iValue;
        CSSParserString string;
        CSSParserFunction* function;
    };
    enum {
        Operator = 0x100000,
        Function = 0x100001,
        Q_EMS    = 0x100002
    };
    int unit;


    PassRefPtr<CSSValue> createCSSValue();
};

class CSSParserValueList {
    WTF_MAKE_FAST_ALLOCATED;
public:
    CSSParserValueList()
        : m_current(0)
    {
    }
    ~CSSParserValueList();

    void addValue(const CSSParserValue&);
    void insertValueAt(unsigned, const CSSParserValue&);
    void deleteValueAt(unsigned);
    void extend(CSSParserValueList&);

    unsigned size() const { return m_values.size(); }
    CSSParserValue* current() { return m_current < m_values.size() ? &m_values[m_current] : 0; }
    CSSParserValue* next() { ++m_current; return current(); }
    CSSParserValue* previous()
    {
        if (!m_current)
            return 0;
        --m_current;
        return current();
    }

    CSSParserValue* valueAt(unsigned i) { return i < m_values.size() ? &m_values[i] : 0; }

    void clear() { m_values.clear(); }

private:
    unsigned m_current;
    Vector<CSSParserValue, 4> m_values;
};

struct CSSParserFunction {
    WTF_MAKE_FAST_ALLOCATED;
public:
    CSSParserString name;
    OwnPtr<CSSParserValueList> args;
};

class CSSParserSelector {
    WTF_MAKE_FAST_ALLOCATED;
public:
    CSSParserSelector();
    ~CSSParserSelector();

    PassOwnPtr<CSSSelector> releaseSelector() { return m_selector.release(); }

    void setTag(const QualifiedName& value) { m_selector->setTag(value); }
    void setValue(const AtomicString& value) { m_selector->setValue(value); }
    void setAttribute(const QualifiedName& value) { m_selector->setAttribute(value); }
    void setArgument(const AtomicString& value) { m_selector->setArgument(value); }
    void setMatch(CSSSelector::Match value) { m_selector->m_match = value; }
    void setRelation(CSSSelector::Relation value) { m_selector->m_relation = value; }
    void setForPage() { m_selector->setForPage(); }

    void adoptSelectorVector(Vector<OwnPtr<CSSParserSelector> >& selectorVector);

    CSSSelector::PseudoType pseudoType() const { return m_selector->pseudoType(); }
    bool isUnknownPseudoElement() const { return m_selector->isUnknownPseudoElement(); }
    bool isSimple() const { return !m_tagHistory && m_selector->isSimple(); }
    bool hasShadowDescendant() const;

    CSSParserSelector* tagHistory() const { return m_tagHistory.get(); }
    void setTagHistory(PassOwnPtr<CSSParserSelector> selector) { m_tagHistory = selector; }
    void insertTagHistory(CSSSelector::Relation before, PassOwnPtr<CSSParserSelector>, CSSSelector::Relation after);
    void appendTagHistory(CSSSelector::Relation, PassOwnPtr<CSSParserSelector>);

private:
    OwnPtr<CSSSelector> m_selector;
    OwnPtr<CSSParserSelector> m_tagHistory;
};

inline bool CSSParserSelector::hasShadowDescendant() const
{
    return m_selector->relation() == CSSSelector::ShadowDescendant;
}

}

#endif
