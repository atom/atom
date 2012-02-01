/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef StringImpl_h
#define StringImpl_h

#include <limits.h>
#include <wtf/ASCIICType.h>
#include <wtf/Forward.h>
#include <wtf/StdLibExtras.h>
#include <wtf/StringHasher.h>
#include <wtf/Vector.h>
#include <wtf/unicode/Unicode.h>

#if USE(CF)
typedef const struct __CFString * CFStringRef;
#endif

#ifdef __OBJC__
@class NSString;
#endif

// FIXME: This is a temporary layering violation while we move string code to WTF.
// Landing the file moves in one patch, will follow on with patches to change the namespaces.
namespace JSC {
struct IdentifierCStringTranslator;
template <typename T> struct IdentifierCharBufferTranslator;
struct IdentifierLCharFromUCharTranslator;
}

namespace WTF {

struct CStringTranslator;
struct HashAndCharactersTranslator;
struct HashAndUTF8CharactersTranslator;
struct SubstringTranslator;
struct UCharBufferTranslator;

enum TextCaseSensitivity { TextCaseSensitive, TextCaseInsensitive };

typedef bool (*CharacterMatchFunctionPtr)(UChar);
typedef bool (*IsWhiteSpaceFunctionPtr)(UChar);

class StringImpl {
    WTF_MAKE_NONCOPYABLE(StringImpl); WTF_MAKE_FAST_ALLOCATED;
    friend struct JSC::IdentifierCStringTranslator;
    friend struct JSC::IdentifierCharBufferTranslator<LChar>;
    friend struct JSC::IdentifierCharBufferTranslator<UChar>;
    friend struct JSC::IdentifierLCharFromUCharTranslator;
    friend struct WTF::CStringTranslator;
    friend struct WTF::HashAndCharactersTranslator;
    friend struct WTF::HashAndUTF8CharactersTranslator;
    friend struct WTF::SubstringTranslator;
    friend struct WTF::UCharBufferTranslator;
    friend class AtomicStringImpl;

private:
    enum BufferOwnership {
        BufferInternal,
        BufferOwned,
        BufferSubstring,
    };

    // Used to construct static strings, which have an special refCount that can never hit zero.
    // This means that the static string will never be destroyed, which is important because
    // static strings will be shared across threads & ref-counted in a non-threadsafe manner.
    enum ConstructStaticStringTag { ConstructStaticString };
    StringImpl(const UChar* characters, unsigned length, ConstructStaticStringTag)
        : m_refCount(s_refCountFlagIsStaticString)
        , m_length(length)
        , m_data16(characters)
        , m_buffer(0)
        , m_hashAndFlags(s_hashFlagIsIdentifier | BufferOwned)
    {
        // Ensure that the hash is computed so that AtomicStringHash can call existingHash()
        // with impunity. The empty string is special because it is never entered into
        // AtomicString's HashKey, but still needs to compare correctly.
        hash();
    }

    // Used to construct static strings, which have an special refCount that can never hit zero.
    // This means that the static string will never be destroyed, which is important because
    // static strings will be shared across threads & ref-counted in a non-threadsafe manner.
    StringImpl(const LChar* characters, unsigned length, ConstructStaticStringTag)
        : m_refCount(s_refCountFlagIsStaticString)
        , m_length(length)
        , m_data8(characters)
        , m_buffer(0)
        , m_hashAndFlags(s_hashFlag8BitBuffer | s_hashFlagIsIdentifier | BufferOwned)
    {
        // Ensure that the hash is computed so that AtomicStringHash can call existingHash()
        // with impunity. The empty string is special because it is never entered into
        // AtomicString's HashKey, but still needs to compare correctly.
        hash();
    }

