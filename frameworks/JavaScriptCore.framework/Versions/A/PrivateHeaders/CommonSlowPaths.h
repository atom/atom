/*
 * Copyright (C) 2011, 2012 Apple Inc. All rights reserved.
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

#ifndef CommonSlowPaths_h
#define CommonSlowPaths_h

#include "CodeBlock.h"
#include "ExceptionHelpers.h"
#include "JSArray.h"

namespace JSC {

// The purpose of this namespace is to include slow paths that are shared
// between the interpreter and baseline JIT. They are written to be agnostic
// with respect to the slow-path calling convention, but they do rely on the
// JS code being executed more-or-less directly from bytecode (so the call
// frame layout is unmodified, making it potentially awkward to use these
// from any optimizing JIT, like the DFG).

namespace CommonSlowPaths {

ALWAYS_INLINE bool opInstanceOfSlow(ExecState* exec, JSValue value, JSValue baseVal, JSValue proto)
{
    ASSERT(!value.isCell() || !baseVal.isCell() || !proto.isCell()
           || !value.isObject() || !baseVal.isObject() || !proto.isObject() 
           || !asObject(baseVal)->structure()->typeInfo().implementsDefaultHasInstance());


    // ECMA-262 15.3.5.3:
    // Throw an exception either if baseVal is not an object, or if it does not implement 'HasInstance' (i.e. is a function).
    TypeInfo typeInfo(UnspecifiedType);
    if (!baseVal.isObject() || !(typeInfo = asObject(baseVal)->structure()->typeInfo()).implementsHasInstance()) {
        exec->globalData().exception = createInvalidParamError(exec, "instanceof", baseVal);
        return false;
    }
    ASSERT(typeInfo.type() != UnspecifiedType);

    if (!typeInfo.overridesHasInstance() && !value.isObject())
        return false;

    return asObject(baseVal)->methodTable()->hasInstance(asObject(baseVal), exec, value, proto);
}

inline bool opIn(ExecState* exec, JSValue propName, JSValue baseVal)
{
    if (!baseVal.isObject()) {
        exec->globalData().exception = createInvalidParamError(exec, "in", baseVal);
        return false;
    }

    JSObject* baseObj = asObject(baseVal);

    uint32_t i;
    if (propName.getUInt32(i))
        return baseObj->hasProperty(exec, i);

    Identifier property(exec, propName.toString(exec)->value(exec));
    if (exec->globalData().exception)
        return false;
    return baseObj->hasProperty(exec, property);
}

ALWAYS_INLINE JSValue opResolve(ExecState* exec, Identifier& ident)
{
    ScopeChainNode* scopeChain = exec->scopeChain();

    ScopeChainIterator iter = scopeChain->begin();
    ScopeChainIterator end = scopeChain->end();
    ASSERT(iter != end);
    
    do {
        JSObject* o = iter->get();
        PropertySlot slot(o);
        if (o->getPropertySlot(exec, ident, slot))
            return slot.getValue(exec, ident);
    } while (++iter != end);

    exec->globalData().exception = createUndefinedVariableError(exec, ident);
    return JSValue();
}

ALWAYS_INLINE JSValue opResolveSkip(ExecState* exec, Identifier& ident, int skip)
{
    ScopeChainNode* scopeChain = exec->scopeChain();

    ScopeChainIterator iter = scopeChain->begin();
    ScopeChainIterator end = scopeChain->end();
    ASSERT(iter != end);
    CodeBlock* codeBlock = exec->codeBlock();
    bool checkTopLevel = codeBlock->codeType() == FunctionCode && codeBlock->needsFullScopeChain();
    ASSERT(skip || !checkTopLevel);
    if (checkTopLevel && skip--) {
        if (exec->uncheckedR(codeBlock->activationRegister()).jsValue())
            ++iter;
    }
    while (skip--) {
        ++iter;
        ASSERT(iter != end);
    }
    do {
        JSObject* o = iter->get();
        PropertySlot slot(o);
        if (o->getPropertySlot(exec, ident, slot))
            return slot.getValue(exec, ident);
    } while (++iter != end);

    exec->globalData().exception = createUndefinedVariableError(exec, ident);
    return JSValue();
}

ALWAYS_INLINE JSValue opResolveWithBase(ExecState* exec, Identifier& ident, Register& baseSlot)
{
    ScopeChainNode* scopeChain = exec->scopeChain();

    ScopeChainIterator iter = scopeChain->begin();
    ScopeChainIterator end = scopeChain->end();

    // FIXME: add scopeDepthIsZero optimization

    ASSERT(iter != end);

    JSObject* base;
    do {
        base = iter->get();
        PropertySlot slot(base);
        if (base->getPropertySlot(exec, ident, slot)) {
            JSValue result = slot.getValue(exec, ident);
            if (exec->globalData().exception)
                return JSValue();

            baseSlot = JSValue(base);
            return result;
        }
        ++iter;
    } while (iter != end);

    exec->globalData().exception = createUndefinedVariableError(exec, ident);
    return JSValue();
}

ALWAYS_INLINE JSValue opResolveWithThis(ExecState* exec, Identifier& ident, Register& baseSlot)
{
    ScopeChainNode* scopeChain = exec->scopeChain();

    ScopeChainIterator iter = scopeChain->begin();
    ScopeChainIterator end = scopeChain->end();

    // FIXME: add scopeDepthIsZero optimization

    ASSERT(iter != end);

    JSObject* base;
    do {
        base = iter->get();
        ++iter;
        PropertySlot slot(base);
        if (base->getPropertySlot(exec, ident, slot)) {
            JSValue result = slot.getValue(exec, ident);
            if (exec->globalData().exception)
                return JSValue();

            // All entries on the scope chain should be EnvironmentRecords (activations etc),
            // other then 'with' object, which are directly referenced from the scope chain,
            // and the global object. If we hit either an EnvironmentRecord or a global
            // object at the end of the scope chain, this is undefined. If we hit a non-
            // EnvironmentRecord within the scope chain, pass the base as the this value.
            if (iter == end || base->structure()->typeInfo().isEnvironmentRecord())
                baseSlot = jsUndefined();
            else
                baseSlot = JSValue(base);
            return result;
        }
    } while (iter != end);

    exec->globalData().exception = createUndefinedVariableError(exec, ident);
    return JSValue();
}

} } // namespace JSC::CommonSlowPaths

#endif // CommonSlowPaths_h

