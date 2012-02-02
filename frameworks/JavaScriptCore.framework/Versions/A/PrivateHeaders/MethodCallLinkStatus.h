/*
 * Copyright (C) 2012 Apple Inc. All rights reserved.
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

#ifndef MethodCallLinkStatus_h
#define MethodCallLinkStatus_h

namespace JSC {

class CodeBlock;
class JSObject;
class Structure;

class MethodCallLinkStatus {
public:
    MethodCallLinkStatus()
        : m_structure(0)
        , m_prototypeStructure(0)
        , m_function(0)
        , m_prototype(0)
    {
    }
    
    MethodCallLinkStatus(
        Structure* structure,
        Structure* prototypeStructure,
        JSObject* function,
        JSObject* prototype)
        : m_structure(structure)
        , m_prototypeStructure(prototypeStructure)
        , m_function(function)
        , m_prototype(prototype)
    {
        if (!m_function) {
            ASSERT(!m_structure);
            ASSERT(!m_prototypeStructure);
            ASSERT(!m_prototype);
        } else
            ASSERT(m_structure);
        
        ASSERT(!m_prototype == !m_prototypeStructure);
    }
    
    static MethodCallLinkStatus computeFor(CodeBlock*, unsigned bytecodeIndex);

    bool isSet() const { return !!m_function; }
    bool operator!() const { return !m_function; }
    
    bool needsPrototypeCheck() const { return !!m_prototype; }
    
    Structure* structure() { return m_structure; }
    Structure* prototypeStructure() { return m_prototypeStructure; }
    JSObject* function() const { return m_function; }
    JSObject* prototype() const { return m_prototype; }
    
private:
    Structure* m_structure;
    Structure* m_prototypeStructure;
    JSObject* m_function;
    JSObject* m_prototype;
};

} // namespace JSC

#endif // MethodCallLinkStatus_h