    // FIXME: there has to be a less hacky way to do this.
    enum Force8Bit { Force8BitConstructor };
    // Create a normal 8-bit string with internal storage (BufferInternal)
    StringImpl(unsigned length, Force8Bit)
        : m_refCount(s_refCountIncrement)
        , m_length(length)
        , m_data8(reinterpret_cast<const LChar*>(this + 1))
        , m_buffer(0)
        , m_hashAndFlags(s_hashFlag8BitBuffer | BufferInternal)
    {
        ASSERT(m_data8);
        ASSERT(m_length);
    }

    // Create a normal 16-bit string with internal storage (BufferInternal)
    StringImpl(unsigned length)
        : m_refCount(s_refCountIncrement)
        , m_length(length)
        , m_data16(reinterpret_cast<const UChar*>(this + 1))
        , m_buffer(0)
        , m_hashAndFlags(BufferInternal)
    {
        ASSERT(m_data16);
        ASSERT(m_length);
    }

    // Create a StringImpl adopting ownership of the provided buffer (BufferOwned)
    StringImpl(const LChar* characters, unsigned length)
        : m_refCount(s_refCountIncrement)
        , m_length(length)
        , m_data8(characters)
        , m_buffer(0)
        , m_hashAndFlags(s_hashFlag8BitBuffer | BufferOwned)
    {
        ASSERT(m_data8);
        ASSERT(m_length);
    }

    // Create a StringImpl adopting ownership of the provided buffer (BufferOwned)
    StringImpl(const UChar* characters, unsigned length)
    : m_refCount(s_refCountIncrement)
    , m_length(length)
    , m_data16(characters)
    , m_buffer(0)
    , m_hashAndFlags(BufferOwned)
    {
        ASSERT(m_data16);
        ASSERT(m_length);
    }

    // Used to create new strings that are a substring of an existing 8-bit StringImpl (BufferSubstring)
    StringImpl(const LChar* characters, unsigned length, PassRefPtr<StringImpl> base)
        : m_refCount(s_refCountIncrement)
        , m_length(length)
        , m_data8(characters)
        , m_substringBuffer(base.leakRef())
        , m_hashAndFlags(s_hashFlag8BitBuffer | BufferSubstring)
    {
        ASSERT(is8Bit());
        ASSERT(m_data8);
        ASSERT(m_length);
        ASSERT(m_substringBuffer->bufferOwnership() != BufferSubstring);
    }

    // Used to create new strings that are a substring of an existing 16-bit StringImpl (BufferSubstring)
    StringImpl(const UChar* characters, unsigned length, PassRefPtr<StringImpl> base)
        : m_refCount(s_refCountIncrement)
        , m_length(length)
        , m_data16(characters)
        , m_substringBuffer(base.leakRef())
        , m_hashAndFlags(BufferSubstring)
    {
        ASSERT(!is8Bit());
        ASSERT(m_data16);
        ASSERT(m_length);
        ASSERT(m_substringBuffer->bufferOwnership() != BufferSubstring);
    }

public:
    WTF_EXPORT_PRIVATE ~StringImpl();

    WTF_EXPORT_PRIVATE static PassRefPtr<StringImpl> create(const UChar*, unsigned length);
    static PassRefPtr<StringImpl> create(const LChar*, unsigned length);
    ALWAYS_INLINE static PassRefPtr<StringImpl> create(const char* s, unsigned length) { return create(reinterpret_cast<const LChar*>(s), length); }
    WTF_EXPORT_PRIVATE static PassRefPtr<StringImpl> create(const LChar*);
    ALWAYS_INLINE static PassRefPtr<StringImpl> create(const char* s) { return create(reinterpret_cast<const LChar*>(s)); }

    static ALWAYS_INLINE PassRefPtr<StringImpl> create8(PassRefPtr<StringImpl> rep, unsigned offset, unsigned length)
    {
        ASSERT(rep);
        ASSERT(length <= rep->length());

        if (!length)
            return empty();

        ASSERT(rep->is8Bit());
        StringImpl* ownerRep = (rep->bufferOwnership() == BufferSubstring) ? rep->m_substringBuffer : rep.get();
        return adoptRef(new StringImpl(rep->m_data8 + offset, length, ownerRep));
    }

