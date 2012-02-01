/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 * Copyright (C) 2003, 2004, 2005, 2006, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef CharacterData_h
#define CharacterData_h

#include "Node.h"
#include <wtf/text/WTFString.h>

namespace WebCore {

class CharacterData : public Node {
public:
    String data() const { return m_data; }
    void setData(const String&, ExceptionCode&);
    unsigned length() const { return m_data.length(); }
    String substringData(unsigned offset, unsigned count, ExceptionCode&);
    void appendData(const String&, ExceptionCode&);
    void insertData(unsigned offset, const String&, ExceptionCode&);
    void deleteData(unsigned offset, unsigned count, ExceptionCode&);
    void replaceData(unsigned offset, unsigned count, const String&, ExceptionCode&);

    bool containsOnlyWhitespace() const;

    StringImpl* dataImpl() { return m_data.impl(); }

    // Like appendData, but optimized for the parser (e.g., no mutation events).
    // Returns how much could be added before length limit was met.
    unsigned parserAppendData(const UChar*, unsigned dataLength, unsigned lengthLimit);

protected:
    CharacterData(Document* document, const String& text, ConstructionType type)
        : Node(document, type)
        , m_data(!text.isNull() ? text : emptyString())
    {
        ASSERT(type == CreateComment || type == CreateText);
    }

    virtual bool rendererIsNeeded(const NodeRenderingContext&);

    void setDataWithoutUpdate(const String& data)
    {
        ASSERT(!data.isNull());
        m_data = data;
    }
    void dispatchModifiedEvent(const String& oldValue);

private:
    virtual String nodeValue() const;
    virtual void setNodeValue(const String&, ExceptionCode&);
    virtual bool isCharacterDataNode() const { return true; }
    virtual int maxCharacterOffset() const;
    virtual bool offsetInCharacters() const;
    void setDataAndUpdate(const String&, unsigned offsetOfReplacedData, unsigned oldLength, unsigned newLength);
    void updateRenderer(unsigned offsetOfReplacedData, unsigned lengthOfReplacedData);
    void checkCharDataOperation(unsigned offset, ExceptionCode&);

    String m_data;
};

} // namespace WebCore

#endif // CharacterData_h
