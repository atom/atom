/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2011 Nokia Corporation and/or its subsidiary(-ies).
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

#ifndef ASCIIFastPath_h
#define ASCIIFastPath_h

#include <stdint.h>
#include <wtf/unicode/Unicode.h>

namespace WTF {

// Assuming that a pointer is the size of a "machine word", then
// uintptr_t is an integer type that is also a machine word.
typedef uintptr_t MachineWord;
const uintptr_t machineWordAlignmentMask = sizeof(MachineWord) - 1;

inline bool isAlignedToMachineWord(const void* pointer)
{
    return !(reinterpret_cast<uintptr_t>(pointer) & machineWordAlignmentMask);
}

template<typename T> inline T* alignToMachineWord(T* pointer)
{
    return reinterpret_cast<T*>(reinterpret_cast<uintptr_t>(pointer) & ~machineWordAlignmentMask);
}

template<size_t size, typename CharacterType> struct NonASCIIMask;
template<> struct NonASCIIMask<4, UChar> {
    static inline uint32_t value() { return 0xFF80FF80U; }
};
template<> struct NonASCIIMask<4, LChar> {
    static inline uint32_t value() { return 0x80808080U; }
};
template<> struct NonASCIIMask<8, UChar> {
    static inline uint64_t value() { return 0xFF80FF80FF80FF80ULL; }
};
template<> struct NonASCIIMask<8, LChar> {
    static inline uint64_t value() { return 0x8080808080808080ULL; }
};


template<typename CharacterType>
inline bool isAllASCII(MachineWord word)
{
    return !(word & NonASCIIMask<sizeof(MachineWord), CharacterType>::value());
}

// Note: This function assume the input is likely all ASCII, and
// does not leave early if it is not the case.
template<typename CharacterType>
inline bool charactersAreAllASCII(const CharacterType* characters, size_t length)
{
    MachineWord allCharBits = 0;
    const CharacterType* end = characters + length;

    // Prologue: align the input.
    while (!isAlignedToMachineWord(characters) && characters != end) {
        allCharBits |= *characters;
        ++characters;
    }

    // Compare the values of CPU word size.
    const CharacterType* wordEnd = alignToMachineWord(end);
    const size_t loopIncrement = sizeof(MachineWord) / sizeof(CharacterType);
    while (characters < wordEnd) {
        allCharBits |= *(reinterpret_cast<const MachineWord*>(characters));
        characters += loopIncrement;
    }

    // Process the remaining bytes.
    while (characters != end) {
        allCharBits |= *characters;
        ++characters;
    }

    MachineWord nonASCIIBitMask = NonASCIIMask<sizeof(MachineWord), CharacterType>::value();
    return !(allCharBits & nonASCIIBitMask);
}


} // namespace WTF

#endif // ASCIIFastPath_h