    static ALWAYS_INLINE PassRefPtr<StringImpl> create(PassRefPtr<StringImpl> rep, unsigned offset, unsigned length)
    {
        ASSERT(rep);
        ASSERT(length <= rep->length());

        if (!length)
            return empty();

        StringImpl* ownerRep = (rep->bufferOwnership() == BufferSubstring) ? rep->m_substringBuffer : rep.get();
        if (rep->is8Bit())
            return adoptRef(new StringImpl(rep->m_data8 + offset, length, ownerRep));
        return adoptRef(new StringImpl(rep->m_data16 + offset, length, ownerRep));
    }

    static PassRefPtr<StringImpl> createUninitialized(unsigned length, LChar*& data);
    WTF_EXPORT_PRIVATE static PassRefPtr<StringImpl> createUninitialized(unsigned length, UChar*& data);
    template <typename T> static ALWAYS_INLINE PassRefPtr<StringImpl> tryCreateUninitialized(unsigned length, T*& output)
    {
        if (!length) {
            output = 0;
            return empty();
        }

        if (length > ((std::numeric_limits<unsigned>::max() - sizeof(StringImpl)) / sizeof(T))) {
            output = 0;
            return 0;
        }
        StringImpl* resultImpl;
        if (!tryFastMalloc(sizeof(T) * length + sizeof(StringImpl)).getValue(resultImpl)) {
            output = 0;
            return 0;
        }
        output = reinterpret_cast<T*>(resultImpl + 1);

        if (sizeof(T) == sizeof(char))
            return adoptRef(new (NotNull, resultImpl) StringImpl(length, Force8BitConstructor));

        return adoptRef(new (NotNull, resultImpl) StringImpl(length));
    }

    // Reallocate the StringImpl. The originalString must be only owned by the PassRefPtr,
    // and the buffer ownership must be BufferInternal. Just like the input pointer of realloc(),
    // the originalString can't be used after this function.
    static PassRefPtr<StringImpl> reallocate(PassRefPtr<StringImpl> originalString, unsigned length, LChar*& data);
    static PassRefPtr<StringImpl> reallocate(PassRefPtr<StringImpl> originalString, unsigned length, UChar*& data);

    static unsigned flagsOffset() { return OBJECT_OFFSETOF(StringImpl, m_hashAndFlags); }
    static unsigned flagIs8Bit() { return s_hashFlag8BitBuffer; }
    static unsigned dataOffset() { return OBJECT_OFFSETOF(StringImpl, m_data8); }
    static PassRefPtr<StringImpl> createWithTerminatingNullCharacter(const StringImpl&);

    template<typename CharType, size_t inlineCapacity>
    static PassRefPtr<StringImpl> adopt(Vector<CharType, inlineCapacity>& vector)
    {
        if (size_t size = vector.size()) {
            ASSERT(vector.data());
            if (size > std::numeric_limits<unsigned>::max())
                CRASH();
            return adoptRef(new StringImpl(vector.releaseBuffer(), size));
        }
        return empty();
    }

    static PassRefPtr<StringImpl> adopt(StringBuffer<LChar>& buffer);
    WTF_EXPORT_PRIVATE static PassRefPtr<StringImpl> adopt(StringBuffer<UChar>& buffer);

    unsigned length() const { return m_length; }
    bool is8Bit() const { return m_hashAndFlags & s_hashFlag8BitBuffer; }

    // FIXME: Remove all unnecessary usages of characters()
    ALWAYS_INLINE const LChar* characters8() const { ASSERT(is8Bit()); return m_data8; }
    ALWAYS_INLINE const UChar* characters16() const { ASSERT(!is8Bit()); return m_data16; }
    ALWAYS_INLINE const UChar* characters() const
    {
        if (!is8Bit())
            return m_data16;

        return getData16SlowCase();
    }

