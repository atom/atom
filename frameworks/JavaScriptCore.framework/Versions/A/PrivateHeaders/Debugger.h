/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2008, 2009 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#ifndef Debugger_h
#define Debugger_h

#include <wtf/HashSet.h>

namespace JSC {

    class DebuggerCallFrame;
    class ExecState;
    class JSGlobalData;
    class JSGlobalObject;
    class JSValue;
    class SourceProvider;
    class UString;

    class JS_EXPORT_PRIVATE Debugger {
    public:
        virtual ~Debugger();

        void attach(JSGlobalObject*);
        virtual void detach(JSGlobalObject*);

        virtual void sourceParsed(ExecState*, SourceProvider*, int errorLineNumber, const UString& errorMessage) = 0;
        virtual void exception(const DebuggerCallFrame&, intptr_t sourceID, int lineNumber, bool hasHandler) = 0;
        virtual void atStatement(const DebuggerCallFrame&, intptr_t sourceID, int lineNumber) = 0;
        virtual void callEvent(const DebuggerCallFrame&, intptr_t sourceID, int lineNumber) = 0;
        virtual void returnEvent(const DebuggerCallFrame&, intptr_t sourceID, int lineNumber) = 0;

        virtual void willExecuteProgram(const DebuggerCallFrame&, intptr_t sourceID, int lineNumber) = 0;
        virtual void didExecuteProgram(const DebuggerCallFrame&, intptr_t sourceID, int lineNumber) = 0;
        virtual void didReachBreakpoint(const DebuggerCallFrame&, intptr_t sourceID, int lineNumber) = 0;

        void recompileAllJSFunctions(JSGlobalData*);

    private:
        HashSet<JSGlobalObject*> m_globalObjects;
    };

    // This function exists only for backwards compatibility with existing WebScriptDebugger clients.
    JS_EXPORT_PRIVATE JSValue evaluateInGlobalCallFrame(const UString&, JSValue& exception, JSGlobalObject*);

} // namespace JSC

#endif // Debugger_h
