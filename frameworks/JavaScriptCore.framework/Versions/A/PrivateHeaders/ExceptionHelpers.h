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

#ifndef ExceptionHelpers_h
#define ExceptionHelpers_h

#include "JSObject.h"

namespace JSC {

JS_EXPORT_PRIVATE JSObject* createInterruptedExecutionException(JSGlobalData*);
bool isInterruptedExecutionException(JSObject*);
bool isInterruptedExecutionException(JSValue);

JSObject* createTerminatedExecutionException(JSGlobalData*);
bool isTerminatedExecutionException(JSObject*);
JS_EXPORT_PRIVATE bool isTerminatedExecutionException(JSValue);

JS_EXPORT_PRIVATE JSObject* createStackOverflowError(ExecState*);
JSObject* createStackOverflowError(JSGlobalObject*);
JSObject* createOutOfMemoryError(JSGlobalObject*);
JSObject* createUndefinedVariableError(ExecState*, const Identifier&);
JSObject* createNotAnObjectError(ExecState*, JSValue);
JSObject* createInvalidParamError(ExecState*, const char* op, JSValue);
JSObject* createNotAConstructorError(ExecState*, JSValue);
JSObject* createNotAFunctionError(ExecState*, JSValue);
JSObject* createErrorForInvalidGlobalAssignment(ExecState*, const UString&);

JSObject* throwOutOfMemoryError(ExecState*);
JSObject* throwStackOverflowError(ExecState*);


class InterruptedExecutionError : public JSNonFinalObject {
private:
    InterruptedExecutionError(JSGlobalData& globalData)
        : JSNonFinalObject(globalData, globalData.interruptedExecutionErrorStructure.get())
    {
    }

    static JSValue defaultValue(const JSObject*, ExecState*, PreferredPrimitiveType);

public:
    typedef JSNonFinalObject Base;

    static InterruptedExecutionError* create(JSGlobalData& globalData)
    {
        InterruptedExecutionError* error = new (NotNull, allocateCell<InterruptedExecutionError>(globalData.heap)) InterruptedExecutionError(globalData);
        error->finishCreation(globalData);
        return error;
    }

    static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
    {
        return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
    }

    static JS_EXPORTDATA const ClassInfo s_info;
};

class TerminatedExecutionError : public JSNonFinalObject {
private:
    TerminatedExecutionError(JSGlobalData& globalData)
        : JSNonFinalObject(globalData, globalData.terminatedExecutionErrorStructure.get())
    {
    }

    static JSValue defaultValue(const JSObject*, ExecState*, PreferredPrimitiveType);

public:
    typedef JSNonFinalObject Base;

    static TerminatedExecutionError* create(JSGlobalData& globalData)
    {
        TerminatedExecutionError* error = new (NotNull, allocateCell<TerminatedExecutionError>(globalData.heap)) TerminatedExecutionError(globalData);
        error->finishCreation(globalData);
        return error;
    }

    static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
    {
        return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
    }

    static JS_EXPORTDATA const ClassInfo s_info;
};

} // namespace JSC

#endif // ExceptionHelpers_h