    template <typename CharType>
    ALWAYS_INLINE const CharType * getCharacters() const;

    size_t cost()
    {
        // For substrings, return the cost of the base string.
        if (bufferOwnership() == BufferSubstring)
            return m_substringBuffer->cost();

        if (m_hashAndFlags & s_hashFlagDidReportCost)
            return 0;

        m_hashAndFlags |= s_hashFlagDidReportCost;
        return m_length;
    }

    bool has16BitShadow() const { return m_hashAndFlags & s_hashFlagHas16BitShadow; }
    WTF_EXPORT_PRIVATE void upconvertCharacters(unsigned, unsigned) const;
    bool isIdentifier() const { return m_hashAndFlags & s_hashFlagIsIdentifier; }
    void setIsIdentifier(bool isIdentifier)
    {
        ASSERT(!isStatic());
        if (isIdentifier)
            m_hashAndFlags |= s_hashFlagIsIdentifier;
        else
            m_hashAndFlags &= ~s_hashFlagIsIdentifier;
    }

    bool hasTerminatingNullCharacter() const { return m_hashAndFlags & s_hashFlagHasTerminatingNullCharacter; }

    bool isAtomic() const { return m_hashAndFlags & s_hashFlagIsAtomic; }
    void setIsAtomic(bool isIdentifier)
    {
        ASSERT(!isStatic());
        if (isIdentifier)
            m_hashAndFlags |= s_hashFlagIsAtomic;
        else
            m_hashAndFlags &= ~s_hashFlagIsAtomic;
    }

private:
    // The high bits of 'hash' are always empty, but we prefer to store our flags
    // in the low bits because it makes them slightly more efficient to access.
    // So, we shift left and right when setting and getting our hash code.
    void setHash(unsigned hash) const
    {
        ASSERT(!hasHash());
        // Multiple clients assume that StringHasher is the canonical string hash function.
        ASSERT(hash == (is8Bit() ? StringHasher::computeHash(m_data8, m_length) : StringHasher::computeHash(m_data16, m_length)));
        ASSERT(!(hash & (s_flagMask << (8 * sizeof(hash) - s_flagCount)))); // Verify that enough high bits are empty.
        
        hash <<= s_flagCount;
        ASSERT(!(hash & m_hashAndFlags)); // Verify that enough low bits are empty after shift.
        ASSERT(hash); // Verify that 0 is a valid sentinel hash value.

        m_hashAndFlags |= hash; // Store hash with flags in low bits.
    }

    unsigned rawHash() const
    {
        return m_hashAndFlags >> s_flagCount;
    }

public:
    bool hasHash() const
    {
        return rawHash() != 0;
    }

    unsigned existingHash() const
    {
        ASSERT(hasHash());
        return rawHash();
    }

    unsigned hash() const
    {
        if (hasHash())
            return existingHash();
        return hashSlowCase();
    }

    inline bool hasOneRef() const
    {
        return m_refCount == s_refCountIncrement;
    }

    inline void ref()
    {
        m_refCount += s_refCountIncrement;
    }

    inline void deref()
    {
        if (m_refCount == s_refCountIncrement) {
            delete this;
            return;
        }

        m_refCount -= s_refCountIncrement;
    }

    WTF_EXPORT_PRIVATE static StringImpl* empty();

