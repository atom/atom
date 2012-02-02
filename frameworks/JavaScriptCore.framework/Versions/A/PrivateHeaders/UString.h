/*
 * Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2009 Google Inc. All rights reserved.
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

#ifndef UString_h
#define UString_h

#include <wtf/text/StringImpl.h>

namespace JSC {

class UString {
public:
    // Construct a null string, distinguishable from an empty string.
    UString() { }

    // Construct a string with UTF-16 data.
    JS_EXPORT_PRIVATE UString(const UChar* characters, unsigned length);

    // Construct a string with UTF-16 data, from a null-terminated source.
    JS_EXPORT_PRIVATE UString(const UChar*);

    // Construct a string with latin1 data.
    UString(const LChar* characters, unsigned length);
    JS_EXPORT_PRIVATE UString(const char* characters, unsigned length);

    // Construct a string with latin1 data, from a null-terminated source.
    UString(const LChar* characters);
    JS_EXPORT_PRIVATE UString(const char* characters);

    // Construct a string referencing an existing StringImpl.
    UString(StringImpl* impl) : m_impl(impl) { }
    UString(PassRefPtr<StringImpl> impl) : m_impl(impl) { }
    UString(RefPtr<StringImpl> impl) : m_impl(impl) { }

    // Inline the destructor.
    ALWAYS_INLINE ~UString() { }

    void swap(UString& o) { m_impl.swap(o.m_impl); }

    template<typename CharType, size_t inlineCapacity>
    static UString adopt(Vector<CharType, inlineCapacity>& vector) { return StringImpl::adopt(vector); }

    bool isNull() const { return !m_impl; }
    bool isEmpty() const { return !m_impl || !m_impl->length(); }

    StringImpl* impl() const { return m_impl.get(); }

    unsigned length() const
    {
        if (!m_impl)
            return 0;
        return m_impl->length();
    }

    const UChar* characters() const
    {
        if (!m_impl)
            return 0;
        return m_impl->characters();
    }

    const LChar* characters8() const
    {
        if (!m_impl)
            return 0;
        ASSERT(m_impl->is8Bit());
        return m_impl->characters8();
    }

    const UChar* characters16() const
    {
        if (!m_impl)
            return 0;
        ASSERT(!m_impl->is8Bit());
        return m_impl->characters16();
    }

    template <typename CharType>
    inline const CharType* getCharacters() const;

    bool is8Bit() const { return m_impl->is8Bit(); }

    JS_EXPORT_PRIVATE CString ascii() const;
    CString latin1() const;
    JS_EXPORT_PRIVATE CString utf8(bool strict = false) const;

    UChar operator[](unsigned index) const
    {
        if (!m_impl || index >= m_impl->length())
            return 0;
        if (is8Bit())
            return m_impl->characters8()[index];
        return m_impl->characters16()[index];
    }

    JS_EXPORT_PRIVATE static UString number(int);
    JS_EXPORT_PRIVATE static UString number(unsigned);
    JS_EXPORT_PRIVATE static UString number(long);
    static UString number(long long);
    JS_EXPORT_PRIVATE static UString number(double);

    // Find a single character or string, also with match function & latin1 forms.
    size_t find(UChar c, unsigned start = 0) const
        { return m_impl ? m_impl->find(c, start) : notFound; }
    size_t find(const UString& str, unsigned start = 0) const
        { return m_impl ? m_impl->find(str.impl(), start) : notFound; }
    size_t find(const LChar* str, unsigned start = 0) const
        { return m_impl ? m_impl->find(str, start) : notFound; }

    // Find the last instance of a single character or string.
    size_t reverseFind(UChar c, unsigned start = UINT_MAX) const
        { return m_impl ? m_impl->reverseFind(c, start) : notFound; }
    size_t reverseFind(const UString& str, unsigned start = UINT_MAX) const
        { return m_impl ? m_impl->reverseFind(str.impl(), start) : notFound; }

    JS_EXPORT_PRIVATE UString substringSharingImpl(unsigned pos, unsigned len = UINT_MAX) const;

private:
    RefPtr<StringImpl> m_impl;
};

template<>
inline const LChar* UString::getCharacters<LChar>() const
{
    ASSERT(is8Bit());
    return characters8();
}

template<>
inline const UChar* UString::getCharacters<UChar>() const
{
    ASSERT(!is8Bit());
    return characters16();
}

NEVER_INLINE bool equalSlowCase(const UString& s1, const UString& s2);

ALWAYS_INLINE bool operator==(const UString& s1, const UString& s2)
{
    StringImpl* rep1 = s1.impl();
    StringImpl* rep2 = s2.impl();

    if (rep1 == rep2) // If they're the same rep, they're equal.
        return true;

    unsigned size1 = 0;
    unsigned size2 = 0;

    if (rep1)
        size1 = rep1->length();

    if (rep2)
        size2 = rep2->length();

    if (size1 != size2) // If the lengths are not the same, we're done.
        return false;

    if (!size1)
        return true;

    if (size1 == 1)
        return (*rep1)[0u] == (*rep2)[0u];

    return equalSlowCase(s1, s2);
}


inline bool operator!=(const UString& s1, const UString& s2)
{
    return !JSC::operator==(s1, s2);
}

JS_EXPORT_PRIVATE bool operator<(const UString& s1, const UString& s2);
JS_EXPORT_PRIVATE bool operator>(const UString& s1, const UString& s2);

JS_EXPORT_PRIVATE bool operator==(const UString& s1, const char* s2);

inline bool operator!=(const UString& s1, const char* s2)
{
    return !JSC::operator==(s1, s2);
}

inline bool operator==(const char *s1, const UString& s2)
{
    return operator==(s2, s1);
}

inline bool operator!=(const char *s1, const UString& s2)
{
    return !JSC::operator==(s1, s2);
}

inline int codePointCompare(const UString& s1, const UString& s2)
{
    return codePointCompare(s1.impl(), s2.impl());
}

struct UStringHash {
    static unsigned hash(StringImpl* key) { return key->hash(); }
    static bool equal(const StringImpl* a, const StringImpl* b)
    {
        if (a == b)
            return true;
        if (!a || !b)
            return false;

        unsigned aLength = a->length();
        unsigned bLength = b->length();
        if (aLength != bLength)
            return false;

        // FIXME: perhaps we should have a more abstract macro that indicates when
        // going 4 bytes at a time is unsafe
#if CPU(ARM) || CPU(SH4) || CPU(MIPS) || CPU(SPARC)
        const UChar* aChars = a->characters();
        const UChar* bChars = b->characters();
        for (unsigned i = 0; i != aLength; ++i) {
            if (*aChars++ != *bChars++)
                return false;
        }
        return true;
#else
        /* Do it 4-bytes-at-a-time on architectures where it's safe */
        const uint32_t* aChars = reinterpret_cast<const uint32_t*>(a->characters());
        const uint32_t* bChars = reinterpret_cast<const uint32_t*>(b->characters());

        unsigned halfLength = aLength >> 1;
        for (unsigned i = 0; i != halfLength; ++i)
            if (*aChars++ != *bChars++)
                return false;

        if (aLength & 1 && *reinterpret_cast<const uint16_t*>(aChars) != *reinterpret_cast<const uint16_t*>(bChars))
            return false;

        return true;
#endif
    }

    static unsigned hash(const RefPtr<StringImpl>& key) { return key->hash(); }
    static bool equal(const RefPtr<StringImpl>& a, const RefPtr<StringImpl>& b)
    {
        return equal(a.get(), b.get());
    }

    static unsigned hash(const UString& key) { return key.impl()->hash(); }
    static bool equal(const UString& a, const UString& b)
    {
        return equal(a.impl(), b.impl());
    }

    static const bool safeToCompareToEmptyOrDeleted = false;
};

} // namespace JSC

namespace WTF {

// UStringHash is the default hash for UString
template<typename T> struct DefaultHash;
template<> struct DefaultHash<JSC::UString> {
    typedef JSC::UStringHash Hash;
};

template <> struct VectorTraits<JSC::UString> : SimpleClassVectorTraits { };

} // namespace WTF

#endif

