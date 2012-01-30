/*
 * Copyright (c) 2008, 2011 Google Inc.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ScriptState_h
#define ScriptState_h

#include <heap/Strong.h>
#include <wtf/Noncopyable.h>

namespace JSC {
class ExecState;
class JSGlobalObject;
}

namespace WebCore {
class DOMWindow;
class DOMWrapperWorld;
class Frame;
class Node;
class Page;
class WorkerContext;

// The idea is to expose "state-like" methods (hadException, and any other
// methods where ExecState just dips into globalData) of JSC::ExecState as a
// separate abstraction.
// For now, the separation is purely by convention.
typedef JSC::ExecState ScriptState;

class ScriptStateProtectedPtr {
    WTF_MAKE_NONCOPYABLE(ScriptStateProtectedPtr);
public:
    explicit ScriptStateProtectedPtr(ScriptState*);
    ~ScriptStateProtectedPtr();
    ScriptState* get() const;
private:
    JSC::Strong<JSC::JSGlobalObject> m_globalObject;
};

DOMWindow* domWindowFromScriptState(ScriptState*);

ScriptState* mainWorldScriptState(Frame*);

ScriptState* scriptStateFromNode(DOMWrapperWorld*, Node*);
ScriptState* scriptStateFromPage(DOMWrapperWorld*, Page*);

#if ENABLE(WORKERS)
ScriptState* scriptStateFromWorkerContext(WorkerContext*);
#endif

} // namespace WebCore

#endif // ScriptState_h