    // FIXME: Does this really belong in StringImpl?
    template <typename T> static void copyChars(T* destination, const T* source, unsigned numCharacters)
    {
        if (numCharacters == 1) {
            *destination = *source;
            return;
        }

        if (numCharacters <= s_copyCharsInlineCutOff) {
            unsigned i = 0;
#if (CPU(X86) || CPU(X86_64))
            const unsigned charsPerInt = sizeof(uint32_t) / sizeof(T);

            if (numCharacters > charsPerInt) {
                unsigned stopCount = numCharacters & ~(charsPerInt - 1);

                const uint32_t* srcCharacters = reinterpret_cast<const uint32_t*>(source);
                uint32_t* destCharacters = reinterpret_cast<uint32_t*>(destination);
                for (unsigned j = 0; i < stopCount; i += charsPerInt, ++j)
                    destCharacters[j] = srcCharacters[j];
            }
#endif
            for (; i < numCharacters; ++i)
                destination[i] = source[i];
        } else
            memcpy(destination, source, numCharacters * sizeof(T));
    }

    // Some string features, like refcounting and the atomicity flag, are not
    // thread-safe. We achieve thread safety by isolation, giving each thread
    // its own copy of the string.
    PassRefPtr<StringImpl> isolatedCopy() const;

    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> substring(unsigned pos, unsigned len = UINT_MAX);

    UChar operator[](unsigned i) const
    {
        ASSERT(i < m_length);
        if (is8Bit())
            return m_data8[i];
        return m_data16[i];
    }
    WTF_EXPORT_PRIVATE UChar32 characterStartingAt(unsigned);

    WTF_EXPORT_PRIVATE bool containsOnlyWhitespace();

    int toIntStrict(bool* ok = 0, int base = 10);
    unsigned toUIntStrict(bool* ok = 0, int base = 10);
    int64_t toInt64Strict(bool* ok = 0, int base = 10);
    uint64_t toUInt64Strict(bool* ok = 0, int base = 10);
    intptr_t toIntPtrStrict(bool* ok = 0, int base = 10);

    WTF_EXPORT_PRIVATE int toInt(bool* ok = 0); // ignores trailing garbage
    unsigned toUInt(bool* ok = 0); // ignores trailing garbage
    int64_t toInt64(bool* ok = 0); // ignores trailing garbage
    uint64_t toUInt64(bool* ok = 0); // ignores trailing garbage
    intptr_t toIntPtr(bool* ok = 0); // ignores trailing garbage

    double toDouble(bool* ok = 0, bool* didReadNumber = 0);
    float toFloat(bool* ok = 0, bool* didReadNumber = 0);

    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> lower();
    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> upper();

    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> fill(UChar);
    // FIXME: Do we need fill(char) or can we just do the right thing if UChar is ASCII?
    PassRefPtr<StringImpl> foldCase();

    PassRefPtr<StringImpl> stripWhiteSpace();
    PassRefPtr<StringImpl> stripWhiteSpace(IsWhiteSpaceFunctionPtr);
    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> simplifyWhiteSpace();
    PassRefPtr<StringImpl> simplifyWhiteSpace(IsWhiteSpaceFunctionPtr);

    PassRefPtr<StringImpl> removeCharacters(CharacterMatchFunctionPtr);
    template <typename CharType>
    ALWAYS_INLINE PassRefPtr<StringImpl> removeCharacters(const CharType* characters, CharacterMatchFunctionPtr);

    WTF_EXPORT_PRIVATE size_t find(UChar, unsigned index = 0);
    WTF_EXPORT_PRIVATE size_t find(CharacterMatchFunctionPtr, unsigned index = 0);
    size_t find(const LChar*, unsigned index = 0);
    ALWAYS_INLINE size_t find(const char* s, unsigned index = 0) { return find(reinterpret_cast<const LChar*>(s), index); };
    WTF_EXPORT_PRIVATE size_t find(StringImpl*, unsigned index = 0);
    size_t findIgnoringCase(const LChar*, unsigned index = 0);
    ALWAYS_INLINE size_t findIgnoringCase(const char* s, unsigned index = 0) { return findIgnoringCase(reinterpret_cast<const LChar*>(s), index); };
    WTF_EXPORT_PRIVATE size_t findIgnoringCase(StringImpl*, unsigned index = 0);

