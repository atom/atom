/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2007, 2008, 2011 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 *
 */

#ifndef CallFrame_h
#define CallFrame_h

#include "JSGlobalData.h"
#include "MacroAssemblerCodeRef.h"
#include "RegisterFile.h"

namespace JSC  {

    class Arguments;
    class JSActivation;
    class Interpreter;
    class ScopeChainNode;

    // Represents the current state of script execution.
    // Passed as the first argument to most functions.
    class ExecState : private Register {
    public:
        JSValue calleeAsValue() const { return this[RegisterFile::Callee].jsValue(); }
        JSObject* callee() const { return this[RegisterFile::Callee].function(); }
        CodeBlock* codeBlock() const { return this[RegisterFile::CodeBlock].Register::codeBlock(); }
        ScopeChainNode* scopeChain() const
        {
            ASSERT(this[RegisterFile::ScopeChain].Register::scopeChain());
            return this[RegisterFile::ScopeChain].Register::scopeChain();
        }

        // Global object in which execution began.
        JSGlobalObject* dynamicGlobalObject();

        // Global object in which the currently executing code was defined.
        // Differs from dynamicGlobalObject() during function calls across web browser frames.
        inline JSGlobalObject* lexicalGlobalObject() const;

        // Differs from lexicalGlobalObject because this will have DOM window shell rather than
        // the actual DOM window, which can't be "this" for security reasons.
        inline JSObject* globalThisValue() const;

        inline JSGlobalData& globalData() const;

        // Convenience functions for access to global data.
        // It takes a few memory references to get from a call frame to the global data
        // pointer, so these are inefficient, and should be used sparingly in new code.
        // But they're used in many places in legacy code, so they're not going away any time soon.

        void clearException() { globalData().exception = JSValue(); }
        JSValue exception() const { return globalData().exception; }
        bool hadException() const { return globalData().exception; }

        const CommonIdentifiers& propertyNames() const { return *globalData().propertyNames; }
        const MarkedArgumentBuffer& emptyList() const { return *globalData().emptyList; }
        Interpreter* interpreter() { return globalData().interpreter; }
        Heap* heap() { return &globalData().heap; }
#ifndef NDEBUG
        void dumpCaller();
#endif
        static const HashTable* arrayConstructorTable(CallFrame* callFrame) { return callFrame->globalData().arrayConstructorTable; }
        static const HashTable* arrayPrototypeTable(CallFrame* callFrame) { return callFrame->globalData().arrayPrototypeTable; }
        static const HashTable* booleanPrototypeTable(CallFrame* callFrame) { return callFrame->globalData().booleanPrototypeTable; }
        static const HashTable* dateTable(CallFrame* callFrame) { return callFrame->globalData().dateTable; }
        static const HashTable* dateConstructorTable(CallFrame* callFrame) { return callFrame->globalData().dateConstructorTable; }
        static const HashTable* errorPrototypeTable(CallFrame* callFrame) { return callFrame->globalData().errorPrototypeTable; }
        static const HashTable* globalObjectTable(CallFrame* callFrame) { return callFrame->globalData().globalObjectTable; }
        static const HashTable* jsonTable(CallFrame* callFrame) { return callFrame->globalData().jsonTable; }
        static const HashTable* mathTable(CallFrame* callFrame) { return callFrame->globalData().mathTable; }
        static const HashTable* numberConstructorTable(CallFrame* callFrame) { return callFrame->globalData().numberConstructorTable; }
        static const HashTable* numberPrototypeTable(CallFrame* callFrame) { return callFrame->globalData().numberPrototypeTable; }
        static const HashTable* objectConstructorTable(CallFrame* callFrame) { return callFrame->globalData().objectConstructorTable; }
        static const HashTable* objectPrototypeTable(CallFrame* callFrame) { return callFrame->globalData().objectPrototypeTable; }
        static const HashTable* regExpTable(CallFrame* callFrame) { return callFrame->globalData().regExpTable; }
        static const HashTable* regExpConstructorTable(CallFrame* callFrame) { return callFrame->globalData().regExpConstructorTable; }
        static const HashTable* regExpPrototypeTable(CallFrame* callFrame) { return callFrame->globalData().regExpPrototypeTable; }
        static const HashTable* stringTable(CallFrame* callFrame) { return callFrame->globalData().stringTable; }
        static const HashTable* stringConstructorTable(CallFrame* callFrame) { return callFrame->globalData().stringConstructorTable; }

        static CallFrame* create(Register* callFrameBase) { return static_cast<CallFrame*>(callFrameBase); }
        Register* registers() { return this; }

        CallFrame& operator=(const Register& r) { *static_cast<Register*>(this) = r; return *this; }

        CallFrame* callerFrame() const { return this[RegisterFile::CallerFrame].callFrame(); }
#if ENABLE(JIT)
        ReturnAddressPtr returnPC() const { return ReturnAddressPtr(this[RegisterFile::ReturnPC].vPC()); }
#endif
#if ENABLE(DFG_JIT)
        InlineCallFrame* inlineCallFrame() const { return this[RegisterFile::ReturnPC].asInlineCallFrame(); }
#else
        // This will never be called if !ENABLE(DFG_JIT) since all calls should be guarded by
        // isInlineCallFrame(). But to make it easier to write code without having a bunch of
        // #if's, we make a dummy implementation available anyway.
        InlineCallFrame* inlineCallFrame() const
        {
            ASSERT_NOT_REACHED();
            return 0;
        }
#endif
#if ENABLE(INTERPRETER)
        Instruction* returnVPC() const { return this[RegisterFile::ReturnPC].vPC(); }
#endif

