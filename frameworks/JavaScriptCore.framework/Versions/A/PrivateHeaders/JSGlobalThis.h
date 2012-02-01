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

#ifndef JSGlobalThis_h
#define JSGlobalThis_h

#include "JSObject.h"

namespace JSC {

class JSGlobalThis : public JSNonFinalObject {
public:
    typedef JSNonFinalObject Base;

    static JSGlobalThis* create(JSGlobalData& globalData, Structure* structure)
    {
        JSGlobalThis* globalThis = new (NotNull, allocateCell<JSGlobalThis>(globalData.heap)) JSGlobalThis(globalData, structure);
        globalThis->finishCreation(globalData);
        return globalThis;
    }

    static Structure* createStructure(JSGlobalData& globalData, JSValue prototype) 
    {
        return Structure::create(globalData, 0, prototype, TypeInfo(GlobalThisType, StructureFlags), &s_info); 
    }

    static JS_EXPORTDATA const JSC::ClassInfo s_info;

    JSGlobalObject* unwrappedObject();

protected:
    JSGlobalThis(JSGlobalData& globalData, Structure* structure)
        : JSNonFinalObject(globalData, structure)
    {
    }

    void finishCreation(JSGlobalData& globalData)
    {
        Base::finishCreation(globalData);
    }

    static const unsigned StructureFlags = OverridesVisitChildren | Base::StructureFlags;

    JS_EXPORT_PRIVATE static void visitChildren(JSCell*, SlotVisitor&);

    WriteBarrier<JSGlobalObject> m_unwrappedObject;
};

} // namespace JSC

#endif // JSGlobalThis_h
