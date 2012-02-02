/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
 *           (C) 2000 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2005, 2006, 2007, 2008, 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Graham Dennis (graham.dennis@gmail.com)
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

#ifndef ContentData_h
#define ContentData_h

#include "CounterContent.h"
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>

namespace WebCore {

class StyleImage;

class ContentData {
    WTF_MAKE_FAST_ALLOCATED;
public:
    static PassOwnPtr<ContentData> create(PassRefPtr<StyleImage>);
    static PassOwnPtr<ContentData> create(const String&);
    static PassOwnPtr<ContentData> create(PassOwnPtr<CounterContent>);
    static PassOwnPtr<ContentData> create(QuoteType);
    
    virtual ~ContentData() { }

    virtual bool isCounter() const { return false; }
    virtual bool isImage() const { return false; }
    virtual bool isQuote() const { return false; }
    virtual bool isText() const { return false; }

    virtual StyleContentType type() const = 0;

    friend bool operator==(const ContentData&, const ContentData&);
    friend bool operator!=(const ContentData&, const ContentData&);

    virtual PassOwnPtr<ContentData> clone() const;

    ContentData* next() const { return m_next.get(); }
    void setNext(PassOwnPtr<ContentData> next) { m_next = next; }

private:
    virtual PassOwnPtr<ContentData> cloneInternal() const = 0;

    OwnPtr<ContentData> m_next;
};

class ImageContentData : public ContentData {
    friend class ContentData;
public:
    const StyleImage* image() const { return m_image.get(); }
    StyleImage* image() { return m_image.get(); }
    void setImage(PassRefPtr<StyleImage> image) { m_image = image; }

private:
    ImageContentData(PassRefPtr<StyleImage> image)
        : m_image(image)
    {
    }

    virtual StyleContentType type() const { return CONTENT_OBJECT; }
    virtual bool isImage() const { return true; }
    virtual PassOwnPtr<ContentData> cloneInternal() const
    {
        RefPtr<StyleImage> image = const_cast<StyleImage*>(this->image());
        return create(image.release());
    }

    RefPtr<StyleImage> m_image;
};

class TextContentData : public ContentData {
    friend class ContentData;
public:
    const String& text() const { return m_text; }
    void setText(const String& text) { m_text = text; }

private:
    TextContentData(const String& text)
        : m_text(text)
    {
    }

    virtual StyleContentType type() const { return CONTENT_TEXT; }
    virtual bool isText() const { return true; }
    virtual PassOwnPtr<ContentData> cloneInternal() const { return create(text()); }

    String m_text;
};

class CounterContentData : public ContentData {
    friend class ContentData;
public:
    const CounterContent* counter() const { return m_counter.get(); }
    void setCounter(PassOwnPtr<CounterContent> counter) { m_counter = counter; }

private:
    CounterContentData(PassOwnPtr<CounterContent> counter)
        : m_counter(counter)
    {
    }

    virtual StyleContentType type() const { return CONTENT_COUNTER; }
    virtual bool isCounter() const { return true; }
    virtual PassOwnPtr<ContentData> cloneInternal() const
    {
        OwnPtr<CounterContent> counterData = adoptPtr(new CounterContent(*counter()));
        return create(counterData.release());
    }

    OwnPtr<CounterContent> m_counter;
};

class QuoteContentData : public ContentData {
    friend class ContentData;
public:
    QuoteType quote() const { return m_quote; }
    void setQuote(QuoteType quote) { m_quote = quote; }

private:
    QuoteContentData(QuoteType quote)
        : m_quote(quote)
    {
    }

    virtual StyleContentType type() const { return CONTENT_QUOTE; }
    virtual bool isQuote() const { return true; }
    virtual PassOwnPtr<ContentData> cloneInternal() const { return create(quote()); }

    QuoteType m_quote;
};

} // namespace WebCore

#endif // ContentData_h
