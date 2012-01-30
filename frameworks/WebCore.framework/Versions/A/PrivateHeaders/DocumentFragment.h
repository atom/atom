/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2001 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2009 Apple Inc. All rights reserved.
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

#ifndef DocumentFragment_h
#define DocumentFragment_h

#include "ContainerNode.h"
#include "FragmentScriptingPermission.h"

namespace WebCore {

class DocumentFragment : public ContainerNode {
public:
    static PassRefPtr<DocumentFragment> create(Document*);

    void parseHTML(const String&, Element* contextElement, FragmentScriptingPermission = FragmentScriptingAllowed);
    bool parseXML(const String&, Element* contextElement, FragmentScriptingPermission = FragmentScriptingAllowed);
    
    virtual bool canContainRangeEndPoint() const { return true; }

protected:
    DocumentFragment(Document*);
    virtual String nodeName() const;

private:
    virtual NodeType nodeType() const;
    virtual PassRefPtr<Node> cloneNode(bool deep);
    virtual bool childTypeAllowed(NodeType) const;
};

} //namespace

#endif
