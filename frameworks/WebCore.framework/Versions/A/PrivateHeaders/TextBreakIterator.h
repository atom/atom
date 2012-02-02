/*
 * Copyright (C) 2006 Lars Knoll <lars@trolltech.com>
 * Copyright (C) 2007 Apple Inc. All rights reserved.
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

#ifndef TextBreakIterator_h
#define TextBreakIterator_h

#include <wtf/text/AtomicString.h>
#include <wtf/unicode/Unicode.h>

namespace WebCore {

    class TextBreakIterator;

    // Note: The returned iterator is good only until you get another iterator, with the exception of acquireLineBreakIterator.

    // Iterates over "extended grapheme clusters", as defined in UAX #29.
    // Note that platform implementations may be less sophisticated - e.g. ICU prior to
    // version 4.0 only supports "legacy grapheme clusters".
    // Use this for general text processing, e.g. string truncation.
    TextBreakIterator* characterBreakIterator(const UChar*, int length);

    // This is similar to character break iterator in most cases, but is subject to
    // platform UI conventions. One notable example where this can be different
    // from character break iterator is Thai prepend characters, see bug 24342.
    // Use this for insertion point and selection manipulations.
    TextBreakIterator* cursorMovementIterator(const UChar*, int length);

    TextBreakIterator* wordBreakIterator(const UChar*, int length);
    TextBreakIterator* acquireLineBreakIterator(const UChar*, int length, const AtomicString& locale);
    void releaseLineBreakIterator(TextBreakIterator*);
    TextBreakIterator* sentenceBreakIterator(const UChar*, int length);

    int textBreakFirst(TextBreakIterator*);
    int textBreakLast(TextBreakIterator*);
    int textBreakNext(TextBreakIterator*);
    int textBreakPrevious(TextBreakIterator*);
    int textBreakCurrent(TextBreakIterator*);
    int textBreakPreceding(TextBreakIterator*, int);
    int textBreakFollowing(TextBreakIterator*, int);
    bool isTextBreak(TextBreakIterator*, int);

    const int TextBreakDone = -1;

class LazyLineBreakIterator {
public:
    LazyLineBreakIterator(const UChar* string = 0, int length = 0, const AtomicString& locale = AtomicString())
        : m_string(string)
        , m_length(length)
        , m_locale(locale)
        , m_iterator(0)
    {
    }

    ~LazyLineBreakIterator()
    {
        if (m_iterator)
            releaseLineBreakIterator(m_iterator);
    }

    const UChar* string() const { return m_string; }
    int length() const { return m_length; }

    TextBreakIterator* get()
    {
        if (!m_iterator)
            m_iterator = acquireLineBreakIterator(m_string, m_length, m_locale);
        return m_iterator;
    }

    void reset(const UChar* string, int length, const AtomicString& locale)
    {
        if (m_iterator)
            releaseLineBreakIterator(m_iterator);

        m_string = string;
        m_length = length;
        m_locale = locale;
        m_iterator = 0;
    }

private:
    const UChar* m_string;
    int m_length;
    AtomicString m_locale;
    TextBreakIterator* m_iterator;
};

}

#endif