    WTF_EXPORT_PRIVATE size_t reverseFind(UChar, unsigned index = UINT_MAX);
    WTF_EXPORT_PRIVATE size_t reverseFind(StringImpl*, unsigned index = UINT_MAX);
    WTF_EXPORT_PRIVATE size_t reverseFindIgnoringCase(StringImpl*, unsigned index = UINT_MAX);

    bool startsWith(StringImpl* str, bool caseSensitive = true) { return (caseSensitive ? reverseFind(str, 0) : reverseFindIgnoringCase(str, 0)) == 0; }
    WTF_EXPORT_PRIVATE bool endsWith(StringImpl*, bool caseSensitive = true);

    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> replace(UChar, UChar);
    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> replace(UChar, StringImpl*);
    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> replace(StringImpl*, StringImpl*);
    WTF_EXPORT_PRIVATE PassRefPtr<StringImpl> replace(unsigned index, unsigned len, StringImpl*);

    WTF_EXPORT_PRIVATE WTF::Unicode::Direction defaultWritingDirection(bool* hasStrongDirectionality = 0);

#if USE(CF)
    CFStringRef createCFString();
#endif
#ifdef __OBJC__
    operator NSString*();
#endif

private:
    // This number must be at least 2 to avoid sharing empty, null as well as 1 character strings from SmallStrings.
    static const unsigned s_copyCharsInlineCutOff = 20;

    BufferOwnership bufferOwnership() const { return static_cast<BufferOwnership>(m_hashAndFlags & s_hashMaskBufferOwnership); }
    bool isStatic() const { return m_refCount & s_refCountFlagIsStaticString; }
    template <class UCharPredicate> PassRefPtr<StringImpl> stripMatchedCharacters(UCharPredicate);
    template <typename CharType, class UCharPredicate> PassRefPtr<StringImpl> simplifyMatchedCharactersToSpace(UCharPredicate);
    WTF_EXPORT_PRIVATE NEVER_INLINE const UChar* getData16SlowCase() const;
    WTF_EXPORT_PRIVATE NEVER_INLINE unsigned hashSlowCase() const;

    // The bottom bit in the ref count indicates a static (immortal) string.
    static const unsigned s_refCountFlagIsStaticString = 0x1;
    static const unsigned s_refCountIncrement = 0x2; // This allows us to ref / deref without disturbing the static string flag.

    // The bottom 8 bits in the hash are flags.
    static const unsigned s_flagCount = 8;
    static const unsigned s_flagMask = (1u << s_flagCount) - 1;
    COMPILE_ASSERT(s_flagCount == StringHasher::flagCount, StringHasher_reserves_enough_bits_for_StringImpl_flags);

    static const unsigned s_hashFlagHas16BitShadow = 1u << 7;
    static const unsigned s_hashFlag8BitBuffer = 1u << 6;
    static const unsigned s_hashFlagHasTerminatingNullCharacter = 1u << 5;
    static const unsigned s_hashFlagIsAtomic = 1u << 4;
    static const unsigned s_hashFlagDidReportCost = 1u << 3;
    static const unsigned s_hashFlagIsIdentifier = 1u << 2;
    static const unsigned s_hashMaskBufferOwnership = 1u | (1u << 1);

