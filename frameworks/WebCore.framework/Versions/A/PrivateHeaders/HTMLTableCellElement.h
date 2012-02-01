/*
 * Copyright (C) 1997 Martin Jones (mjones@kde.org)
 *           (C) 1997 Torben Weis (weis@kde.org)
 *           (C) 1998 Waldo Bastian (bastian@kde.org)
 *           (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 * Copyright (C) 2003, 2004, 2005, 2006, 2010 Apple Inc. All rights reserved.
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

#ifndef HTMLTableCellElement_h
#define HTMLTableCellElement_h

#include "HTMLTablePartElement.h"

namespace WebCore {

class HTMLTableCellElement : public HTMLTablePartElement {
public:
    static PassRefPtr<HTMLTableCellElement> create(const QualifiedName&, Document*);

    int cellIndex() const;

    int colSpan() const;
    int rowSpan() const;

    void setCellIndex(int);

    String abbr() const;
    String axis() const;
    void setColSpan(int);
    String headers() const;
    void setRowSpan(int);
    String scope() const;

    HTMLTableCellElement* cellAbove() const;

private:
    HTMLTableCellElement(const QualifiedName&, Document*);

    virtual bool mapToEntry(const QualifiedName&, MappedAttributeEntry&) const;
    virtual void parseMappedAttribute(Attribute*);

    // used by table cells to share style decls created by the enclosing table.
    virtual bool canHaveAdditionalAttributeStyleDecls() const { return true; }
    virtual void additionalAttributeStyleDecls(Vector<CSSMutableStyleDeclaration*>&);
    
    virtual bool isURLAttribute(Attribute*) const;

    virtual void addSubresourceAttributeURLs(ListHashSet<KURL>&) const;
};

HTMLTableCellElement* toHTMLTableCellElement(Node* node);
const HTMLTableCellElement* toHTMLTableCellElement(const Node* node);

// This will catch anyone doing an unnecessary cast.
void toHTMLTableCellElement(const HTMLTableCellElement*);

#ifdef NDEBUG

// The debug versions of these, with assertions, are not inlined.

inline HTMLTableCellElement* toHTMLTableCellElement(Node* node)
{
    return static_cast<HTMLTableCellElement*>(node);
}

inline const HTMLTableCellElement* toHTMLTableCellElement(const Node* node)
{
    return static_cast<const HTMLTableCellElement*>(node);
}
#endif

} // namespace

#endif
