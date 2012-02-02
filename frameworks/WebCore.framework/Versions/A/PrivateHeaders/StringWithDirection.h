/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef StringWithDirection_h
#define StringWithDirection_h

#include "PlatformString.h"
#include "TextDirection.h"

namespace WebCore {

// In some circumstances we want to store a String along with the TextDirection
// of the String as learned from the context of the String. For example,
// consider storing the title derived from <title dir='rtl'>some title</title>
// in the history.
//
// Note that is explicitly *not* the direction of the string as learned
// from the characters of the string; it's extra metadata we have external
// to the string.
class StringWithDirection {
public:
    StringWithDirection()
        : m_direction(LTR)
    {
    }

    StringWithDirection(const String& string, TextDirection dir)
        : m_string(string)
        , m_direction(dir)
    {
    }

    const String& string() const { return m_string; }
    TextDirection direction() const { return m_direction; }

    bool isEmpty() const { return m_string.isEmpty(); }
    bool isNull() const { return m_string.isNull(); }

    bool operator==(const StringWithDirection& other) const
    {
        return other.m_string == m_string && other.m_direction == m_direction;
    }
    bool operator!=(const StringWithDirection& other) const { return !((*this) == other); }

private:
    String m_string;
    TextDirection m_direction;
};

}

#endif // StringWithDirection_h