    unsigned m_refCount;
    unsigned m_length;
    union {
        const LChar* m_data8;
        const UChar* m_data16;
    };
    union {
        void* m_buffer;
        StringImpl* m_substringBuffer;
        mutable UChar* m_copyData16;
    };
    mutable unsigned m_hashAndFlags;
};

template <>
ALWAYS_INLINE const LChar* StringImpl::getCharacters<LChar>() const { return characters8(); }

template <>
ALWAYS_INLINE const UChar* StringImpl::getCharacters<UChar>() const { return characters16(); }

WTF_EXPORT_PRIVATE bool equal(const StringImpl*, const StringImpl*);
WTF_EXPORT_PRIVATE bool equal(const StringImpl*, const LChar*);
inline bool equal(const StringImpl* a, const char* b) { return equal(a, reinterpret_cast<const LChar*>(b)); }
WTF_EXPORT_PRIVATE bool equal(const StringImpl*, const LChar*, unsigned);
inline bool equal(const StringImpl* a, const char* b, unsigned length) { return equal(a, reinterpret_cast<const LChar*>(b), length); }
inline bool equal(const LChar* a, StringImpl* b) { return equal(b, a); }
inline bool equal(const char* a, StringImpl* b) { return equal(b, reinterpret_cast<const LChar*>(a)); }
WTF_EXPORT_PRIVATE bool equal(const StringImpl*, const UChar*, unsigned);

// Do comparisons 8 or 4 bytes-at-a-time on architectures where it's safe.
#if CPU(X86_64)
ALWAYS_INLINE bool equal(const LChar* a, const LChar* b, unsigned length)
{
    unsigned dwordLength = length >> 3;

    if (dwordLength) {
        const uint64_t* aDWordCharacters = reinterpret_cast<const uint64_t*>(a);
        const uint64_t* bDWordCharacters = reinterpret_cast<const uint64_t*>(b);

        for (unsigned i = 0; i != dwordLength; ++i) {
            if (*aDWordCharacters++ != *bDWordCharacters++)
                return false;
        }

        a = reinterpret_cast<const LChar*>(aDWordCharacters);
        b = reinterpret_cast<const LChar*>(bDWordCharacters);
    }

    if (length & 4) {
        if (*reinterpret_cast<const uint32_t*>(a) != *reinterpret_cast<const uint32_t*>(b))
            return false;

        a += 4;
        b += 4;
    }

    if (length & 2) {
        if (*reinterpret_cast<const uint16_t*>(a) != *reinterpret_cast<const uint16_t*>(b))
            return false;

        a += 2;
        b += 2;
    }

    if (length & 1 && (*a != *b))
        return false;

    return true;
}

ALWAYS_INLINE bool equal(const UChar* a, const UChar* b, unsigned length)
{
    unsigned dwordLength = length >> 2;
    
    if (dwordLength) {
        const uint64_t* aDWordCharacters = reinterpret_cast<const uint64_t*>(a);
        const uint64_t* bDWordCharacters = reinterpret_cast<const uint64_t*>(b);

        for (unsigned i = 0; i != dwordLength; ++i) {
            if (*aDWordCharacters++ != *bDWordCharacters++)
                return false;
        }

        a = reinterpret_cast<const UChar*>(aDWordCharacters);
        b = reinterpret_cast<const UChar*>(bDWordCharacters);
    }

    if (length & 2) {
        if (*reinterpret_cast<const uint32_t*>(a) != *reinterpret_cast<const uint32_t*>(b))
            return false;

        a += 2;
        b += 2;
    }

    if (length & 1 && (*a != *b))
        return false;

    return true;
}
#elif CPU(X86)
ALWAYS_INLINE bool equal(const LChar* a, const LChar* b, unsigned length)
{
    const uint32_t* aCharacters = reinterpret_cast<const uint32_t*>(a);
    const uint32_t* bCharacters = reinterpret_cast<const uint32_t*>(b);

    unsigned wordLength = length >> 2;
    for (unsigned i = 0; i != wordLength; ++i) {
        if (*aCharacters++ != *bCharacters++)
            return false;
    }

    length &= 3;

    if (length) {
        const LChar* aRemainder = reinterpret_cast<const LChar*>(aCharacters);
        const LChar* bRemainder = reinterpret_cast<const LChar*>(bCharacters);
        
        for (unsigned i = 0; i <  length; ++i) {
            if (aRemainder[i] != bRemainder[i])
                return false;
        }
    }

    return true;
}

ALWAYS_INLINE bool equal(const UChar* a, const UChar* b, unsigned length)
{
    const uint32_t* aCharacters = reinterpret_cast<const uint32_t*>(a);
    const uint32_t* bCharacters = reinterpret_cast<const uint32_t*>(b);
    
    unsigned wordLength = length >> 1;
    for (unsigned i = 0; i != wordLength; ++i) {
        if (*aCharacters++ != *bCharacters++)
            return false;
    }
    
    if (length & 1 && *reinterpret_cast<const UChar*>(aCharacters) != *reinterpret_cast<const UChar*>(bCharacters))
        return false;
    
    return true;
}
#else
ALWAYS_INLINE bool equal(const LChar* a, const LChar* b, unsigned length)
{
    for (unsigned i = 0; i != length; ++i) {
        if (a[i] != b[i])
            return false;
    }

    return true;
}

ALWAYS_INLINE bool equal(const UChar* a, const UChar* b, unsigned length)
{
    for (unsigned i = 0; i != length; ++i) {
        if (a[i] != b[i])
            return false;
    }

    return true;
}
#endif

ALWAYS_INLINE bool equal(const LChar* a, const UChar* b, unsigned length)
{
    for (unsigned i = 0; i != length; ++i) {
        if (a[i] != b[i])
            return false;
    }

    return true;
}

ALWAYS_INLINE bool equal(const UChar* a, const LChar* b, unsigned length)
{
    for (unsigned i = 0; i != length; ++i) {
        if (a[i] != b[i])
            return false;
    }

    return true;
}

WTF_EXPORT_PRIVATE bool equalIgnoringCase(StringImpl*, StringImpl*);
WTF_EXPORT_PRIVATE bool equalIgnoringCase(StringImpl*, const LChar*);
inline bool equalIgnoringCase(const LChar* a, StringImpl* b) { return equalIgnoringCase(b, a); }
WTF_EXPORT_PRIVATE bool equalIgnoringCase(const UChar*, const LChar*, unsigned);
inline bool equalIgnoringCase(const UChar* a, const char* b, unsigned length) { return equalIgnoringCase(a, reinterpret_cast<const LChar*>(b), length); }
inline bool equalIgnoringCase(const LChar* a, const UChar* b, unsigned length) { return equalIgnoringCase(b, a, length); }
inline bool equalIgnoringCase(const char* a, const UChar* b, unsigned length) { return equalIgnoringCase(b, reinterpret_cast<const LChar*>(a), length); }

WTF_EXPORT_PRIVATE bool equalIgnoringNullity(StringImpl*, StringImpl*);

template<size_t inlineCapacity>
bool equalIgnoringNullity(const Vector<UChar, inlineCapacity>& a, StringImpl* b)
{
    if (!b)
        return !a.size();
    if (a.size() != b->length())
        return false;
    return !memcmp(a.data(), b->characters(), b->length());
}

WTF_EXPORT_PRIVATE int codePointCompare(const StringImpl*, const StringImpl*);

static inline bool isSpaceOrNewline(UChar c)
{
    // Use isASCIISpace() for basic Latin-1.
    // This will include newlines, which aren't included in Unicode DirWS.
    return c <= 0x7F ? WTF::isASCIISpace(c) : WTF::Unicode::direction(c) == WTF::Unicode::WhiteSpaceNeutral;
}

inline PassRefPtr<StringImpl> StringImpl::isolatedCopy() const
{
    if (is8Bit())
        return create(m_data8, m_length);
    return create(m_data16, m_length);
}

struct StringHash;

// StringHash is the default hash for StringImpl* and RefPtr<StringImpl>
template<typename T> struct DefaultHash;
template<> struct DefaultHash<StringImpl*> {
    typedef StringHash Hash;
};
template<> struct DefaultHash<RefPtr<StringImpl> > {
    typedef StringHash Hash;
};

}

using WTF::StringImpl;
using WTF::equal;
using WTF::TextCaseSensitivity;
using WTF::TextCaseSensitive;
using WTF::TextCaseInsensitive;

#endif
