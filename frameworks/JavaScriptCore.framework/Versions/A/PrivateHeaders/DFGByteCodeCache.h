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

#ifndef DFGByteCodeCache_h
#define DFGByteCodeCache_h

#include <wtf/Platform.h>

#if ENABLE(DFG_JIT)

#include "CodeBlock.h"
#include "Executable.h"
#include "JSFunction.h"
#include <wtf/HashMap.h>

namespace JSC { namespace DFG {

class CodeBlockKey {
public:
    CodeBlockKey()
        : m_executable(0)
        , m_kind(CodeForCall) // CodeForCall = empty value
    {
    }
    
    CodeBlockKey(WTF::HashTableDeletedValueType)
        : m_executable(0)
        , m_kind(CodeForConstruct) // CodeForConstruct = deleted value
    {
    }
    
    CodeBlockKey(FunctionExecutable* executable, CodeSpecializationKind kind)
        : m_executable(executable)
        , m_kind(kind)
    {
    }
    
    bool operator==(const CodeBlockKey& other) const
    {
        return m_executable == other.m_executable
            && m_kind == other.m_kind;
    }
    
    unsigned hash() const
    {
        return WTF::PtrHash<FunctionExecutable*>::hash(m_executable) ^ static_cast<unsigned>(m_kind);
    }
    
    FunctionExecutable* executable() const { return m_executable; }
    CodeSpecializationKind kind() const { return m_kind; }

    bool isHashTableDeletedValue() const
    {
        return !m_executable && m_kind == CodeForConstruct;
    }

private:
    FunctionExecutable* m_executable;
    CodeSpecializationKind m_kind;
};

struct CodeBlockKeyHash {
    static unsigned hash(const CodeBlockKey& key) { return key.hash(); }
    static bool equal(const CodeBlockKey& a, const CodeBlockKey& b) { return a == b; }
    
    static const bool safeToCompareToEmptyOrDeleted = true;
};

} } // namespace JSC::DFG

namespace WTF {

template<typename T> struct DefaultHash;
template<> struct DefaultHash<JSC::DFG::CodeBlockKey> {
    typedef JSC::DFG::CodeBlockKeyHash Hash;
};

template<typename T> struct HashTraits;
template<> struct HashTraits<JSC::DFG::CodeBlockKey> : SimpleClassHashTraits<JSC::DFG::CodeBlockKey> { };

} // namespace WTF

namespace JSC { namespace DFG {

struct ByteCodeCacheValue {
    FunctionCodeBlock* codeBlock;
    bool owned;
    bool oldValueOfShouldDiscardBytecode;
    
    // All uses of this struct initialize everything manually. But gcc isn't
    // smart enough to see that, so this constructor is just here to make the
    // compiler happy.
    ByteCodeCacheValue()
        : codeBlock(0)
        , owned(false)
        , oldValueOfShouldDiscardBytecode(false)
    {
    }
};

template<bool (*filterFunction)(CodeBlock*, CodeSpecializationKind)>
class ByteCodeCache {
public:
    typedef HashMap<CodeBlockKey, ByteCodeCacheValue> Map;
    
    ByteCodeCache() { }
    
    ~ByteCodeCache()
    {
        Map::iterator begin = m_map.begin();
        Map::iterator end = m_map.end();
        for (Map::iterator iter = begin; iter != end; ++iter) {
            if (!iter->second.codeBlock)
                continue;
            if (iter->second.owned) {
                delete iter->second.codeBlock;
                continue;
            }
            iter->second.codeBlock->m_shouldDiscardBytecode = iter->second.oldValueOfShouldDiscardBytecode;
        }
    }
    
    CodeBlock* get(const CodeBlockKey& key, ScopeChainNode* scope)
    {
        Map::iterator iter = m_map.find(key);
        if (iter != m_map.end())
            return iter->second.codeBlock;
        
        ByteCodeCacheValue value;
        
        // First see if there is already a parsed code block that still has some
        // bytecode in it.
        value.codeBlock = key.executable()->codeBlockWithBytecodeFor(key.kind());
        if (value.codeBlock) {
            value.owned = false;
            value.oldValueOfShouldDiscardBytecode = value.codeBlock->m_shouldDiscardBytecode;
        } else {
            // Nope, so try to parse one.
            JSObject* exception;
            value.owned = true;
            value.codeBlock = key.executable()->produceCodeBlockFor(scope, OptimizingCompilation, key.kind(), exception).leakPtr();
        }
        
        // Check if there is any reason to reject this from our cache. If so, then
        // poison it.
        if (!!value.codeBlock && !filterFunction(value.codeBlock, key.kind())) {
            if (value.owned)
                delete value.codeBlock;
            value.codeBlock = 0;
        }
        
        // If we're about to return a code block, make sure that we're not going
        // to be discarding its bytecode if a GC were to happen during DFG
        // compilation. That's unlikely, but it's good to thoroughly enjoy this
        // kind of paranoia.
        if (!!value.codeBlock)
            value.codeBlock->m_shouldDiscardBytecode = false;
        
        m_map.add(key, value);
        
        return value.codeBlock;
    }

private:
    Map m_map;
};

} } // namespace JSC::DFG

#endif // ENABLE(DFG_JIT)

#endif // DFGByteCodeCache_h
