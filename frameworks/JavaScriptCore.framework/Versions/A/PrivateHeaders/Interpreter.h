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

#ifndef Interpreter_h
#define Interpreter_h

#include "ArgList.h"
#include "JSCell.h"
#include "JSFunction.h"
#include "JSValue.h"
#include "JSObject.h"
#include "Opcode.h"
#include "RegisterFile.h"
#include "StrongInlines.h"

#include <wtf/HashMap.h>

namespace JSC {

    class CodeBlock;
    class EvalExecutable;
    class ExecutableBase;
    class FunctionExecutable;
    class JSGlobalObject;
    class ProgramExecutable;
    class Register;
    class ScopeChainNode;
    class SamplingTool;
    struct CallFrameClosure;
    struct HandlerInfo;
    struct Instruction;
    
    enum DebugHookID {
        WillExecuteProgram,
        DidExecuteProgram,
        DidEnterCallFrame,
        DidReachBreakpoint,
        WillLeaveCallFrame,
        WillExecuteStatement
    };

    enum StackFrameCodeType {
        StackFrameGlobalCode,
        StackFrameEvalCode,
        StackFrameFunctionCode,
        StackFrameNativeCode
    };

    struct StackFrame {
        Strong<JSObject> callee;
        Strong<CallFrame> callFrame;
        StackFrameCodeType codeType;
        Strong<ExecutableBase> executable;
        int line;
        UString sourceURL;
        UString toString() const
        {
            bool hasSourceURLInfo = sourceURL != NULL && !sourceURL.isNull() && !sourceURL.isEmpty();
            bool hasLineInfo = line > -1;
            String traceLine;
            String sourceInfo;
            JSObject* stackFrameCallee = callee.get();
            UString functionName = "";

            if (hasSourceURLInfo)
             sourceInfo = hasLineInfo ? String::format("%s:%d", sourceURL.ascii().data(), line)
                                      : String::format("%s", sourceURL.ascii().data());

            if (stackFrameCallee && stackFrameCallee->inherits(&JSFunction::s_info))
                functionName = asFunction(stackFrameCallee)->name(callFrame.get());

            switch (codeType) {
            case StackFrameEvalCode:
                if (hasSourceURLInfo && !functionName.isEmpty())
                    traceLine = String::format("at eval at %s (%s)", functionName.ascii().data(), sourceInfo.ascii().data());
                else if (hasSourceURLInfo)
                    traceLine = String::format("at eval at <anonymous> (%s)", sourceInfo.ascii().data());
                else if (!functionName.isEmpty())
                    traceLine = String::format("at eval at %s", functionName.ascii().data());
                else
                    traceLine = String::format("at eval");
                break;
            case StackFrameNativeCode:
                if (!functionName.isEmpty())
                    traceLine = String::format("at %s (native)", functionName.ascii().data());
                else
                    traceLine = "at (native)";
                break;
            case StackFrameFunctionCode:
            case StackFrameGlobalCode:
                if (hasSourceURLInfo && !functionName.isEmpty())
                    traceLine = String::format("at %s (%s)", functionName.ascii().data(), sourceInfo.ascii().data());
                else if (hasSourceURLInfo)
                    traceLine = String::format("at %s", sourceInfo.ascii().data());
                else if (!functionName.isEmpty())
                    traceLine = String::format("at %s", functionName.ascii().data());
                else
                    traceLine = String::format("at unknown source");
                break;
            }
            return traceLine.impl();
        }
    };

    class TopCallFrameSetter {
    public:
        TopCallFrameSetter(JSGlobalData& global, CallFrame* callFrame)
            : globalData(global)
            , oldCallFrame(global.topCallFrame)
        {
            global.topCallFrame = callFrame;
        }

        ~TopCallFrameSetter()
        {
            globalData.topCallFrame = oldCallFrame;
        }
    private:
        JSGlobalData& globalData;
        CallFrame* oldCallFrame;
    };

#if PLATFORM(IOS)
    // We use a smaller reentrancy limit on iPhone because of the high amount of
    // stack space required on the web thread.
    enum { MaxLargeThreadReentryDepth = 93, MaxSmallThreadReentryDepth = 16 };
#else
    enum { MaxLargeThreadReentryDepth = 256, MaxSmallThreadReentryDepth = 16 };
#endif // PLATFORM(IOS)

    class Interpreter {
        WTF_MAKE_FAST_ALLOCATED;
        friend class JIT;
        friend class CachedCall;
    public:
        Interpreter();
        
        void initialize(bool canUseJIT);

        RegisterFile& registerFile() { return m_registerFile; }
        
        Opcode getOpcode(OpcodeID id)
        {
            ASSERT(m_initialized);
#if ENABLE(COMPUTED_GOTO_INTERPRETER)
            return m_opcodeTable[id];
#else
            return id;
#endif
        }

        OpcodeID getOpcodeID(Opcode opcode)
        {
            ASSERT(m_initialized);
#if ENABLE(COMPUTED_GOTO_INTERPRETER)
            ASSERT(isOpcode(opcode));
            if (!m_enabled)
                return static_cast<OpcodeID>(bitwise_cast<uintptr_t>(opcode));

            return m_opcodeIDTable.get(opcode);
#else
            return opcode;
#endif
        }

        bool isOpcode(Opcode);

