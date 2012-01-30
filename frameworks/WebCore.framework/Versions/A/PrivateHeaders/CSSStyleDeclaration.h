/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef CSSStyleDeclaration_h
#define CSSStyleDeclaration_h

#include "CSSRule.h"
#include <wtf/Forward.h>

namespace WebCore {

class CSSMutableStyleDeclaration;
class CSSProperty;
class CSSStyleSheet;
class CSSValue;
class StyledElement;

typedef int ExceptionCode;

class CSSStyleDeclaration : public RefCounted<CSSStyleDeclaration> {
    WTF_MAKE_NONCOPYABLE(CSSStyleDeclaration);
public:
    virtual ~CSSStyleDeclaration() { }

    static bool isPropertyName(const String&);

    CSSRule* parentRule() const { return m_isElementStyleDeclaration ? 0 : m_parent.rule; }
    void clearParentRule() { ASSERT(!m_isElementStyleDeclaration); m_parent.rule = 0; }

    StyledElement* parentElement() const { ASSERT(m_isElementStyleDeclaration); return m_parent.element; }
    void clearParentElement() { ASSERT(m_isElementStyleDeclaration); m_parent.element = 0; }

    CSSStyleSheet* parentStyleSheet() const;

    virtual String cssText() const = 0;
    virtual void setCssText(const String&, ExceptionCode&) = 0;

    unsigned length() const { return virtualLength(); }
    virtual unsigned virtualLength() const = 0;
    bool isEmpty() const { return !length(); }
    virtual String item(unsigned index) const = 0;

    PassRefPtr<CSSValue> getPropertyCSSValue(const String& propertyName);
    String getPropertyValue(const String& propertyName);
    String getPropertyPriority(const String& propertyName);
    String getPropertyShorthand(const String& propertyName);
    bool isPropertyImplicit(const String& propertyName);

    virtual PassRefPtr<CSSValue> getPropertyCSSValue(int propertyID) const = 0;
    virtual String getPropertyValue(int propertyID) const = 0;
    virtual bool getPropertyPriority(int propertyID) const = 0;
    virtual int getPropertyShorthand(int propertyID) const = 0;
    virtual bool isPropertyImplicit(int propertyID) const = 0;

    void setProperty(const String& propertyName, const String& value, const String& priority, ExceptionCode&);
    String removeProperty(const String& propertyName, ExceptionCode&);
    virtual void setProperty(int propertyId, const String& value, bool important, ExceptionCode&) = 0;
    virtual String removeProperty(int propertyID, ExceptionCode&) = 0;

    virtual PassRefPtr<CSSMutableStyleDeclaration> copy() const = 0;
    virtual PassRefPtr<CSSMutableStyleDeclaration> makeMutable() = 0;

    void diff(CSSMutableStyleDeclaration*) const;

    PassRefPtr<CSSMutableStyleDeclaration> copyPropertiesInSet(const int* set, unsigned length) const;

#ifndef NDEBUG
    void showStyle();
#endif

    bool isElementStyleDeclaration() const { return m_isElementStyleDeclaration; }
    bool isInlineStyleDeclaration() const { return m_isInlineStyleDeclaration; }

protected:
    CSSStyleDeclaration(CSSRule* parentRule = 0);
    CSSStyleDeclaration(StyledElement* parentElement, bool isInline);

    virtual bool cssPropertyMatches(const CSSProperty*) const;

    // The bits in this section are only used by specific subclasses but kept here
    // to maximize struct packing.

    // CSSMutableStyleDeclaration bits:
    bool m_strictParsing : 1;
#ifndef NDEBUG
    unsigned m_iteratorCount : 4;
#endif
    bool m_isElementStyleDeclaration : 1;
    bool m_isInlineStyleDeclaration : 1;

private:
    union Parent {
        Parent(CSSRule* rule) : rule(rule) { }
        Parent(StyledElement* element) : element(element) { }
        CSSRule* rule;
        StyledElement* element;
    } m_parent;
};

} // namespace WebCore

#endif // CSSStyleDeclaration_h
