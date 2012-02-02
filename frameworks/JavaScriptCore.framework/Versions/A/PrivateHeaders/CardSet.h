/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef CardSet_h
#define CardSet_h

#include <stdint.h>
#include <wtf/Assertions.h>
#include <wtf/Noncopyable.h>

namespace JSC {

template <size_t cardSize, size_t blockSize> class CardSet {
    WTF_MAKE_NONCOPYABLE(CardSet);

public:
    static const size_t cardCount = (blockSize + cardSize - 1) / cardSize;

    CardSet()
    {
        memset(m_cards, 0, cardCount);
    }

    bool isCardMarkedForAtom(const void*);
    void markCardForAtom(const void*);
    uint8_t& cardForAtom(const void*);
    bool isCardMarked(size_t);
    bool testAndClear(size_t);

private:
    uint8_t m_cards[cardCount];
    COMPILE_ASSERT(!(cardSize & (cardSize - 1)), cardSet_cardSize_is_power_of_two);
    COMPILE_ASSERT(!(cardCount & (cardCount - 1)), cardSet_cardCount_is_power_of_two);
};

template <size_t cardSize, size_t blockSize> uint8_t& CardSet<cardSize, blockSize>::cardForAtom(const void* ptr)
{
    ASSERT(ptr > this && ptr < (reinterpret_cast<char*>(this) + cardCount * cardSize));
    uintptr_t card = (reinterpret_cast<uintptr_t>(ptr) / cardSize) % cardCount;
    return m_cards[card];
}

template <size_t cardSize, size_t blockSize> bool CardSet<cardSize, blockSize>::isCardMarkedForAtom(const void* ptr)
{
    return cardForAtom(ptr);
}

template <size_t cardSize, size_t blockSize> void CardSet<cardSize, blockSize>::markCardForAtom(const void* ptr)
{
    cardForAtom(ptr) = 1;
}

template <size_t cardSize, size_t blockSize> bool CardSet<cardSize, blockSize>::isCardMarked(size_t i)
{
    ASSERT(i < cardCount);
    return m_cards[i];
}

template <size_t cardSize, size_t blockSize> bool CardSet<cardSize, blockSize>::testAndClear(size_t i)
{
    ASSERT(i < cardCount);
    bool result = m_cards[i];
    m_cards[i] = 0;
    return result;
}

}

#endif
