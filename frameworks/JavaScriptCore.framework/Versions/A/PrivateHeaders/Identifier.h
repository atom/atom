/*
 *  Copyright (C) 2003, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 *
 */

#ifndef Identifier_h
#define Identifier_h

#include "JSGlobalData.h"
#include "ThreadSpecific.h"
#include "UString.h"
#include <wtf/WTFThreadData.h>
#include <wtf/text/CString.h>

namespace JSC {

    class ExecState;

    class Identifier {
        friend class Structure;
    public:
        Identifier() { }

        Identifier(ExecState* exec, const char* s) : m_string(add(exec, s)) { } // Only to be used with string literals.
        Identifier(ExecState* exec, StringImpl* rep) : m_string(add(exec, rep)) { } 
        Identifier(ExecState* exec, const UString& s) : m_string(add(exec, s.impl())) { }

        Identifier(JSGlobalData* globalData, const char* s) : m_string(add(globalData, s)) { } // Only to be used with string literals.
        Identifier(JSGlobalData* globalData, const LChar* s, int length) : m_string(add(globalData, s, length)) { }
        Identifier(JSGlobalData* globalData, const UChar* s, int length) : m_string(add(globalData, s, length)) { }
        Identifier(JSGlobalData* globalData, StringImpl* rep) : m_string(add(globalData, rep)) { } 
        Identifier(JSGlobalData* globalData, const UString& s) : m_string(add(globalData, s.impl())) { }

        const UString& ustring() const { return m_string; }
        StringImpl* impl() const { return m_string.impl(); }
        
        const UChar* characters() const { return m_string.characters(); }
        int length() const { return m_string.length(); }
        
        CString ascii() const { return m_string.ascii(); }

        static Identifier createLCharFromUChar(JSGlobalData* globalData, const UChar* s, int length) { return Identifier(globalData, add8(globalData, s, length)); }

        JS_EXPORT_PRIVATE static Identifier from(ExecState* exec, unsigned y);
        JS_EXPORT_PRIVATE static Identifier from(ExecState* exec, int y);
        static Identifier from(ExecState* exec, double y);
        static Identifier from(JSGlobalData*, unsigned y);
        static Identifier from(JSGlobalData*, int y);
        static Identifier from(JSGlobalData*, double y);

        JS_EXPORT_PRIVATE static uint32_t toUInt32(const UString&, bool& ok);
        uint32_t toUInt32(bool& ok) const { return toUInt32(m_string, ok); }
        unsigned toArrayIndex(bool& ok) const;

        bool isNull() const { return m_string.isNull(); }
        bool isEmpty() const { return m_string.isEmpty(); }
        
        friend bool operator==(const Identifier&, const Identifier&);
        friend bool operator!=(const Identifier&, const Identifier&);

        friend bool operator==(const Identifier&, const LChar*);
        friend bool operator==(const Identifier&, const char*);
        friend bool operator!=(const Identifier&, const LChar*);
        friend bool operator!=(const Identifier&, const char*);
    
        static bool equal(const StringImpl*, const LChar*);
        static inline bool equal(const StringImpl*a, const char*b) { return Identifier::equal(a, reinterpret_cast<const LChar*>(b)); };
        static bool equal(const StringImpl*, const LChar*, unsigned length);
        static bool equal(const StringImpl*, const UChar*, unsigned length);
        static bool equal(const StringImpl* a, const StringImpl* b) { return ::equal(a, b); }

        JS_EXPORT_PRIVATE static PassRefPtr<StringImpl> add(ExecState*, const char*); // Only to be used with string literals.
        static PassRefPtr<StringImpl> add(JSGlobalData*, const char*); // Only to be used with string literals.

    private:
        UString m_string;

        template <typename CharType>
        ALWAYS_INLINE static uint32_t toUInt32FromCharacters(const CharType* characters, unsigned length, bool& ok);

        static bool equal(const Identifier& a, const Identifier& b) { return a.m_string.impl() == b.m_string.impl(); }
        static bool equal(const Identifier& a, const LChar* b) { return equal(a.m_string.impl(), b); }

        template <typename T> static PassRefPtr<StringImpl> add(JSGlobalData*, const T*, int length);
        static PassRefPtr<StringImpl> add8(JSGlobalData*, const UChar*, int length);
        template <typename T> ALWAYS_INLINE static bool canUseSingleCharacterString(T);

        static PassRefPtr<StringImpl> add(ExecState* exec, StringImpl* r)
        {
#ifndef NDEBUG
            checkCurrentIdentifierTable(exec);
#endif
            if (r->isIdentifier())
                return r;
            return addSlowCase(exec, r);
        }
        static PassRefPtr<StringImpl> add(JSGlobalData* globalData, StringImpl* r)
        {
#ifndef NDEBUG
            checkCurrentIdentifierTable(globalData);
#endif
            if (r->isIdentifier())
                return r;
            return addSlowCase(globalData, r);
        }

