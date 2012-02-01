/*
    Copyright (C) 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this library; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

#ifndef SegmentedString_h
#define SegmentedString_h

#include "PlatformString.h"
#include <wtf/Deque.h>
#include <wtf/text/TextPosition.h>

namespace WebCore {

class SegmentedString;

class SegmentedSubstring {
public:
    SegmentedSubstring()
        : m_length(0)
        , m_current(0)
        , m_doNotExcludeLineNumbers(true)
    {
    }

    SegmentedSubstring(const String& str)
        : m_length(str.length())
        , m_current(str.isEmpty() ? 0 : str.characters())
        , m_string(str)
        , m_doNotExcludeLineNumbers(true)
    {
    }

    void clear() { m_length = 0; m_current = 0; }
    
    bool excludeLineNumbers() const { return !m_doNotExcludeLineNumbers; }
    bool doNotExcludeLineNumbers() const { return m_doNotExcludeLineNumbers; }

    void setExcludeLineNumbers() { m_doNotExcludeLineNumbers = false; }

    int numberOfCharactersConsumed() const { return m_string.length() - m_length; }

    void appendTo(String& str) const
    {
        if (m_string.characters() == m_current) {
            if (str.isEmpty())
                str = m_string;
            else
                str.append(m_string);
        } else
            str.append(String(m_current, m_length));
    }

public:
    int m_length;
    const UChar* m_current;

private:
    String m_string;
    bool m_doNotExcludeLineNumbers;
};

class SegmentedString {
public:
    SegmentedString()
        : m_pushedChar1(0)
        , m_pushedChar2(0)
        , m_currentChar(0)
        , m_numberOfCharactersConsumedPriorToCurrentString(0)
        , m_numberOfCharactersConsumedPriorToCurrentLine(0)
        , m_currentLine(0)
        , m_closed(false)
    {
    }

    SegmentedString(const String& str)
        : m_pushedChar1(0)
        , m_pushedChar2(0)
        , m_currentString(str)
        , m_currentChar(m_currentString.m_current)
        , m_numberOfCharactersConsumedPriorToCurrentString(0)
        , m_numberOfCharactersConsumedPriorToCurrentLine(0)
        , m_currentLine(0)
        , m_closed(false)
    {
    }

    SegmentedString(const SegmentedString&);

    const SegmentedString& operator=(const SegmentedString&);

    void clear();
    void close();

    void append(const SegmentedString&);
    void prepend(const SegmentedString&);

    bool excludeLineNumbers() const { return m_currentString.excludeLineNumbers(); }
    void setExcludeLineNumbers();

    void push(UChar c)
    {
        if (!m_pushedChar1) {
            m_pushedChar1 = c;
            m_currentChar = m_pushedChar1 ? &m_pushedChar1 : m_currentString.m_current;
        } else {
            ASSERT(!m_pushedChar2);
            m_pushedChar2 = c;
        }
    }

    bool isEmpty() const { return !current(); }
    unsigned length() const;

    bool isClosed() const { return m_closed; }

    enum LookAheadResult {
        DidNotMatch,
        DidMatch,
        NotEnoughCharacters,
    };

    LookAheadResult lookAhead(const String& string) { return lookAheadInline<SegmentedString::equalsLiterally>(string); }
    LookAheadResult lookAheadIgnoringCase(const String& string) { return lookAheadInline<SegmentedString::equalsIgnoringCase>(string); }

    void advance()
    {
        if (!m_pushedChar1 && m_currentString.m_length > 1) {
            --m_currentString.m_length;
            m_currentChar = ++m_currentString.m_current;
            return;
        }
        advanceSlowCase();
    }

    void advanceAndASSERT(UChar expectedCharacter)
    {
        ASSERT_UNUSED(expectedCharacter, *current() == expectedCharacter);
        advance();
    }

    void advanceAndASSERTIgnoringCase(UChar expectedCharacter)
    {
        ASSERT_UNUSED(expectedCharacter, WTF::Unicode::foldCase(*current()) == WTF::Unicode::foldCase(expectedCharacter));
        advance();
    }

    void advancePastNewline(int& lineNumber)
    {
        ASSERT(*current() == '\n');
        if (!m_pushedChar1 && m_currentString.m_length > 1) {
            int newLineFlag = m_currentString.doNotExcludeLineNumbers();
            lineNumber += newLineFlag;
            m_currentLine += newLineFlag;
            if (newLineFlag)
                m_numberOfCharactersConsumedPriorToCurrentLine = numberOfCharactersConsumed() + 1;
            --m_currentString.m_length;
            m_currentChar = ++m_currentString.m_current;
            return;
        }
        advanceSlowCase(lineNumber);
    }
    
    void advancePastNonNewline()
    {
        ASSERT(*current() != '\n');
        if (!m_pushedChar1 && m_currentString.m_length > 1) {
            --m_currentString.m_length;
            m_currentChar = ++m_currentString.m_current;
            return;
        }
        advanceSlowCase();
    }
    
    void advance(int& lineNumber)
    {
        if (!m_pushedChar1 && m_currentString.m_length > 1) {
            int newLineFlag = (*m_currentString.m_current == '\n') & m_currentString.doNotExcludeLineNumbers();
            lineNumber += newLineFlag;
            m_currentLine += newLineFlag;
            if (newLineFlag)
                m_numberOfCharactersConsumedPriorToCurrentLine = numberOfCharactersConsumed() + 1;
            --m_currentString.m_length;
            m_currentChar = ++m_currentString.m_current;
            return;
        }
        advanceSlowCase(lineNumber);
    }

    // Writes the consumed characters into consumedCharacters, which must
    // have space for at least |count| characters.
    void advance(unsigned count, UChar* consumedCharacters);

    bool escaped() const { return m_pushedChar1; }

    int numberOfCharactersConsumed() const
    {
        int numberOfPushedCharacters = 0;
        if (m_pushedChar1) {
            ++numberOfPushedCharacters;
            if (m_pushedChar2)
                ++numberOfPushedCharacters;
        }
        return m_numberOfCharactersConsumedPriorToCurrentString + m_currentString.numberOfCharactersConsumed() - numberOfPushedCharacters;
    }

    String toString() const;

    const UChar& operator*() const { return *current(); }
    const UChar* operator->() const { return current(); }
    

    // The method is moderately slow, comparing to currentLine method.
    OrdinalNumber currentColumn() const;
    OrdinalNumber currentLine() const;
    // Sets value of line/column variables. Column is specified indirectly by a parameter columnAftreProlog
    // which is a value of column that we should get after a prolog (first prologLength characters) has been consumed.
    void setCurrentPosition(OrdinalNumber line, OrdinalNumber columnAftreProlog, int prologLength);

private:
    void append(const SegmentedSubstring&);
    void prepend(const SegmentedSubstring&);

    void advanceSlowCase();
    void advanceSlowCase(int& lineNumber);
    void advanceSubstring();
    const UChar* current() const { return m_currentChar; }

    static bool equalsLiterally(const UChar* str1, const UChar* str2, size_t count) { return !memcmp(str1, str2, count * sizeof(UChar)); }
    static bool equalsIgnoringCase(const UChar* str1, const UChar* str2, size_t count) { return !WTF::Unicode::umemcasecmp(str1, str2, count); }

    template<bool equals(const UChar* str1, const UChar* str2, size_t count)>
    inline LookAheadResult lookAheadInline(const String& string)
    {
        if (!m_pushedChar1 && string.length() <= static_cast<unsigned>(m_currentString.m_length)) {
            if (equals(string.characters(), m_currentString.m_current, string.length()))
                return DidMatch;
            return DidNotMatch;
        }
        return lookAheadSlowCase<equals>(string);
    }

    template<bool equals(const UChar* str1, const UChar* str2, size_t count)>
    LookAheadResult lookAheadSlowCase(const String& string)
    {
        unsigned count = string.length();
        if (count > length())
            return NotEnoughCharacters;
        UChar* consumedCharacters;
        String consumedString = String::createUninitialized(count, consumedCharacters);
        advance(count, consumedCharacters);
        LookAheadResult result = DidNotMatch;
        if (equals(string.characters(), consumedCharacters, count))
            result = DidMatch;
        prepend(SegmentedString(consumedString));
        return result;
    }

    bool isComposite() const { return !m_substrings.isEmpty(); }

    UChar m_pushedChar1;
    UChar m_pushedChar2;
    SegmentedSubstring m_currentString;
    const UChar* m_currentChar;
    int m_numberOfCharactersConsumedPriorToCurrentString;
    int m_numberOfCharactersConsumedPriorToCurrentLine;
    int m_currentLine;
    Deque<SegmentedSubstring> m_substrings;
    bool m_closed;
};

}

#endif
