/*
 * Copyright (C) 2008, 2011 Apple Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef PopupMenuStyle_h
#define PopupMenuStyle_h

#include "Color.h"
#include "Font.h"
#include "Length.h"
#include "TextDirection.h"

namespace WebCore {

class PopupMenuStyle {
public:
    enum PopupMenuType { SelectPopup, AutofillPopup };
    PopupMenuStyle(const Color& foreground, const Color& background, const Font& font, bool visible, bool isDisplayNone, Length textIndent, TextDirection textDirection, bool hasTextDirectionOverride, PopupMenuType menuType = SelectPopup)
        : m_foregroundColor(foreground)
        , m_backgroundColor(background)
        , m_font(font)
        , m_visible(visible)
        , m_isDisplayNone(isDisplayNone)
        , m_textIndent(textIndent)
        , m_textDirection(textDirection)
        , m_hasTextDirectionOverride(hasTextDirectionOverride)
        , m_menuType(menuType)
    {
    }

    const Color& foregroundColor() const { return m_foregroundColor; }
    const Color& backgroundColor() const { return m_backgroundColor; }
    const Font& font() const { return m_font; }
    bool isVisible() const { return m_visible; }
    bool isDisplayNone() const { return m_isDisplayNone; }
    Length textIndent() const { return m_textIndent; }
    TextDirection textDirection() const { return m_textDirection; }
    bool hasTextDirectionOverride() const { return m_hasTextDirectionOverride; }
    PopupMenuType menuType() const { return m_menuType; }
private:
    Color m_foregroundColor;
    Color m_backgroundColor;
    Font m_font;
    bool m_visible;
    bool m_isDisplayNone;
    Length m_textIndent;
    TextDirection m_textDirection;
    bool m_hasTextDirectionOverride;
    PopupMenuType m_menuType;
};

} // namespace WebCore

#endif // PopupMenuStyle_h
