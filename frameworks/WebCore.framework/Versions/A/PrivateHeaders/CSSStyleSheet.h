/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2004, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef CSSStyleSheet_h
#define CSSStyleSheet_h

#include "CSSRuleList.h"
#include "StyleSheet.h"

namespace WebCore {

struct CSSNamespace;
class CSSParser;
class CSSRule;
class CachedResourceLoader;
class Document;

typedef int ExceptionCode;

class CSSStyleSheet : public StyleSheet {
public:
    static PassRefPtr<CSSStyleSheet> create()
    {
        return adoptRef(new CSSStyleSheet(static_cast<CSSImportRule*>(0), String(), KURL(), String()));
    }
    static PassRefPtr<CSSStyleSheet> create(Node* ownerNode)
    {
        return adoptRef(new CSSStyleSheet(ownerNode, String(), KURL(), String()));
    }
    static PassRefPtr<CSSStyleSheet> create(Node* ownerNode, const String& originalURL, const KURL& finalURL, const String& charset)
    {
        return adoptRef(new CSSStyleSheet(ownerNode, originalURL, finalURL, charset));
    }
    static PassRefPtr<CSSStyleSheet> create(CSSImportRule* ownerRule, const String& originalURL, const KURL& finalURL, const String& charset)
    {
        return adoptRef(new CSSStyleSheet(ownerRule, originalURL, finalURL, charset));
    }
    static PassRefPtr<CSSStyleSheet> createInline(Node* ownerNode, const KURL& finalURL)
    {
        return adoptRef(new CSSStyleSheet(ownerNode, finalURL.string(), finalURL, String()));
    }

    virtual ~CSSStyleSheet();

    CSSStyleSheet* parentStyleSheet() const
    {
        StyleSheet* parentSheet = StyleSheet::parentStyleSheet();
        ASSERT(!parentSheet || parentSheet->isCSSStyleSheet());
        return static_cast<CSSStyleSheet*>(parentSheet);
    }

    PassRefPtr<CSSRuleList> cssRules(bool omitCharsetRules = false);
    unsigned insertRule(const String& rule, unsigned index, ExceptionCode&);
    void deleteRule(unsigned index, ExceptionCode&);

    // IE Extensions
    PassRefPtr<CSSRuleList> rules() { return cssRules(true); }
    int addRule(const String& selector, const String& style, int index, ExceptionCode&);
    int addRule(const String& selector, const String& style, ExceptionCode&);
    void removeRule(unsigned index, ExceptionCode& ec) { deleteRule(index, ec); }

    void addNamespace(CSSParser*, const AtomicString& prefix, const AtomicString& uri);
    const AtomicString& determineNamespace(const AtomicString& prefix);

    void styleSheetChanged();

    virtual bool parseString(const String&, bool strict = true);

    bool parseStringAtLine(const String&, bool strict, int startLineNumber);

    virtual bool isLoading();

    void checkLoaded();
    void startLoadingDynamicSheet();

    Node* findStyleSheetOwnerNode() const;
    Document* findDocument();

    const String& charset() const { return m_charset; }

    bool loadCompleted() const { return m_loadCompleted; }

    KURL completeURL(const String& url) const;
    void addSubresourceStyleURLs(ListHashSet<KURL>&);

    void setStrictParsing(bool b) { m_strictParsing = b; }
    bool useStrictParsing() const { return m_strictParsing; }

    void setIsUserStyleSheet(bool b) { m_isUserStyleSheet = b; }
    bool isUserStyleSheet() const { return m_isUserStyleSheet; }
    void setHasSyntacticallyValidCSSHeader(bool b) { m_hasSyntacticallyValidCSSHeader = b; }
    bool hasSyntacticallyValidCSSHeader() const { return m_hasSyntacticallyValidCSSHeader; }

    void append(PassRefPtr<CSSRule>);
    void remove(unsigned index);

    unsigned length() const { return m_children.size(); }
    CSSRule* item(unsigned index) { return index < length() ? m_children.at(index).get() : 0; }

private:
    CSSStyleSheet(Node* ownerNode, const String& originalURL, const KURL& finalURL, const String& charset);
    CSSStyleSheet(CSSImportRule* ownerRule, const String& originalURL, const KURL& finalURL, const String& charset);

    virtual bool isCSSStyleSheet() const { return true; }
    virtual String type() const { return "text/css"; }

    Vector<RefPtr<CSSRule> > m_children;
    OwnPtr<CSSNamespace> m_namespaces;
    String m_charset;
    bool m_loadCompleted : 1;
    bool m_strictParsing : 1;
    bool m_isUserStyleSheet : 1;
    bool m_hasSyntacticallyValidCSSHeader : 1;
};

} // namespace

#endif
