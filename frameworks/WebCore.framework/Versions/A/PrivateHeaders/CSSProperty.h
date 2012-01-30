/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2004, 2005, 2006 Apple Computer, Inc.
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

#ifndef CSSProperty_h
#define CSSProperty_h

#include "CSSValue.h"
#include "RenderStyleConstants.h"
#include "TextDirection.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class CSSProperty {
    WTF_MAKE_FAST_ALLOCATED;
public:
    CSSProperty(unsigned propID, PassRefPtr<CSSValue> value, bool important = false, int shorthandID = 0, bool implicit = false)
        : m_id(propID)
        , m_shorthandID(shorthandID)
        , m_important(important)
        , m_implicit(implicit)
        , m_inherited(isInheritedProperty(propID))
        , m_value(value)
    {
    }

    int id() const { return m_id; }
    int shorthandID() const { return m_shorthandID; }

    bool isImportant() const { return m_important; }
    bool isImplicit() const { return m_implicit; }
    bool isInherited() const { return m_inherited; }

    CSSValue* value() const { return m_value.get(); }

    String cssText() const;

    static int resolveDirectionAwareProperty(int propertyID, TextDirection, WritingMode);
    static bool isInheritedProperty(unsigned propertyID);

    // Make sure the following fits in 4 bytes. Really.
    unsigned m_id : 14;
    unsigned m_shorthandID : 14; // If this property was set as part of a shorthand, gives the shorthand.
    bool m_important : 1;
    bool m_implicit : 1; // Whether or not the property was set implicitly as the result of a shorthand.
    bool m_inherited : 1;

    RefPtr<CSSValue> m_value;
};

} // namespace WebCore

namespace WTF {
    // Properties in Vector can be initialized with memset and moved using memcpy.
    template<> struct VectorTraits<WebCore::CSSProperty> : SimpleClassVectorTraits { };
}

#endif // CSSProperty_h
