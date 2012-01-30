/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 * Copyright (C) 2004, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef HTMLDocument_h
#define HTMLDocument_h

#include "CachedResourceClient.h"
#include "Document.h"
#include <wtf/HashCountedSet.h>
#include <wtf/text/AtomicStringHash.h>

namespace WebCore {

class FrameView;
class HTMLElement;

class HTMLDocument : public Document, public CachedResourceClient {
public:
    static PassRefPtr<HTMLDocument> create(Frame* frame, const KURL& url)
    {
        return adoptRef(new HTMLDocument(frame, url));
    }
    virtual ~HTMLDocument();

    int width();
    int height();

    String dir();
    void setDir(const String&);

    String designMode() const;
    void setDesignMode(const String&);

    virtual void setCompatibilityModeFromDoctype();

    Element* activeElement();
    bool hasFocus();

    String bgColor();
    void setBgColor(const String&);
    String fgColor();
    void setFgColor(const String&);
    String alinkColor();
    void setAlinkColor(const String&);
    String linkColor();
    void setLinkColor(const String&);
    String vlinkColor();
    void setVlinkColor(const String&);

    void clear();

    void captureEvents();
    void releaseEvents();

    void addNamedItem(const AtomicString& name);
    void removeNamedItem(const AtomicString& name);
    bool hasNamedItem(AtomicStringImpl* name);

    void addExtraNamedItem(const AtomicString& name);
    void removeExtraNamedItem(const AtomicString& name);
    bool hasExtraNamedItem(AtomicStringImpl* name);

protected:
    HTMLDocument(Frame*, const KURL&);

private:
    virtual PassRefPtr<Element> createElement(const AtomicString& tagName, ExceptionCode&);

    virtual bool isFrameSet() const;
    virtual PassRefPtr<DocumentParser> createParser();

    void addItemToMap(HashCountedSet<AtomicStringImpl*>&, const AtomicString&);
    void removeItemFromMap(HashCountedSet<AtomicStringImpl*>&, const AtomicString&);

    HashCountedSet<AtomicStringImpl*> m_namedItemCounts;
    HashCountedSet<AtomicStringImpl*> m_extraNamedItemCounts;
};

inline bool HTMLDocument::hasNamedItem(AtomicStringImpl* name)
{
    ASSERT(name);
    return m_namedItemCounts.contains(name);
}

inline bool HTMLDocument::hasExtraNamedItem(AtomicStringImpl* name)
{
    ASSERT(name);
    return m_extraNamedItemCounts.contains(name);
}

} // namespace WebCore

#endif // HTMLDocument_h