        JS_EXPORT_PRIVATE static PassRefPtr<StringImpl> addSlowCase(ExecState*, StringImpl* r);
        JS_EXPORT_PRIVATE static PassRefPtr<StringImpl> addSlowCase(JSGlobalData*, StringImpl* r);

        JS_EXPORT_PRIVATE static void checkCurrentIdentifierTable(ExecState*);
        JS_EXPORT_PRIVATE static void checkCurrentIdentifierTable(JSGlobalData*);
    };

    template <> ALWAYS_INLINE bool Identifier::canUseSingleCharacterString(LChar)
    {
        ASSERT(maxSingleCharacterString == 0xff);
        return true;
    }

    template <> ALWAYS_INLINE bool Identifier::canUseSingleCharacterString(UChar c)
    {
        return (c <= maxSingleCharacterString);
    }

    template <typename T>
    struct CharBuffer {
        const T* s;
        unsigned int length;
    };
    
    template <typename T>
    struct IdentifierCharBufferTranslator {
        static unsigned hash(const CharBuffer<T>& buf)
        {
            return StringHasher::computeHash<T>(buf.s, buf.length);
        }
        
        static bool equal(StringImpl* str, const CharBuffer<T>& buf)
        {
            return Identifier::equal(str, buf.s, buf.length);
        }

        static void translate(StringImpl*& location, const CharBuffer<T>& buf, unsigned hash)
        {
            T* d;
            StringImpl* r = StringImpl::createUninitialized(buf.length, d).leakRef();
            for (unsigned i = 0; i != buf.length; i++)
                d[i] = buf.s[i];
            r->setHash(hash);
            location = r; 
        }
    };

    template <typename T>
    PassRefPtr<StringImpl> Identifier::add(JSGlobalData* globalData, const T* s, int length)
    {
        if (length == 1) {
            T c = s[0];
            if (canUseSingleCharacterString(c))
                return add(globalData, globalData->smallStrings.singleCharacterStringRep(c));
        }
        
        if (!length)
            return StringImpl::empty();
        CharBuffer<T> buf = {s, length}; 
        pair<HashSet<StringImpl*>::iterator, bool> addResult = globalData->identifierTable->add<CharBuffer<T>, IdentifierCharBufferTranslator<T> >(buf);
        
        // If the string is newly-translated, then we need to adopt it.
        // The boolean in the pair tells us if that is so.
        return addResult.second ? adoptRef(*addResult.first) : *addResult.first;
    }

    inline bool operator==(const Identifier& a, const Identifier& b)
    {
        return Identifier::equal(a, b);
    }

    inline bool operator!=(const Identifier& a, const Identifier& b)
    {
        return !Identifier::equal(a, b);
    }

    inline bool operator==(const Identifier& a, const LChar* b)
    {
        return Identifier::equal(a, b);
    }

    inline bool operator==(const Identifier& a, const char* b)
    {
        return Identifier::equal(a, reinterpret_cast<const LChar*>(b));
    }
    
    inline bool operator!=(const Identifier& a, const LChar* b)
    {
        return !Identifier::equal(a, b);
    }

    inline bool operator!=(const Identifier& a, const char* b)
    {
        return !Identifier::equal(a, reinterpret_cast<const LChar*>(b));
    }
    
    inline bool Identifier::equal(const StringImpl* r, const LChar* s)
    {
        return WTF::equal(r, s);
    }

    inline bool Identifier::equal(const StringImpl* r, const LChar* s, unsigned length)
    {
        return WTF::equal(r, s, length);
    }

    inline bool Identifier::equal(const StringImpl* r, const UChar* s, unsigned length)
    {
        return WTF::equal(r, s, length);
    }
    
    IdentifierTable* createIdentifierTable();
    void deleteIdentifierTable(IdentifierTable*);

    struct IdentifierRepHash : PtrHash<RefPtr<StringImpl> > {
        static unsigned hash(const RefPtr<StringImpl>& key) { return key->existingHash(); }
        static unsigned hash(StringImpl* key) { return key->existingHash(); }
    };

    struct IdentifierMapIndexHashTraits : HashTraits<int> {
        static int emptyValue() { return std::numeric_limits<int>::max(); }
        static const bool emptyValueIsZero = false;
    };

    typedef HashMap<RefPtr<StringImpl>, int, IdentifierRepHash, HashTraits<RefPtr<StringImpl> >, IdentifierMapIndexHashTraits> IdentifierMap;

    template<typename U, typename V>
    std::pair<HashSet<StringImpl*>::iterator, bool> IdentifierTable::add(U value)
    {
        std::pair<HashSet<StringImpl*>::iterator, bool> result = m_table.add<U, V>(value);
        (*result.first)->setIsIdentifier(true);
        return result;
    }

} // namespace JSC

#endif // Identifier_h
