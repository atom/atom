/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
#ifndef DebuggerCallFrame_h
#define DebuggerCallFrame_h

#include "CallFrame.h"

namespace JSC {
    
    class DebuggerCallFrame {
    public:
        enum Type { ProgramType, FunctionType };

        DebuggerCallFrame(CallFrame* callFrame)
            : m_callFrame(callFrame)
        {
        }

        DebuggerCallFrame(CallFrame* callFrame, JSValue exception)
            : m_callFrame(callFrame)
            , m_exception(exception)
        {
        }

        JSGlobalObject* dynamicGlobalObject() const { return m_callFrame->dynamicGlobalObject(); }
        ScopeChainNode* scopeChain() const { return m_callFrame->scopeChain(); }
        JS_EXPORT_PRIVATE const UString* functionName() const;
        JS_EXPORT_PRIVATE UString calculatedFunctionName() const;
        JS_EXPORT_PRIVATE Type type() const;
        JS_EXPORT_PRIVATE JSObject* thisObject() const;
        JS_EXPORT_PRIVATE JSValue evaluate(const UString&, JSValue& exception) const;
        JSValue exception() const { return m_exception; }

    private:
        CallFrame* m_callFrame;
        JSValue m_exception;
    };

} // namespace JSC

#endif // DebuggerCallFrame_h
