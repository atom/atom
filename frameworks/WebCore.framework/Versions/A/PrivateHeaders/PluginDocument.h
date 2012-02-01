/*
 * Copyright (C) 2006, 2008, 2009 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef PluginDocument_h
#define PluginDocument_h

#include "HTMLDocument.h"

namespace WebCore {

class Node;
class Widget;

class PluginDocument : public HTMLDocument {
public:
    static PassRefPtr<PluginDocument> create(Frame* frame, const KURL& url)
    {
        return adoptRef(new PluginDocument(frame, url));
    }

    void setPluginNode(Node* pluginNode) { m_pluginNode = pluginNode; }

    Widget* pluginWidget();
    Node* pluginNode();

    virtual void detach() OVERRIDE;

    void cancelManualPluginLoad();

    bool shouldLoadPluginManually() { return m_shouldLoadPluginManually; }

private:
    PluginDocument(Frame*, const KURL&);

    virtual PassRefPtr<DocumentParser> createParser() OVERRIDE;
    virtual bool isPluginDocument() const OVERRIDE { return true; }    
        
    void setShouldLoadPluginManually(bool loadManually) { m_shouldLoadPluginManually = loadManually; }

    bool m_shouldLoadPluginManually;
    RefPtr<Node> m_pluginNode;
};

inline PluginDocument* toPluginDocument(Document* document)
{
    ASSERT(!document || document->isPluginDocument());
    return static_cast<PluginDocument*>(document);
}

inline const PluginDocument* toPluginDocument(const Document* document)
{
    ASSERT(!document || document->isPluginDocument());
    return static_cast<const PluginDocument*>(document);
}

// This will catch anyone doing an unnecessary cast.
void toPluginDocument(const PluginDocument*);
    
}

#endif // PluginDocument_h