        JSValue execute(ProgramExecutable*, CallFrame*, ScopeChainNode*, JSObject* thisObj);
        JSValue executeCall(CallFrame*, JSObject* function, CallType, const CallData&, JSValue thisValue, const ArgList&);
        JSObject* executeConstruct(CallFrame*, JSObject* function, ConstructType, const ConstructData&, const ArgList&);
        JSValue execute(EvalExecutable*, CallFrame*, JSValue thisValue, ScopeChainNode*);
        JSValue execute(EvalExecutable*, CallFrame*, JSValue thisValue, ScopeChainNode*, int globalRegisterOffset);

        JSValue retrieveArguments(CallFrame*, JSFunction*) const;
        JS_EXPORT_PRIVATE JSValue retrieveCaller(CallFrame*, JSFunction*) const;
        JS_EXPORT_PRIVATE void retrieveLastCaller(CallFrame*, int& lineNumber, intptr_t& sourceID, UString& sourceURL, JSValue& function) const;
        
        void getArgumentsData(CallFrame*, JSFunction*&, ptrdiff_t& firstParameterIndex, Register*& argv, int& argc);
        
        SamplingTool* sampler() { return m_sampler.get(); }

        NEVER_INLINE HandlerInfo* throwException(CallFrame*&, JSValue&, unsigned bytecodeOffset);
        NEVER_INLINE void debug(CallFrame*, DebugHookID, int firstLine, int lastLine);
        static const UString getTraceLine(CallFrame*, StackFrameCodeType, const UString&, int);
        static void getStackTrace(JSGlobalData*, int line, Vector<StackFrame>& results);

        void dumpSampleData(ExecState* exec);
        void startSampling();
        void stopSampling();
    private:
        enum ExecutionFlag { Normal, InitializeAndReturn };

        CallFrameClosure prepareForRepeatCall(FunctionExecutable*, CallFrame*, JSFunction*, int argumentCountIncludingThis, ScopeChainNode*);
        void endRepeatCall(CallFrameClosure&);
        JSValue execute(CallFrameClosure&);

#if ENABLE(INTERPRETER)
        NEVER_INLINE bool resolve(CallFrame*, Instruction*, JSValue& exceptionValue);
        NEVER_INLINE bool resolveSkip(CallFrame*, Instruction*, JSValue& exceptionValue);
        NEVER_INLINE bool resolveGlobal(CallFrame*, Instruction*, JSValue& exceptionValue);
        NEVER_INLINE bool resolveGlobalDynamic(CallFrame*, Instruction*, JSValue& exceptionValue);
        NEVER_INLINE void resolveBase(CallFrame*, Instruction* vPC);
        NEVER_INLINE bool resolveBaseAndProperty(CallFrame*, Instruction*, JSValue& exceptionValue);
        NEVER_INLINE bool resolveThisAndProperty(CallFrame*, Instruction*, JSValue& exceptionValue);
        NEVER_INLINE ScopeChainNode* createExceptionScope(CallFrame*, const Instruction* vPC);

        void tryCacheGetByID(CallFrame*, CodeBlock*, Instruction*, JSValue baseValue, const Identifier& propertyName, const PropertySlot&);
        void uncacheGetByID(CodeBlock*, Instruction* vPC);
        void tryCachePutByID(CallFrame*, CodeBlock*, Instruction*, JSValue baseValue, const PutPropertySlot&);
        void uncachePutByID(CodeBlock*, Instruction* vPC);        
#endif // ENABLE(INTERPRETER)

        NEVER_INLINE bool unwindCallFrame(CallFrame*&, JSValue, unsigned& bytecodeOffset, CodeBlock*&);

        static ALWAYS_INLINE CallFrame* slideRegisterWindowForCall(CodeBlock*, RegisterFile*, CallFrame*, size_t registerOffset, int argc);

        static CallFrame* findFunctionCallFrame(CallFrame*, JSFunction*);

        JSValue privateExecute(ExecutionFlag, RegisterFile*, CallFrame*);

        void dumpCallFrame(CallFrame*);
        void dumpRegisters(CallFrame*);
        
        bool isCallBytecode(Opcode opcode) { return opcode == getOpcode(op_call) || opcode == getOpcode(op_construct) || opcode == getOpcode(op_call_eval); }

        void enableSampler();
        int m_sampleEntryDepth;
        OwnPtr<SamplingTool> m_sampler;

        int m_reentryDepth;

        RegisterFile m_registerFile;
        
#if ENABLE(COMPUTED_GOTO_INTERPRETER)
        Opcode m_opcodeTable[numOpcodeIDs]; // Maps OpcodeID => Opcode for compiling
        HashMap<Opcode, OpcodeID> m_opcodeIDTable; // Maps Opcode => OpcodeID for decompiling
#endif

#if !ASSERT_DISABLED
        bool m_initialized;
#endif
        bool m_enabled;
    };

    // This value must not be an object that would require this conversion (WebCore's global object).
    inline bool isValidThisObject(JSValue thisValue, ExecState* exec)
    {
        return !thisValue.isObject() || thisValue.toThisObject(exec) == thisValue;
    }

    inline JSValue Interpreter::execute(EvalExecutable* eval, CallFrame* callFrame, JSValue thisValue, ScopeChainNode* scopeChain)
    {
        return execute(eval, callFrame, thisValue, scopeChain, m_registerFile.size() + 1 + RegisterFile::CallFrameHeaderSize);
    }

    JSValue eval(CallFrame*);
    CallFrame* loadVarargs(CallFrame*, RegisterFile*, JSValue thisValue, JSValue arguments, int firstFreeRegister);

} // namespace JSC

#endif // Interpreter_h
