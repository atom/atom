/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * (C) 2002-2003 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2002, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef CSSImportRule_h
#define CSSImportRule_h

#include "CSSRule.h"
#include "CachedResourceHandle.h"
#include "CachedStyleSheetClient.h"
#include "MediaList.h"
#include "PlatformString.h"

namespace WebCore {

class CachedCSSStyleSheet;
class MediaList;

class CSSImportRule : public CSSRule {
public:
    static PassRefPtr<CSSImportRule> create(CSSStyleSheet* parent, const String& href, PassRefPtr<MediaList> media)
    {
        return adoptRef(new CSSImportRule(parent, href, media));
    }

    ~CSSImportRule();

    String href() const { return m_strHref; }
    MediaList* media() const { return m_lstMedia.get(); }
    CSSStyleSheet* styleSheet() const { return m_styleSheet.get(); }

    String cssText() const;

    // Not part of the CSSOM
    bool isLoading() const;

    void addSubresourceStyleURLs(ListHashSet<KURL>& urls);

    void requestStyleSheet();

private:
    // NOTE: We put the CachedStyleSheetClient in a member instead of inheriting from it
    // to avoid adding a vptr to CSSImportRule.
    class ImportedStyleSheetClient : public CachedStyleSheetClient {
    public:
        ImportedStyleSheetClient(CSSImportRule* ownerRule) : m_ownerRule(ownerRule) { }
        virtual ~ImportedStyleSheetClient() { }
        virtual void setCSSStyleSheet(const String& href, const KURL& baseURL, const String& charset, const CachedCSSStyleSheet* sheet)
        {
            m_ownerRule->setCSSStyleSheet(href, baseURL, charset, sheet);
        }
    private:
        CSSImportRule* m_ownerRule;
    };

    void setCSSStyleSheet(const String& href, const KURL& baseURL, const String& charset, const CachedCSSStyleSheet*);
    friend class ImportedStyleSheetClient;

    CSSImportRule(CSSStyleSheet* parent, const String& href, PassRefPtr<MediaList>);

    ImportedStyleSheetClient m_styleSheetClient;
    String m_strHref;
    RefPtr<MediaList> m_lstMedia;
    RefPtr<CSSStyleSheet> m_styleSheet;
    CachedResourceHandle<CachedCSSStyleSheet> m_cachedSheet;
    bool m_loading;
};

} // namespace WebCore

#endif // CSSImportRule_h
