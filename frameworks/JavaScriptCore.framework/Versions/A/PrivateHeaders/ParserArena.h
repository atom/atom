/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef ParserArena_h
#define ParserArena_h

#include "Identifier.h"
#include <wtf/SegmentedVector.h>

namespace JSC {

    class ParserArenaDeletable;
    class ParserArenaRefCounted;

    class IdentifierArena {
        WTF_MAKE_FAST_ALLOCATED;
    public:
        IdentifierArena()
        {
            clear();
        }

        template <typename T>
        ALWAYS_INLINE const Identifier& makeIdentifier(JSGlobalData*, const T* characters, size_t length);
        ALWAYS_INLINE const Identifier& makeIdentifierLCharFromUChar(JSGlobalData*, const UChar* characters, size_t length);

        const Identifier& makeNumericIdentifier(JSGlobalData*, double number);

        bool isEmpty() const { return m_identifiers.isEmpty(); }

    public:
        static const int MaximumCachableCharacter = 128;
        typedef SegmentedVector<Identifier, 64> IdentifierVector;
        void clear()
        {
            m_identifiers.clear();
            for (int i = 0; i < MaximumCachableCharacter; i++)
                m_shortIdentifiers[i] = 0;
            for (int i = 0; i < MaximumCachableCharacter; i++)
                m_recentIdentifiers[i] = 0;
        }

    private:
        IdentifierVector m_identifiers;
        FixedArray<Identifier*, MaximumCachableCharacter> m_shortIdentifiers;
        FixedArray<Identifier*, MaximumCachableCharacter> m_recentIdentifiers;
    };

    template <typename T>
    ALWAYS_INLINE const Identifier& IdentifierArena::makeIdentifier(JSGlobalData* globalData, const T* characters, size_t length)
    {
        if (characters[0] >= MaximumCachableCharacter) {
            m_identifiers.append(Identifier(globalData, characters, length));
            return m_identifiers.last();
        }
        if (length == 1) {
            if (Identifier* ident = m_shortIdentifiers[characters[0]])
                return *ident;
            m_identifiers.append(Identifier(globalData, characters, length));
            m_shortIdentifiers[characters[0]] = &m_identifiers.last();
            return m_identifiers.last();
        }
        Identifier* ident = m_recentIdentifiers[characters[0]];
        if (ident && Identifier::equal(ident->impl(), characters, length))
            return *ident;
        m_identifiers.append(Identifier(globalData, characters, length));
        m_recentIdentifiers[characters[0]] = &m_identifiers.last();
        return m_identifiers.last();
    }

    ALWAYS_INLINE const Identifier& IdentifierArena::makeIdentifierLCharFromUChar(JSGlobalData* globalData, const UChar* characters, size_t length)
    {
        if (characters[0] >= MaximumCachableCharacter) {
            m_identifiers.append(Identifier::createLCharFromUChar(globalData, characters, length));
            return m_identifiers.last();
        }
        if (length == 1) {
            if (Identifier* ident = m_shortIdentifiers[characters[0]])
                return *ident;
            m_identifiers.append(Identifier(globalData, characters, length));
            m_shortIdentifiers[characters[0]] = &m_identifiers.last();
            return m_identifiers.last();
        }
        Identifier* ident = m_recentIdentifiers[characters[0]];
        if (ident && Identifier::equal(ident->impl(), characters, length))
            return *ident;
        m_identifiers.append(Identifier::createLCharFromUChar(globalData, characters, length));
        m_recentIdentifiers[characters[0]] = &m_identifiers.last();
        return m_identifiers.last();
    }
    
    inline const Identifier& IdentifierArena::makeNumericIdentifier(JSGlobalData* globalData, double number)
    {
        m_identifiers.append(Identifier(globalData, UString::number(number)));
        return m_identifiers.last();
    }

    class ParserArena {
        WTF_MAKE_NONCOPYABLE(ParserArena);
    public:
        ParserArena();
        ~ParserArena();

        void swap(ParserArena& otherArena)
        {
            std::swap(m_freeableMemory, otherArena.m_freeableMemory);
            std::swap(m_freeablePoolEnd, otherArena.m_freeablePoolEnd);
            m_identifierArena.swap(otherArena.m_identifierArena);
            m_freeablePools.swap(otherArena.m_freeablePools);
            m_deletableObjects.swap(otherArena.m_deletableObjects);
            m_refCountedObjects.swap(otherArena.m_refCountedObjects);
        }

        void* allocateFreeable(size_t size)
        {
            ASSERT(size);
            ASSERT(size <= freeablePoolSize);
            size_t alignedSize = alignSize(size);
            ASSERT(alignedSize <= freeablePoolSize);
            if (UNLIKELY(static_cast<size_t>(m_freeablePoolEnd - m_freeableMemory) < alignedSize))
                allocateFreeablePool();
            void* block = m_freeableMemory;
            m_freeableMemory += alignedSize;
            return block;
        }

        void* allocateDeletable(size_t size)
        {
            ParserArenaDeletable* deletable = static_cast<ParserArenaDeletable*>(allocateFreeable(size));
            m_deletableObjects.append(deletable);
            return deletable;
        }

        void derefWithArena(PassRefPtr<ParserArenaRefCounted>);
        bool contains(ParserArenaRefCounted*) const;
        ParserArenaRefCounted* last() const;
        void removeLast();

        bool isEmpty() const;
        JS_EXPORT_PRIVATE void reset();

        IdentifierArena& identifierArena() { return *m_identifierArena; }

    private:
        static const size_t freeablePoolSize = 8000;

        static size_t alignSize(size_t size)
        {
            return (size + sizeof(WTF::AllocAlignmentInteger) - 1) & ~(sizeof(WTF::AllocAlignmentInteger) - 1);
        }

        void* freeablePool();
        void allocateFreeablePool();
        void deallocateObjects();

        char* m_freeableMemory;
        char* m_freeablePoolEnd;

        OwnPtr<IdentifierArena> m_identifierArena;
        Vector<void*> m_freeablePools;
        Vector<ParserArenaDeletable*> m_deletableObjects;
        Vector<RefPtr<ParserArenaRefCounted> > m_refCountedObjects;
    };

}

#endif
