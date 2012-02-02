 /*
 * Copyright (C) 2006, 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) 2009, 2010 Google Inc. All rights reserved.
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

#ifndef TypeTraits_h
#define TypeTraits_h

#include "Platform.h"

#if (defined(__GLIBCXX__) && (__GLIBCXX__ >= 20070724) && defined(__GXX_EXPERIMENTAL_CXX0X__)) || (defined(_MSC_VER) && (_MSC_VER >= 1600))
#include <type_traits>
#if defined(__GXX_EXPERIMENTAL_CXX0X__)
#include <tr1/memory>
#endif
#endif

namespace WTF {

    // The following are provided in this file:
    //
    //   Conditional<Predicate, If, Then>::Type
    //
    //   IsInteger<T>::value
    //   IsPod<T>::value, see the definition for a note about its limitations
    //   IsConvertibleToInteger<T>::value
    //
    //   IsArray<T>::value
    //
    //   IsSameType<T, U>::value
    //
    //   RemovePointer<T>::Type
    //   RemoveReference<T>::Type
    //   RemoveConst<T>::Type
    //   RemoveVolatile<T>::Type
    //   RemoveConstVolatile<T>::Type
    //   RemoveExtent<T>::Type
    //
    //   DecayArray<T>::Type
    //
    //   COMPILE_ASSERT's in TypeTraits.cpp illustrate their usage and what they do.

    template <bool Predicate, class If, class Then> struct Conditional  { typedef If Type; };
    template <class If, class Then> struct Conditional<false, If, Then> { typedef Then Type; };

    template<typename T> struct IsInteger           { static const bool value = false; };
    template<> struct IsInteger<bool>               { static const bool value = true; };
    template<> struct IsInteger<char>               { static const bool value = true; };
    template<> struct IsInteger<signed char>        { static const bool value = true; };
    template<> struct IsInteger<unsigned char>      { static const bool value = true; };
    template<> struct IsInteger<short>              { static const bool value = true; };
    template<> struct IsInteger<unsigned short>     { static const bool value = true; };
    template<> struct IsInteger<int>                { static const bool value = true; };
    template<> struct IsInteger<unsigned int>       { static const bool value = true; };
    template<> struct IsInteger<long>               { static const bool value = true; };
    template<> struct IsInteger<unsigned long>      { static const bool value = true; };
    template<> struct IsInteger<long long>          { static const bool value = true; };
    template<> struct IsInteger<unsigned long long> { static const bool value = true; };
#if !COMPILER(MSVC) || defined(_NATIVE_WCHAR_T_DEFINED)
    template<> struct IsInteger<wchar_t>            { static const bool value = true; };
#endif

    template<typename T> struct IsFloatingPoint     { static const bool value = false; };
    template<> struct IsFloatingPoint<float>        { static const bool value = true; };
    template<> struct IsFloatingPoint<double>       { static const bool value = true; };
    template<> struct IsFloatingPoint<long double>  { static const bool value = true; };

    template<typename T> struct IsArithmetic     { static const bool value = IsInteger<T>::value || IsFloatingPoint<T>::value; };

    // IsPod is misnamed as it doesn't cover all plain old data (pod) types.
    // Specifically, it doesn't allow for enums or for structs.
    template <typename T> struct IsPod           { static const bool value = IsArithmetic<T>::value; };
    template <typename P> struct IsPod<P*>       { static const bool value = true; };

    template<typename T> class IsConvertibleToInteger {
        // Avoid "possible loss of data" warning when using Microsoft's C++ compiler
        // by not converting int's to doubles.
        template<bool performCheck, typename U> class IsConvertibleToDouble;
        template<typename U> class IsConvertibleToDouble<false, U> {
        public:
            static const bool value = false;
        };

        template<typename U> class IsConvertibleToDouble<true, U> {
            typedef char YesType;
            struct NoType {
                char padding[8];
            };

            static YesType floatCheck(long double);
            static NoType floatCheck(...);
            static T& t;
        public:
            static const bool value = sizeof(floatCheck(t)) == sizeof(YesType);
        };

    public:
        static const bool value = IsInteger<T>::value || IsConvertibleToDouble<!IsInteger<T>::value, T>::value;
    };


    template <class T> struct IsArray {
        static const bool value = false;
    };

    template <class T> struct IsArray<T[]> {
        static const bool value = true;
    };

    template <class T, size_t N> struct IsArray<T[N]> {
        static const bool value = true;
    };


    template <typename T, typename U> struct IsSameType {
        static const bool value = false;
    };

    template <typename T> struct IsSameType<T, T> {
        static const bool value = true;
    };

    template <typename T, typename U> class IsSubclass {
        typedef char YesType;
        struct NoType {
            char padding[8];
        };

        static YesType subclassCheck(U*);
        static NoType subclassCheck(...);
        static T* t;
    public:
        static const bool value = sizeof(subclassCheck(t)) == sizeof(YesType);
    };

    template <typename T, template<class V> class U> class IsSubclassOfTemplate {
        typedef char YesType;
        struct NoType {
            char padding[8];
        };

        template<typename W> static YesType subclassCheck(U<W>*);
        static NoType subclassCheck(...);
        static T* t;
    public:
        static const bool value = sizeof(subclassCheck(t)) == sizeof(YesType);
    };

    template <typename T, template <class V> class OuterTemplate> struct RemoveTemplate {
        typedef T Type;
    };

    template <typename T, template <class V> class OuterTemplate> struct RemoveTemplate<OuterTemplate<T>, OuterTemplate> {
        typedef T Type;
    };

    template <typename T> struct RemoveConst {
        typedef T Type;
    };

    template <typename T> struct RemoveConst<const T> {
        typedef T Type;
    };

    template <typename T> struct RemoveVolatile {
        typedef T Type;
    };

    template <typename T> struct RemoveVolatile<volatile T> {
        typedef T Type;
    };

    template <typename T> struct RemoveConstVolatile {
        typedef typename RemoveVolatile<typename RemoveConst<T>::Type>::Type Type;
    };

    template <typename T> struct RemovePointer {
        typedef T Type;
    };

    template <typename T> struct RemovePointer<T*> {
        typedef T Type;
    };

    template <typename T> struct RemoveReference {
        typedef T Type;
    };

    template <typename T> struct RemoveReference<T&> {
        typedef T Type;
    };

    template <typename T> struct RemoveExtent {
        typedef T Type;
    };

    template <typename T> struct RemoveExtent<T[]> {
        typedef T Type;
    };

    template <typename T, size_t N> struct RemoveExtent<T[N]> {
        typedef T Type;
    };

    template <class T> struct DecayArray {
        typedef typename RemoveReference<T>::Type U;
    public:
        typedef typename Conditional<
            IsArray<U>::value,
            typename RemoveExtent<U>::Type*,
            typename RemoveConstVolatile<U>::Type
        >::Type Type;
    };

#if (defined(__GLIBCXX__) && (__GLIBCXX__ >= 20070724) && defined(__GXX_EXPERIMENTAL_CXX0X__)) || (defined(_MSC_VER) && (_MSC_VER >= 1600))

    // GCC's libstdc++ 20070724 and later supports C++ TR1 type_traits in the std namespace.
    // VC10 (VS2010) and later support C++ TR1 type_traits in the std::tr1 namespace.
    template<typename T> struct HasTrivialConstructor : public std::tr1::has_trivial_constructor<T> { };
    template<typename T> struct HasTrivialDestructor : public std::tr1::has_trivial_destructor<T> { };

#else

    // This compiler doesn't provide type traits, so we provide basic HasTrivialConstructor
    // and HasTrivialDestructor definitions. The definitions here include most built-in
    // scalar types but do not include POD structs and classes. For the intended purposes of
    // type_traits this results correct but potentially less efficient code.
    template <typename T, T v>
    struct IntegralConstant {
        static const T value = v;
        typedef T value_type;
        typedef IntegralConstant<T, v> type;
    };

    typedef IntegralConstant<bool, true>  true_type;
    typedef IntegralConstant<bool, false> false_type;

#if defined(_MSC_VER) && (_MSC_VER >= 1400) && !defined(__INTEL_COMPILER)
    // VC8 (VS2005) and later have built-in compiler support for HasTrivialConstructor / HasTrivialDestructor,
    // but for some unexplained reason it doesn't work on built-in types.
    template <typename T> struct HasTrivialConstructor : public IntegralConstant<bool, __has_trivial_constructor(T)>{ };
    template <typename T> struct HasTrivialDestructor : public IntegralConstant<bool, __has_trivial_destructor(T)>{ };
#else
    template <typename T> struct HasTrivialConstructor : public false_type{ };
    template <typename T> struct HasTrivialDestructor : public false_type{ };
#endif

    template <typename T> struct HasTrivialConstructor<T*> : public true_type{ };
    template <typename T> struct HasTrivialDestructor<T*> : public true_type{ };

    template <> struct HasTrivialConstructor<float> : public true_type{ };
    template <> struct HasTrivialConstructor<const float> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile float> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile float> : public true_type{ };

    template <> struct HasTrivialConstructor<double> : public true_type{ };
    template <> struct HasTrivialConstructor<const double> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile double> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile double> : public true_type{ };

    template <> struct HasTrivialConstructor<long double> : public true_type{ };
    template <> struct HasTrivialConstructor<const long double> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile long double> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile long double> : public true_type{ };

    template <> struct HasTrivialConstructor<unsigned char> : public true_type{ };
    template <> struct HasTrivialConstructor<const unsigned char> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile unsigned char> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile unsigned char> : public true_type{ };

    template <> struct HasTrivialConstructor<unsigned short> : public true_type{ };
    template <> struct HasTrivialConstructor<const unsigned short> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile unsigned short> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile unsigned short> : public true_type{ };

    template <> struct HasTrivialConstructor<unsigned int> : public true_type{ };
    template <> struct HasTrivialConstructor<const unsigned int> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile unsigned int> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile unsigned int> : public true_type{ };

    template <> struct HasTrivialConstructor<unsigned long> : public true_type{ };
    template <> struct HasTrivialConstructor<const unsigned long> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile unsigned long> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile unsigned long> : public true_type{ };

    template <> struct HasTrivialConstructor<unsigned long long> : public true_type{ };
    template <> struct HasTrivialConstructor<const unsigned long long> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile unsigned long long> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile unsigned long long> : public true_type{ };

    template <> struct HasTrivialConstructor<signed char> : public true_type{ };
    template <> struct HasTrivialConstructor<const signed char> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile signed char> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile signed char> : public true_type{ };

    template <> struct HasTrivialConstructor<signed short> : public true_type{ };
    template <> struct HasTrivialConstructor<const signed short> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile signed short> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile signed short> : public true_type{ };

    template <> struct HasTrivialConstructor<signed int> : public true_type{ };
    template <> struct HasTrivialConstructor<const signed int> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile signed int> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile signed int> : public true_type{ };

    template <> struct HasTrivialConstructor<signed long> : public true_type{ };
    template <> struct HasTrivialConstructor<const signed long> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile signed long> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile signed long> : public true_type{ };

    template <> struct HasTrivialConstructor<signed long long> : public true_type{ };
    template <> struct HasTrivialConstructor<const signed long long> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile signed long long> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile signed long long> : public true_type{ };

    template <> struct HasTrivialConstructor<bool> : public true_type{ };
    template <> struct HasTrivialConstructor<const bool> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile bool> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile bool> : public true_type{ };

    template <> struct HasTrivialConstructor<char> : public true_type{ };
    template <> struct HasTrivialConstructor<const char> : public true_type{ };
    template <> struct HasTrivialConstructor<volatile char> : public true_type{ };
    template <> struct HasTrivialConstructor<const volatile char> : public true_type{ };

    #if !defined(_MSC_VER) || defined(_NATIVE_WCHAR_T_DEFINED)
        template <> struct HasTrivialConstructor<wchar_t> : public true_type{ };
        template <> struct HasTrivialConstructor<const wchar_t> : public true_type{ };
        template <> struct HasTrivialConstructor<volatile wchar_t> : public true_type{ };
        template <> struct HasTrivialConstructor<const volatile wchar_t> : public true_type{ };
    #endif

    template <> struct HasTrivialDestructor<float> : public true_type{ };
    template <> struct HasTrivialDestructor<const float> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile float> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile float> : public true_type{ };

    template <> struct HasTrivialDestructor<double> : public true_type{ };
    template <> struct HasTrivialDestructor<const double> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile double> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile double> : public true_type{ };

    template <> struct HasTrivialDestructor<long double> : public true_type{ };
    template <> struct HasTrivialDestructor<const long double> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile long double> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile long double> : public true_type{ };

    template <> struct HasTrivialDestructor<unsigned char> : public true_type{ };
    template <> struct HasTrivialDestructor<const unsigned char> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile unsigned char> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile unsigned char> : public true_type{ };

    template <> struct HasTrivialDestructor<unsigned short> : public true_type{ };
    template <> struct HasTrivialDestructor<const unsigned short> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile unsigned short> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile unsigned short> : public true_type{ };

    template <> struct HasTrivialDestructor<unsigned int> : public true_type{ };
    template <> struct HasTrivialDestructor<const unsigned int> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile unsigned int> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile unsigned int> : public true_type{ };

    template <> struct HasTrivialDestructor<unsigned long> : public true_type{ };
    template <> struct HasTrivialDestructor<const unsigned long> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile unsigned long> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile unsigned long> : public true_type{ };

    template <> struct HasTrivialDestructor<unsigned long long> : public true_type{ };
    template <> struct HasTrivialDestructor<const unsigned long long> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile unsigned long long> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile unsigned long long> : public true_type{ };

    template <> struct HasTrivialDestructor<signed char> : public true_type{ };
    template <> struct HasTrivialDestructor<const signed char> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile signed char> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile signed char> : public true_type{ };

    template <> struct HasTrivialDestructor<signed short> : public true_type{ };
    template <> struct HasTrivialDestructor<const signed short> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile signed short> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile signed short> : public true_type{ };

    template <> struct HasTrivialDestructor<signed int> : public true_type{ };
    template <> struct HasTrivialDestructor<const signed int> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile signed int> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile signed int> : public true_type{ };

    template <> struct HasTrivialDestructor<signed long> : public true_type{ };
    template <> struct HasTrivialDestructor<const signed long> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile signed long> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile signed long> : public true_type{ };

    template <> struct HasTrivialDestructor<signed long long> : public true_type{ };
    template <> struct HasTrivialDestructor<const signed long long> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile signed long long> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile signed long long> : public true_type{ };

    template <> struct HasTrivialDestructor<bool> : public true_type{ };
    template <> struct HasTrivialDestructor<const bool> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile bool> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile bool> : public true_type{ };

    template <> struct HasTrivialDestructor<char> : public true_type{ };
    template <> struct HasTrivialDestructor<const char> : public true_type{ };
    template <> struct HasTrivialDestructor<volatile char> : public true_type{ };
    template <> struct HasTrivialDestructor<const volatile char> : public true_type{ };

    #if !defined(_MSC_VER) || defined(_NATIVE_WCHAR_T_DEFINED)
        template <> struct HasTrivialDestructor<wchar_t> : public true_type{ };
        template <> struct HasTrivialDestructor<const wchar_t> : public true_type{ };
        template <> struct HasTrivialDestructor<volatile wchar_t> : public true_type{ };
        template <> struct HasTrivialDestructor<const volatile wchar_t> : public true_type{ };
    #endif

#endif  // __GLIBCXX__, etc.

} // namespace WTF

#endif // TypeTraits_h
