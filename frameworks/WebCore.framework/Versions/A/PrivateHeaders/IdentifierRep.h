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

#ifndef IdentifierRep_h
#define IdentifierRep_h

#include <wtf/Assertions.h>
#include <wtf/FastAllocBase.h>
#include <wtf/StringExtras.h>
#include <string.h>

namespace WebCore {
    
class IdentifierRep {
    WTF_MAKE_FAST_ALLOCATED;
public:
    static IdentifierRep* get(int);
    static IdentifierRep* get(const char*);

    static bool isValid(IdentifierRep*);
    
    bool isString() const { return m_isString; }

    int number() const { return m_isString ? 0 : m_value.m_number; }
    const char* string() const { return m_isString ? m_value.m_string : 0; }

private:
    IdentifierRep(int number) 
        : m_isString(false)
    {
        m_value.m_number = number;
    }
    
    IdentifierRep(const char* name)
        : m_isString(true)
    {
        m_value.m_string = fastStrDup(name);
    }
    
    ~IdentifierRep(); // Not implemented
    
    union {
        const char* m_string;
        int m_number;
    } m_value;
    bool m_isString;
};

} // namespace WebCore

#endif // IdentifierRep_h
