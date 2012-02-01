// -*- mode: c++; c-basic-offset: 4 -*-
/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef JSTypeInfo_h
#define JSTypeInfo_h

// This file would be called TypeInfo.h, but that conflicts with <typeinfo.h>
// in the STL on systems without case-sensitive file systems. 

#include "JSType.h"

namespace JSC {

    static const unsigned MasqueradesAsUndefined = 1; // WebCore uses MasqueradesAsUndefined to make document.all undetectable.
    static const unsigned ImplementsHasInstance = 1 << 1;
    static const unsigned OverridesHasInstance = 1 << 2;
    static const unsigned ImplementsDefaultHasInstance = 1 << 3;
    static const unsigned IsEnvironmentRecord = 1 << 4;
    static const unsigned OverridesGetOwnPropertySlot = 1 << 5;
    static const unsigned OverridesVisitChildren = 1 << 6;
    static const unsigned OverridesGetPropertyNames = 1 << 7;
    static const unsigned ProhibitsPropertyCaching = 1 << 8;

    class TypeInfo {
    public:
        TypeInfo(JSType type, unsigned flags = 0)
            : m_type(type)
            , m_flags(flags & 0xff)
            , m_flags2(flags >> 8)
        {
            ASSERT(flags <= 0x3ff);
            ASSERT(type <= 0xff);
            ASSERT(type >= CompoundType || !(flags & OverridesVisitChildren));
            // No object that doesn't ImplementsHasInstance should override it!
            ASSERT((m_flags & (ImplementsHasInstance | OverridesHasInstance)) != OverridesHasInstance);
            // ImplementsDefaultHasInstance means (ImplementsHasInstance & !OverridesHasInstance)
            if ((m_flags & (ImplementsHasInstance | OverridesHasInstance)) == ImplementsHasInstance)
                m_flags |= ImplementsDefaultHasInstance;
        }

        JSType type() const { return static_cast<JSType>(m_type); }
        bool isObject() const { return type() >= ObjectType; }
        bool isFinalObject() const { return type() == FinalObjectType; }
        bool isNumberObject() const { return type() == NumberObjectType; }

        bool masqueradesAsUndefined() const { return isSetOnFlags1(MasqueradesAsUndefined); }
        bool implementsHasInstance() const { return isSetOnFlags1(ImplementsHasInstance); }
        bool isEnvironmentRecord() const { return isSetOnFlags1(IsEnvironmentRecord); }
        bool overridesHasInstance() const { return isSetOnFlags1(OverridesHasInstance); }
        bool implementsDefaultHasInstance() const { return isSetOnFlags1(ImplementsDefaultHasInstance); }
        bool overridesGetOwnPropertySlot() const { return isSetOnFlags1(OverridesGetOwnPropertySlot); }
        bool overridesVisitChildren() const { return isSetOnFlags1(OverridesVisitChildren); }
        bool overridesGetPropertyNames() const { return isSetOnFlags1(OverridesGetPropertyNames); }
        bool prohibitsPropertyCaching() const { return isSetOnFlags2(ProhibitsPropertyCaching); }

        static ptrdiff_t flagsOffset()
        {
            return OBJECT_OFFSETOF(TypeInfo, m_flags);
        }

        static ptrdiff_t typeOffset()
        {
            return OBJECT_OFFSETOF(TypeInfo, m_type);
        }

    private:
        bool isSetOnFlags1(unsigned flag) const { ASSERT(flag <= (1 << 7)); return m_flags & flag; }
        bool isSetOnFlags2(unsigned flag) const { ASSERT(flag >= (1 << 8)); return m_flags2 & (flag >> 8); }

        unsigned char m_type;
        unsigned char m_flags;
        unsigned char m_flags2;
    };

}

#endif // JSTypeInfo_h