        void setCallerFrame(CallFrame* callerFrame) { static_cast<Register*>(this)[RegisterFile::CallerFrame] = callerFrame; }
        void setScopeChain(ScopeChainNode* scopeChain) { static_cast<Register*>(this)[RegisterFile::ScopeChain] = scopeChain; }

        ALWAYS_INLINE void init(CodeBlock* codeBlock, Instruction* vPC, ScopeChainNode* scopeChain,
            CallFrame* callerFrame, int argc, JSObject* callee)
        {
            ASSERT(callerFrame); // Use noCaller() rather than 0 for the outer host call frame caller.
            ASSERT(callerFrame == noCaller() || callerFrame->removeHostCallFrameFlag()->registerFile()->end() >= this);

            setCodeBlock(codeBlock);
            setScopeChain(scopeChain);
            setCallerFrame(callerFrame);
            setReturnPC(vPC); // This is either an Instruction* or a pointer into JIT generated code stored as an Instruction*.
            setArgumentCountIncludingThis(argc); // original argument count (for the sake of the "arguments" object)
            setCallee(callee);
        }

        // Read a register from the codeframe (or constant from the CodeBlock).
        inline Register& r(int);
        // Read a register for a non-constant 
        inline Register& uncheckedR(int);

        // Access to arguments.
        size_t argumentCount() const { return argumentCountIncludingThis() - 1; }
        size_t argumentCountIncludingThis() const { return this[RegisterFile::ArgumentCount].payload(); }
        static int argumentOffset(size_t argument) { return s_firstArgumentOffset - argument; }
        static int argumentOffsetIncludingThis(size_t argument) { return s_thisArgumentOffset - argument; }

        JSValue argument(size_t argument)
        {
            if (argument >= argumentCount())
                 return jsUndefined();
            return this[argumentOffset(argument)].jsValue();
        }
        void setArgument(size_t argument, JSValue value)
        {
            this[argumentOffset(argument)] = value;
        }

        static int thisArgumentOffset() { return argumentOffsetIncludingThis(0); }
        JSValue thisValue() { return this[thisArgumentOffset()].jsValue(); }
        void setThisValue(JSValue value) { this[thisArgumentOffset()] = value; }

        static int offsetFor(size_t argumentCountIncludingThis) { return argumentCountIncludingThis + RegisterFile::CallFrameHeaderSize; }

        // FIXME: Remove these.
        int hostThisRegister() { return thisArgumentOffset(); }
        JSValue hostThisValue() { return thisValue(); }

        static CallFrame* noCaller() { return reinterpret_cast<CallFrame*>(HostCallFrameFlag); }

        bool hasHostCallFrameFlag() const { return reinterpret_cast<intptr_t>(this) & HostCallFrameFlag; }
        CallFrame* addHostCallFrameFlag() const { return reinterpret_cast<CallFrame*>(reinterpret_cast<intptr_t>(this) | HostCallFrameFlag); }
        CallFrame* removeHostCallFrameFlag() { return reinterpret_cast<CallFrame*>(reinterpret_cast<intptr_t>(this) & ~HostCallFrameFlag); }

        void setArgumentCountIncludingThis(int count) { static_cast<Register*>(this)[RegisterFile::ArgumentCount].payload() = count; }
        void setCallee(JSObject* callee) { static_cast<Register*>(this)[RegisterFile::Callee] = Register::withCallee(callee); }
        void setCodeBlock(CodeBlock* codeBlock) { static_cast<Register*>(this)[RegisterFile::CodeBlock] = codeBlock; }
        void setReturnPC(void* value) { static_cast<Register*>(this)[RegisterFile::ReturnPC] = (Instruction*)value; }
        
#if ENABLE(DFG_JIT)
        bool isInlineCallFrame();
        
        void setInlineCallFrame(InlineCallFrame* inlineCallFrame) { static_cast<Register*>(this)[RegisterFile::ReturnPC] = inlineCallFrame; }
        
        // Call this to get the semantically correct JS CallFrame*. This resolves issues
        // surrounding inlining and the HostCallFrameFlag stuff.
        CallFrame* trueCallerFrame();
#else
        bool isInlineCallFrame() { return false; }
        
        CallFrame* trueCallerFrame() { return callerFrame()->removeHostCallFrameFlag(); }
#endif

    private:
        static const intptr_t HostCallFrameFlag = 1;
        static const int s_thisArgumentOffset = -1 - RegisterFile::CallFrameHeaderSize;
        static const int s_firstArgumentOffset = s_thisArgumentOffset - 1;

#ifndef NDEBUG
        RegisterFile* registerFile();
#endif
#if ENABLE(DFG_JIT)
        bool isInlineCallFrameSlow();
#endif
        ExecState();
        ~ExecState();
    };

} // namespace JSC

#endif // CallFrame_h
