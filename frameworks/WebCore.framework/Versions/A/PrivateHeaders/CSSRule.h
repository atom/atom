/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * (C) 2002-2003 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2002, 2006, 2007 Apple Inc. All rights reserved.
 * Copyright (C) 2011 Andreas Kling (kling@webkit.org)
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

#ifndef CSSRule_h
#define CSSRule_h

#include "CSSStyleSheet.h"
#include "KURLHash.h"
#include <wtf/ListHashSet.h>

namespace WebCore {

typedef int ExceptionCode;

class CSSRule : public RefCounted<CSSRule> {
public:
    // Override RefCounted's deref() to ensure operator delete is called on
    // the appropriate subclass type.
    void deref()
    {
        if (derefBase())
            destroy();
    }

    enum Type {
        UNKNOWN_RULE,
        STYLE_RULE,
        CHARSET_RULE,
        IMPORT_RULE,
        MEDIA_RULE,
        FONT_FACE_RULE,
        PAGE_RULE,
        // 7 used to be VARIABLES_RULE
        WEBKIT_KEYFRAMES_RULE = 8,
        WEBKIT_KEYFRAME_RULE,
        WEBKIT_REGION_RULE
    };

    Type type() const { return static_cast<Type>(m_type); }

    bool isCharsetRule() const { return type() == CHARSET_RULE; }
    bool isFontFaceRule() const { return type() == FONT_FACE_RULE; }
    bool isKeyframeRule() const { return type() == WEBKIT_KEYFRAME_RULE; }
    bool isKeyframesRule() const { return type() == WEBKIT_KEYFRAMES_RULE; }
    bool isMediaRule() const { return type() == MEDIA_RULE; }
    bool isPageRule() const { return type() == PAGE_RULE; }
    bool isStyleRule() const { return type() == STYLE_RULE; }
    bool isRegionRule() const { return type() == WEBKIT_REGION_RULE; }
    bool isImportRule() const { return type() == IMPORT_RULE; }

    bool useStrictParsing() const
    {
        if (parentRule())
            return parentRule()->useStrictParsing();
        if (parentStyleSheet())
            return parentStyleSheet()->useStrictParsing();
        return true;
    }

    void setParentStyleSheet(CSSStyleSheet* styleSheet)
    {
        m_parentIsRule = false;
        m_parentStyleSheet = styleSheet;
    }

    void setParentRule(CSSRule* rule)
    {
        m_parentIsRule = true;
        m_parentRule = rule;
    }

    CSSStyleSheet* parentStyleSheet() const
    {
        if (m_parentIsRule)
            return m_parentRule ? m_parentRule->parentStyleSheet() : 0;
        return m_parentStyleSheet;
    }

    CSSRule* parentRule() const { return m_parentIsRule ? m_parentRule : 0; }

    String cssText() const;
    void setCssText(const String&, ExceptionCode&);

    KURL baseURL() const
    {
        if (CSSStyleSheet* parentSheet = parentStyleSheet())
            return parentSheet->baseURL();
        return KURL();
    }

protected:
    CSSRule(CSSStyleSheet* parent, Type type)
        : m_sourceLine(0)
        , m_hasCachedSelectorText(false)
        , m_parentIsRule(false)
        , m_type(type)
        , m_parentStyleSheet(parent)
    {
    }

    // NOTE: This class is non-virtual for memory and performance reasons.
    // Don't go making it virtual again unless you know exactly what you're doing!

    ~CSSRule() { }

    int sourceLine() const { return m_sourceLine; }
    void setSourceLine(int sourceLine) { m_sourceLine = sourceLine; }
    bool hasCachedSelectorText() const { return m_hasCachedSelectorText; }
    void setHasCachedSelectorText(bool hasCachedSelectorText) const { m_hasCachedSelectorText = hasCachedSelectorText; }

private:
    // Only used by CSSStyleRule but kept here to maximize struct packing.
    signed m_sourceLine : 26;
    mutable unsigned m_hasCachedSelectorText : 1;
    unsigned m_parentIsRule : 1;
    unsigned m_type : 4;
    union {
        CSSRule* m_parentRule;
        CSSStyleSheet* m_parentStyleSheet;
    };

    void destroy();
};

} // namespace WebCore

#endif // CSSRule_h
