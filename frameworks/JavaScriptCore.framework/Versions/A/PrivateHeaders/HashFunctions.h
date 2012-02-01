/*
 * Copyright (C) 2005, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef WTF_HashFunctions_h
#define WTF_HashFunctions_h

#include "RefPtr.h"
#include <stdint.h>

namespace WTF {

    template<size_t size> struct IntTypes;
    template<> struct IntTypes<1> { typedef int8_t SignedType; typedef uint8_t UnsignedType; };
    template<> struct IntTypes<2> { typedef int16_t SignedType; typedef uint16_t UnsignedType; };
    template<> struct IntTypes<4> { typedef int32_t SignedType; typedef uint32_t UnsignedType; };
    template<> struct IntTypes<8> { typedef int64_t SignedType; typedef uint64_t UnsignedType; };

    // integer hash function

    // Thomas Wang's 32 Bit Mix Function: http://www.cris.com/~Ttwang/tech/inthash.htm
    inline unsigned intHash(uint8_t key8)
    {
        unsigned key = key8;
        key += ~(key << 15);
        key ^= (key >> 10);
        key += (key << 3);
        key ^= (key >> 6);
        key += ~(key << 11);
        key ^= (key >> 16);
        return key;
    }

    // Thomas Wang's 32 Bit Mix Function: http://www.cris.com/~Ttwang/tech/inthash.htm
    inline unsigned intHash(uint16_t key16)
    {
        unsigned key = key16;
        key += ~(key << 15);
        key ^= (key >> 10);
        key += (key << 3);
        key ^= (key >> 6);
        key += ~(key << 11);
        key ^= (key >> 16);
        return key;
    }

    // Thomas Wang's 32 Bit Mix Function: http://www.cris.com/~Ttwang/tech/inthash.htm
    inline unsigned intHash(uint32_t key) 
    {
        key += ~(key << 15);
        key ^= (key >> 10);
        key += (key << 3);
        key ^= (key >> 6);
        key += ~(key << 11);
        key ^= (key >> 16);
        return key;
    }
    
    // Thomas Wang's 64 bit Mix Function: http://www.cris.com/~Ttwang/tech/inthash.htm
    inline unsigned intHash(uint64_t key)
    {
        key += ~(key << 32);
        key ^= (key >> 22);
        key += ~(key << 13);
        key ^= (key >> 8);
        key += (key << 3);
        key ^= (key >> 15);
        key += ~(key << 27);
        key ^= (key >> 31);
        return static_cast<unsigned>(key);
    }

    template<typename T> struct IntHash {
        static unsigned hash(T key) { return intHash(static_cast<typename IntTypes<sizeof(T)>::UnsignedType>(key)); }
        static bool equal(T a, T b) { return a == b; }
        static const bool safeToCompareToEmptyOrDeleted = true;
    };

    template<typename T> struct FloatHash {
        static unsigned hash(T key)
        {
            union {
                T key;
                typename IntTypes<sizeof(T)>::UnsignedType bits;
            } u;
            u.key = key;
            return intHash(u.bits);
        }
        static bool equal(T a, T b) { return a == b; }
        static const bool safeToCompareToEmptyOrDeleted = true;
    };

    // pointer identity hash function

    template<typename T> struct PtrHash {
        static unsigned hash(T key)
        {
#if COMPILER(MSVC)
#pragma warning(push)
#pragma warning(disable: 4244) // work around what seems to be a bug in MSVC's conversion warnings
#endif
            return IntHash<uintptr_t>::hash(reinterpret_cast<uintptr_t>(key));
#if COMPILER(MSVC)
#pragma warning(pop)
#endif
        }
        static bool equal(T a, T b) { return a == b; }
        static const bool safeToCompareToEmptyOrDeleted = true;
    };
    template<typename P> struct PtrHash<RefPtr<P> > : PtrHash<P*> {
        using PtrHash<P*>::hash;
        static unsigned hash(const RefPtr<P>& key) { return hash(key.get()); }
        using PtrHash<P*>::equal;
        static bool equal(const RefPtr<P>& a, const RefPtr<P>& b) { return a == b; }
        static bool equal(P* a, const RefPtr<P>& b) { return a == b; }
        static bool equal(const RefPtr<P>& a, P* b) { return a == b; }
    };

    // default hash function for each type

    template<typename T> struct DefaultHash;

    template<typename T, typename U> struct PairHash {
        static unsigned hash(const std::pair<T, U>& p)
        {
            return intHash((static_cast<uint64_t>(DefaultHash<T>::Hash::hash(p.first)) << 32 | DefaultHash<U>::Hash::hash(p.second)));
        }
        static bool equal(const std::pair<T, U>& a, const std::pair<T, U>& b)
        {
            return DefaultHash<T>::Hash::equal(a.first, b.first) && DefaultHash<U>::Hash::equal(a.second, b.second);
        }
        static const bool safeToCompareToEmptyOrDeleted = DefaultHash<T>::Hash::safeToCompareToEmptyOrDeleted 
                                                            && DefaultHash<U>::Hash::safeToCompareToEmptyOrDeleted;
    };

    // make IntHash the default hash function for many integer types

    template<> struct DefaultHash<short> { typedef IntHash<unsigned> Hash; };
    template<> struct DefaultHash<unsigned short> { typedef IntHash<unsigned> Hash; };
    template<> struct DefaultHash<int> { typedef IntHash<unsigned> Hash; };
    template<> struct DefaultHash<unsigned> { typedef IntHash<unsigned> Hash; };
    template<> struct DefaultHash<long> { typedef IntHash<unsigned long> Hash; };
    template<> struct DefaultHash<unsigned long> { typedef IntHash<unsigned long> Hash; };
    template<> struct DefaultHash<long long> { typedef IntHash<unsigned long long> Hash; };
    template<> struct DefaultHash<unsigned long long> { typedef IntHash<unsigned long long> Hash; };

#if !COMPILER(MSVC) || defined(_NATIVE_WCHAR_T_DEFINED)
    template<> struct DefaultHash<wchar_t> { typedef IntHash<wchar_t> Hash; };
#endif

    template<> struct DefaultHash<float> { typedef FloatHash<float> Hash; };
    template<> struct DefaultHash<double> { typedef FloatHash<double> Hash; };

    // make PtrHash the default hash function for pointer types that don't specialize

    template<typename P> struct DefaultHash<P*> { typedef PtrHash<P*> Hash; };
    template<typename P> struct DefaultHash<RefPtr<P> > { typedef PtrHash<RefPtr<P> > Hash; };

    template<typename T, typename U> struct DefaultHash<std::pair<T, U> > { typedef PairHash<T, U> Hash; };

} // namespace WTF

using WTF::DefaultHash;
using WTF::IntHash;
using WTF::PtrHash;

#endif // WTF_HashFunctions_h
