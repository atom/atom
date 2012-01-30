/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2001 Peter Kelly (pmk@post.com)
 *           (C) 2001 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef StyledElement_h
#define StyledElement_h

#include "CSSMutableStyleDeclaration.h"
#include "Element.h"
#include "MappedAttributeEntry.h"

namespace WebCore {

class Attribute;
class CSSMappedAttributeDeclaration;

class StyledElement : public Element {
public:
    virtual ~StyledElement();

    size_t mappedAttributeCount() const { return attributeMap() ? attributeMap()->mappedAttributeCount() : 0; }
    bool isMappedAttribute(const QualifiedName& name) const { MappedAttributeEntry res = eNone; mapToEntry(name, res); return res != eNone; }

    void addCSSLength(Attribute*, int id, const String& value);
    void addCSSProperty(Attribute*, int id, const String& value);
    void addCSSProperty(Attribute*, int id, int value);
    void addCSSImageProperty(Attribute*, int propertyID, const String& url);
    void addCSSColor(Attribute*, int id, const String& color);
    void removeCSSProperty(Attribute*, int id);

    static CSSMappedAttributeDeclaration* getMappedAttributeDecl(MappedAttributeEntry, const QualifiedName& name, const AtomicString& value);
    static void setMappedAttributeDecl(MappedAttributeEntry, const QualifiedName& name, const AtomicString& value, CSSMappedAttributeDeclaration*);
    static void removeMappedAttributeDecl(MappedAttributeEntry, const QualifiedName& name, const AtomicString& value);

    static CSSMappedAttributeDeclaration* getMappedAttributeDecl(MappedAttributeEntry, Attribute*);
    static void setMappedAttributeDecl(MappedAttributeEntry, Attribute*, CSSMappedAttributeDeclaration*);

    virtual bool canHaveAdditionalAttributeStyleDecls() const { return false; }
    virtual void additionalAttributeStyleDecls(Vector<CSSMutableStyleDeclaration*>&) { }
    void invalidateStyleAttribute();

    CSSMutableStyleDeclaration* inlineStyleDecl() const { return m_inlineStyleDecl.get(); }
    CSSMutableStyleDeclaration* ensureInlineStyleDecl();
    virtual CSSStyleDeclaration* style() OVERRIDE;

    const SpaceSplitString& classNames() const;

    virtual bool mapToEntry(const QualifiedName& attrName, MappedAttributeEntry& result) const;

    virtual PassRefPtr<Attribute> createAttribute(const QualifiedName&, const AtomicString& value);

protected:
    StyledElement(const QualifiedName& name, Document* document, ConstructionType type)
        : Element(name, document, type)
    {
    }

    virtual void attributeChanged(Attribute*, bool preserveDecls = false);
    virtual void parseMappedAttribute(Attribute*);
    virtual void copyNonAttributeProperties(const Element*);

    virtual void addSubresourceAttributeURLs(ListHashSet<KURL>&) const;

    // classAttributeChanged() exists to share code between
    // parseMappedAttribute (called via setAttribute()) and
    // svgAttributeChanged (called when element.className.baseValue is set)
    void classAttributeChanged(const AtomicString& newClassString);

private:
    void createMappedDecl(Attribute*);

    void createInlineStyleDecl();
    void destroyInlineStyleDecl();
    virtual void updateStyleAttribute() const;

    RefPtr<CSSMutableStyleDeclaration> m_inlineStyleDecl;
};

inline const SpaceSplitString& StyledElement::classNames() const
{
    ASSERT(hasClass());
    ASSERT(attributeMap());
    return attributeMap()->classNames();
}

inline void StyledElement::invalidateStyleAttribute()
{
    clearIsStyleAttributeValid();
}

} //namespace

#endif
