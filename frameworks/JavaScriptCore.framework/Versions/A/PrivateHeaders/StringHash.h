/*
 * Copyright (C) 2006, 2007, 2008 Apple Inc. All rights reserved
 * Copyright (C) Research In Motion Limited 2009. All rights reserved.
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

#ifndef StringHash_h
#define StringHash_h

#include "AtomicString.h"
#include "WTFString.h"
#include <wtf/Forward.h>
#include <wtf/HashTraits.h>
#include <wtf/StringHasher.h>
#include <wtf/unicode/Unicode.h>

namespace WTF {

    // The hash() functions on StringHash and CaseFoldingHash do not support
    // null strings. get(), contains(), and add() on HashMap<String,..., StringHash>
    // cause a null-pointer dereference when passed null strings.

    // FIXME: We should really figure out a way to put the computeHash function that's
    // currently a member function of StringImpl into this file so we can be a little
    // closer to having all the nearly-identical hash functions in one place.

    struct StringHash {
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

            if (a->is8Bit()) {
                if (b->is8Bit()) {
                    // Both a & b are 8 bit.
                    return WTF::equal(a->characters8(), b->characters8(), aLength);
                }

                // We know that a is 8 bit & b is 16 bit.
                return WTF::equal(a->characters8(), b->characters16(), aLength);
            }

            if (b->is8Bit()) {
                // We know that a is 8 bit and b is 16 bit.
                return WTF::equal(a->characters16(), b->characters8(), aLength);
            }

            return WTF::equal(a->characters16(), b->characters16(), aLength);
        }

        static unsigned hash(const RefPtr<StringImpl>& key) { return key->hash(); }
        static bool equal(const RefPtr<StringImpl>& a, const RefPtr<StringImpl>& b)
        {
            return equal(a.get(), b.get());
        }

        static unsigned hash(const String& key) { return key.impl()->hash(); }
        static bool equal(const String& a, const String& b)
        {
            return equal(a.impl(), b.impl());
        }

        static const bool safeToCompareToEmptyOrDeleted = false;
    };

    class CaseFoldingHash {
    public:
        template<typename T> static inline UChar foldCase(T ch)
        {
            return WTF::Unicode::foldCase(ch);
        }

        static unsigned hash(const UChar* data, unsigned length)
        {
            return StringHasher::computeHash<UChar, foldCase<UChar> >(data, length);
        }

        static unsigned hash(StringImpl* str)
        {
            return hash(str->characters(), str->length());
        }

        static unsigned hash(const LChar* data, unsigned length)
        {
            return StringHasher::computeHash<LChar, foldCase<LChar> >(data, length);
        }

        static inline unsigned hash(const char* data, unsigned length)
        {
            return CaseFoldingHash::hash(reinterpret_cast<const LChar*>(data), length);
        }
        
        static bool equal(const StringImpl* a, const StringImpl* b)
        {
            if (a == b)
                return true;
            if (!a || !b)
                return false;
            unsigned length = a->length();
            if (length != b->length())
                return false;
            return WTF::Unicode::umemcasecmp(a->characters(), b->characters(), length) == 0;
        }

        static unsigned hash(const RefPtr<StringImpl>& key) 
        {
            return hash(key.get());
        }

        static bool equal(const RefPtr<StringImpl>& a, const RefPtr<StringImpl>& b)
        {
            return equal(a.get(), b.get());
        }

        static unsigned hash(const String& key)
        {
            return hash(key.impl());
        }
        static unsigned hash(const AtomicString& key)
        {
            return hash(key.impl());
        }
        static bool equal(const String& a, const String& b)
        {
            return equal(a.impl(), b.impl());
        }
        static bool equal(const AtomicString& a, const AtomicString& b)
        {
            return (a == b) || equal(a.impl(), b.impl());
        }

        static const bool safeToCompareToEmptyOrDeleted = false;
    };

    // This hash can be used in cases where the key is a hash of a string, but we don't
    // want to store the string. It's not really specific to string hashing, but all our
    // current uses of it are for strings.
    struct AlreadyHashed : IntHash<unsigned> {
        static unsigned hash(unsigned key) { return key; }

        // To use a hash value as a key for a hash table, we need to eliminate the
        // "deleted" value, which is negative one. That could be done by changing
        // the string hash function to never generate negative one, but this works
        // and is still relatively efficient.
        static unsigned avoidDeletedValue(unsigned hash)
        {
            ASSERT(hash);
            unsigned newHash = hash | (!(hash + 1) << 31);
            ASSERT(newHash);
            ASSERT(newHash != 0xFFFFFFFF);
            return newHash;
        }
    };

}

using WTF::StringHash;
using WTF::CaseFoldingHash;
using WTF::AlreadyHashed;

#endif
