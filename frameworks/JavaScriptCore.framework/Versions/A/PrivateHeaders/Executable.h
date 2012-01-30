/*
 * Copyright (C) 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef Executable_h
#define Executable_h

#include "CallData.h"
#include "JSFunction.h"
#include "Interpreter.h"
#include "Nodes.h"
#include "SamplingTool.h"
#include <wtf/PassOwnPtr.h>

namespace JSC {

    class CodeBlock;
    class Debugger;
    class EvalCodeBlock;
    class FunctionCodeBlock;
    class ProgramCodeBlock;
    class ScopeChainNode;

    struct ExceptionInfo;
    
    enum CodeSpecializationKind { CodeForCall, CodeForConstruct };
    enum CompilationKind { FirstCompilation, OptimizingCompilation };

    inline bool isCall(CodeSpecializationKind kind)
    {
        if (kind == CodeForCall)
            return true;
        ASSERT(kind == CodeForConstruct);
        return false;
    }

    class ExecutableBase : public JSCell {
        friend class JIT;

    protected:
        static const int NUM_PARAMETERS_IS_HOST = 0;
        static const int NUM_PARAMETERS_NOT_COMPILED = -1;

        ExecutableBase(JSGlobalData& globalData, Structure* structure, int numParameters)
            : JSCell(globalData, structure)
            , m_numParametersForCall(numParameters)
            , m_numParametersForConstruct(numParameters)
        {
        }

        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData);
        }

    public:
        typedef JSCell Base;

        static void destroy(JSCell*);

        bool isHostFunction() const
        {
            ASSERT((m_numParametersForCall == NUM_PARAMETERS_IS_HOST) == (m_numParametersForConstruct == NUM_PARAMETERS_IS_HOST));
            return m_numParametersForCall == NUM_PARAMETERS_IS_HOST;
        }

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue proto) { return Structure::create(globalData, globalObject, proto, TypeInfo(CompoundType, StructureFlags), &s_info); }
        
        static JS_EXPORTDATA const ClassInfo s_info;

    protected:
        static const unsigned StructureFlags = 0;
        int m_numParametersForCall;
        int m_numParametersForConstruct;

#if ENABLE(JIT)
    public:
        JITCode& generatedJITCodeForCall()
        {
            ASSERT(m_jitCodeForCall);
            return m_jitCodeForCall;
        }

        JITCode& generatedJITCodeForConstruct()
        {
            ASSERT(m_jitCodeForConstruct);
            return m_jitCodeForConstruct;
        }
        
        JITCode& generatedJITCodeFor(CodeSpecializationKind kind)
        {
            if (kind == CodeForCall)
                return generatedJITCodeForCall();
            ASSERT(kind == CodeForConstruct);
            return generatedJITCodeForConstruct();
        }

        MacroAssemblerCodePtr generatedJITCodeForCallWithArityCheck()
        {
            ASSERT(m_jitCodeForCall);
            ASSERT(m_jitCodeForCallWithArityCheck);
            return m_jitCodeForCallWithArityCheck;
        }

        MacroAssemblerCodePtr generatedJITCodeForConstructWithArityCheck()
        {
            ASSERT(m_jitCodeForConstruct);
            ASSERT(m_jitCodeForConstructWithArityCheck);
            return m_jitCodeForConstructWithArityCheck;
        }
        
        MacroAssemblerCodePtr generatedJITCodeWithArityCheckFor(CodeSpecializationKind kind)
        {
            if (kind == CodeForCall)
                return generatedJITCodeForCallWithArityCheck();
            ASSERT(kind == CodeForConstruct);
            return generatedJITCodeForConstructWithArityCheck();
        }
        
        bool hasJITCodeForCall() const
        {
            return m_numParametersForCall >= 0;
        }
        
        bool hasJITCodeForConstruct() const
        {
            return m_numParametersForConstruct >= 0;
        }
        
        bool hasJITCodeFor(CodeSpecializationKind kind) const
        {
            if (kind == CodeForCall)
                return hasJITCodeForCall();
            ASSERT(kind == CodeForConstruct);
            return hasJITCodeForConstruct();
        }

        // Intrinsics are only for calls, currently.
        Intrinsic intrinsic() const;
        
        Intrinsic intrinsicFor(CodeSpecializationKind kind) const
        {
            if (isCall(kind))
                return intrinsic();
            return NoIntrinsic;
        }

    protected:
        JITCode m_jitCodeForCall;
        JITCode m_jitCodeForConstruct;
        MacroAssemblerCodePtr m_jitCodeForCallWithArityCheck;
        MacroAssemblerCodePtr m_jitCodeForConstructWithArityCheck;
#endif
        void clearCode();
    };

    class NativeExecutable : public ExecutableBase {
        friend class JIT;
    public:
        typedef ExecutableBase Base;

#if ENABLE(JIT)
        static NativeExecutable* create(JSGlobalData& globalData, MacroAssemblerCodeRef callThunk, NativeFunction function, MacroAssemblerCodeRef constructThunk, NativeFunction constructor, Intrinsic intrinsic)
        {
            ASSERT(globalData.canUseJIT());
            NativeExecutable* executable;
            if (!callThunk) {
                executable = new (NotNull, allocateCell<NativeExecutable>(globalData.heap)) NativeExecutable(globalData, function, constructor);
                executable->finishCreation(globalData, JITCode(), JITCode(), intrinsic);
            } else {
                executable = new (NotNull, allocateCell<NativeExecutable>(globalData.heap)) NativeExecutable(globalData, function, constructor);
                executable->finishCreation(globalData, JITCode::HostFunction(callThunk), JITCode::HostFunction(constructThunk), intrinsic);
            }
            globalData.heap.addFinalizer(executable, &finalize);
            return executable;
        }
#endif

#if ENABLE(INTERPRETER)
        static NativeExecutable* create(JSGlobalData& globalData, NativeFunction function, NativeFunction constructor)
        {
            ASSERT(!globalData.canUseJIT());
            NativeExecutable* executable = new (NotNull, allocateCell<NativeExecutable>(globalData.heap)) NativeExecutable(globalData, function, constructor);
            executable->finishCreation(globalData);
            globalData.heap.addFinalizer(executable, &finalize);
            return executable;
        }
#endif

        static void destroy(JSCell*);

        NativeFunction function() { return m_function; }
        NativeFunction constructor() { return m_constructor; }

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue proto) { return Structure::create(globalData, globalObject, proto, TypeInfo(LeafType, StructureFlags), &s_info); }
        
        static const ClassInfo s_info;

        Intrinsic intrinsic() const;

    protected:
#if ENABLE(JIT)
        void finishCreation(JSGlobalData& globalData, JITCode callThunk, JITCode constructThunk, Intrinsic intrinsic)
        {
            ASSERT(globalData.canUseJIT());
            Base::finishCreation(globalData);
            m_jitCodeForCall = callThunk;
            m_jitCodeForConstruct = constructThunk;
            m_jitCodeForCallWithArityCheck = callThunk.addressForCall();
            m_jitCodeForConstructWithArityCheck = constructThunk.addressForCall();
            m_intrinsic = intrinsic;
        }
#endif

#if ENABLE(INTERPRETER)
        void finishCreation(JSGlobalData& globalData)
        {
            ASSERT(!globalData.canUseJIT());
            Base::finishCreation(globalData);
            m_intrinsic = NoIntrinsic;
        }
#endif

        static void finalize(JSCell*);
 
    private:
        NativeExecutable(JSGlobalData& globalData, NativeFunction function, NativeFunction constructor)
            : ExecutableBase(globalData, globalData.nativeExecutableStructure.get(), NUM_PARAMETERS_IS_HOST)
            , m_function(function)
            , m_constructor(constructor)
        {
        }

        NativeFunction m_function;
        NativeFunction m_constructor;
        
        Intrinsic m_intrinsic;
    };

    class ScriptExecutable : public ExecutableBase {
    public:
        typedef ExecutableBase Base;

        ScriptExecutable(Structure* structure, JSGlobalData& globalData, const SourceCode& source, bool isInStrictContext)
            : ExecutableBase(globalData, structure, NUM_PARAMETERS_NOT_COMPILED)
            , m_source(source)
            , m_features(isInStrictContext ? StrictModeFeature : 0)
        {
        }

        ScriptExecutable(Structure* structure, ExecState* exec, const SourceCode& source, bool isInStrictContext)
            : ExecutableBase(exec->globalData(), structure, NUM_PARAMETERS_NOT_COMPILED)
            , m_source(source)
            , m_features(isInStrictContext ? StrictModeFeature : 0)
        {
        }

        static void destroy(JSCell*);

        const SourceCode& source() { return m_source; }
        intptr_t sourceID() const { return m_source.provider()->asID(); }
        const UString& sourceURL() const { return m_source.provider()->url(); }
        int lineNo() const { return m_firstLine; }
        int lastLine() const { return m_lastLine; }

        bool usesEval() const { return m_features & EvalFeature; }
        bool usesArguments() const { return m_features & ArgumentsFeature; }
        bool needsActivation() const { return m_hasCapturedVariables || m_features & (EvalFeature | WithFeature | CatchFeature); }
        bool isStrictMode() const { return m_features & StrictModeFeature; }

        void unlinkCalls();
        
        static const ClassInfo s_info;

    protected:
        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData);
#if ENABLE(CODEBLOCK_SAMPLING)
            if (SamplingTool* sampler = globalData.interpreter->sampler())
                sampler->notifyOfScope(globalData, this);
#endif
        }

        void recordParse(CodeFeatures features, bool hasCapturedVariables, int firstLine, int lastLine)
        {
            m_features = features;
            m_hasCapturedVariables = hasCapturedVariables;
            m_firstLine = firstLine;
            m_lastLine = lastLine;
        }

        SourceCode m_source;
        CodeFeatures m_features;
        bool m_hasCapturedVariables;
        int m_firstLine;
        int m_lastLine;
    };

    class EvalExecutable : public ScriptExecutable {
    public:
        typedef ScriptExecutable Base;

        static void destroy(JSCell*);

        JSObject* compile(ExecState* exec, ScopeChainNode* scopeChainNode)
        {
            ASSERT(exec->globalData().dynamicGlobalObject);
            JSObject* error = 0;
            if (!m_evalCodeBlock)
                error = compileInternal(exec, scopeChainNode, JITCode::bottomTierJIT());
            ASSERT(!error == !!m_evalCodeBlock);
            return error;
        }
        
        JSObject* compileOptimized(ExecState*, ScopeChainNode*);
        
#if ENABLE(JIT)
        void jettisonOptimizedCode(JSGlobalData&);
#endif

        EvalCodeBlock& generatedBytecode()
        {
            ASSERT(m_evalCodeBlock);
            return *m_evalCodeBlock;
        }

        static EvalExecutable* create(ExecState* exec, const SourceCode& source, bool isInStrictContext) 
        {
            EvalExecutable* executable = new (NotNull, allocateCell<EvalExecutable>(*exec->heap())) EvalExecutable(exec, source, isInStrictContext);
            executable->finishCreation(exec->globalData());
            exec->globalData().heap.addFinalizer(executable, &finalize);
            return executable;
        }

#if ENABLE(JIT)
        JITCode& generatedJITCode()
        {
            return generatedJITCodeForCall();
        }
#endif
        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue proto)
        {
            return Structure::create(globalData, globalObject, proto, TypeInfo(EvalExecutableType, StructureFlags), &s_info);
        }
        
        static const ClassInfo s_info;

        void unlinkCalls();

    protected:
        void clearCode();
        static void finalize(JSCell*);

    private:
        static const unsigned StructureFlags = OverridesVisitChildren | ScriptExecutable::StructureFlags;
        EvalExecutable(ExecState*, const SourceCode&, bool);

        JSObject* compileInternal(ExecState*, ScopeChainNode*, JITCode::JITType);
        static void visitChildren(JSCell*, SlotVisitor&);

        OwnPtr<EvalCodeBlock> m_evalCodeBlock;
    };

    class ProgramExecutable : public ScriptExecutable {
    public:
        typedef ScriptExecutable Base;

        static ProgramExecutable* create(ExecState* exec, const SourceCode& source)
        {
            ProgramExecutable* executable = new (NotNull, allocateCell<ProgramExecutable>(*exec->heap())) ProgramExecutable(exec, source);
            executable->finishCreation(exec->globalData());
            exec->globalData().heap.addFinalizer(executable, &finalize);
            return executable;
        }

        static void destroy(JSCell*);

        JSObject* compile(ExecState* exec, ScopeChainNode* scopeChainNode)
        {
            ASSERT(exec->globalData().dynamicGlobalObject);
            JSObject* error = 0;
            if (!m_programCodeBlock)
                error = compileInternal(exec, scopeChainNode, JITCode::bottomTierJIT());
            ASSERT(!error == !!m_programCodeBlock);
            return error;
        }

        JSObject* compileOptimized(ExecState*, ScopeChainNode*);
        
#if ENABLE(JIT)
        void jettisonOptimizedCode(JSGlobalData&);
#endif

        ProgramCodeBlock& generatedBytecode()
        {
            ASSERT(m_programCodeBlock);
            return *m_programCodeBlock;
        }

        JSObject* checkSyntax(ExecState*);

#if ENABLE(JIT)
        JITCode& generatedJITCode()
        {
            return generatedJITCodeForCall();
        }
#endif
        
        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue proto)
        {
            return Structure::create(globalData, globalObject, proto, TypeInfo(ProgramExecutableType, StructureFlags), &s_info);
        }
        
        static const ClassInfo s_info;
        
        void unlinkCalls();

    protected:
        void clearCode();
        static void finalize(JSCell*);

    private:
        static const unsigned StructureFlags = OverridesVisitChildren | ScriptExecutable::StructureFlags;
        ProgramExecutable(ExecState*, const SourceCode&);

        JSObject* compileInternal(ExecState*, ScopeChainNode*, JITCode::JITType);
        static void visitChildren(JSCell*, SlotVisitor&);

        OwnPtr<ProgramCodeBlock> m_programCodeBlock;
    };

    class FunctionExecutable : public ScriptExecutable {
        friend class JIT;
    public:
        typedef ScriptExecutable Base;

        static FunctionExecutable* create(ExecState* exec, const Identifier& name, const SourceCode& source, bool forceUsesArguments, FunctionParameters* parameters, bool isInStrictContext, int firstLine, int lastLine)
        {
            FunctionExecutable* executable = new (NotNull, allocateCell<FunctionExecutable>(*exec->heap())) FunctionExecutable(exec, name, source, forceUsesArguments, parameters, isInStrictContext);
            executable->finishCreation(exec->globalData(), name, firstLine, lastLine);
            exec->globalData().heap.addFinalizer(executable, &finalize);
            return executable;
        }

        static FunctionExecutable* create(JSGlobalData& globalData, const Identifier& name, const SourceCode& source, bool forceUsesArguments, FunctionParameters* parameters, bool isInStrictContext, int firstLine, int lastLine)
        {
            FunctionExecutable* executable = new (NotNull, allocateCell<FunctionExecutable>(globalData.heap)) FunctionExecutable(globalData, name, source, forceUsesArguments, parameters, isInStrictContext);
            executable->finishCreation(globalData, name, firstLine, lastLine);
            globalData.heap.addFinalizer(executable, &finalize);
            return executable;
        }

        static void destroy(JSCell*);

        JSFunction* make(ExecState* exec, ScopeChainNode* scopeChain)
        {
            return JSFunction::create(exec, this, scopeChain);
        }
        
        // Returns either call or construct bytecode. This can be appropriate
        // for answering questions that that don't vary between call and construct --
        // for example, argumentsRegister().
        FunctionCodeBlock& generatedBytecode()
        {
            if (m_codeBlockForCall)
                return *m_codeBlockForCall;
            ASSERT(m_codeBlockForConstruct);
            return *m_codeBlockForConstruct;
        }
        
        FunctionCodeBlock* codeBlockWithBytecodeFor(CodeSpecializationKind);
        
        PassOwnPtr<FunctionCodeBlock> produceCodeBlockFor(ScopeChainNode*, CompilationKind, CodeSpecializationKind, JSObject*& exception);

        JSObject* compileForCall(ExecState* exec, ScopeChainNode* scopeChainNode)
        {
            ASSERT(exec->globalData().dynamicGlobalObject);
            JSObject* error = 0;
            if (!m_codeBlockForCall)
                error = compileForCallInternal(exec, scopeChainNode, JITCode::bottomTierJIT());
            ASSERT(!error == !!m_codeBlockForCall);
            return error;
        }

        JSObject* compileOptimizedForCall(ExecState*, ScopeChainNode*);
        
#if ENABLE(JIT)
        void jettisonOptimizedCodeForCall(JSGlobalData&);
#endif

        bool isGeneratedForCall() const
        {
            return m_codeBlockForCall;
        }

        FunctionCodeBlock& generatedBytecodeForCall()
        {
            ASSERT(m_codeBlockForCall);
            return *m_codeBlockForCall;
        }

        JSObject* compileForConstruct(ExecState* exec, ScopeChainNode* scopeChainNode)
        {
            ASSERT(exec->globalData().dynamicGlobalObject);
            JSObject* error = 0;
            if (!m_codeBlockForConstruct)
                error = compileForConstructInternal(exec, scopeChainNode, JITCode::bottomTierJIT());
            ASSERT(!error == !!m_codeBlockForConstruct);
            return error;
        }

        JSObject* compileOptimizedForConstruct(ExecState*, ScopeChainNode*);
        
#if ENABLE(JIT)
        void jettisonOptimizedCodeForConstruct(JSGlobalData&);
#endif

        bool isGeneratedForConstruct() const
        {
            return m_codeBlockForConstruct;
        }

        FunctionCodeBlock& generatedBytecodeForConstruct()
        {
            ASSERT(m_codeBlockForConstruct);
            return *m_codeBlockForConstruct;
        }
        
        JSObject* compileFor(ExecState* exec, ScopeChainNode* scopeChainNode, CodeSpecializationKind kind)
        {
            ASSERT(exec->callee());
            ASSERT(exec->callee()->inherits(&JSFunction::s_info));
            ASSERT(asFunction(exec->callee())->jsExecutable() == this);

            if (kind == CodeForCall)
                return compileForCall(exec, scopeChainNode);
            ASSERT(kind == CodeForConstruct);
            return compileForConstruct(exec, scopeChainNode);
        }
        
        JSObject* compileOptimizedFor(ExecState* exec, ScopeChainNode* scopeChainNode, CodeSpecializationKind kind)
        {
            ASSERT(exec->callee());
            ASSERT(exec->callee()->inherits(&JSFunction::s_info));
            ASSERT(asFunction(exec->callee())->jsExecutable() == this);
            
            if (kind == CodeForCall)
                return compileOptimizedForCall(exec, scopeChainNode);
            ASSERT(kind == CodeForConstruct);
            return compileOptimizedForConstruct(exec, scopeChainNode);
        }
        
#if ENABLE(JIT)
        void jettisonOptimizedCodeFor(JSGlobalData& globalData, CodeSpecializationKind kind)
        {
            if (kind == CodeForCall) 
                jettisonOptimizedCodeForCall(globalData);
            else {
                ASSERT(kind == CodeForConstruct);
                jettisonOptimizedCodeForConstruct(globalData);
            }
        }
#endif
        
        bool isGeneratedFor(CodeSpecializationKind kind)
        {
            if (kind == CodeForCall)
                return isGeneratedForCall();
            ASSERT(kind == CodeForConstruct);
            return isGeneratedForConstruct();
        }
        
        FunctionCodeBlock& generatedBytecodeFor(CodeSpecializationKind kind)
        {
            if (kind == CodeForCall)
                return generatedBytecodeForCall();
            ASSERT(kind == CodeForConstruct);
            return generatedBytecodeForConstruct();
        }

        FunctionCodeBlock* baselineCodeBlockFor(CodeSpecializationKind);
        
        FunctionCodeBlock* profiledCodeBlockFor(CodeSpecializationKind kind)
        {
            return baselineCodeBlockFor(kind);
        }
        
        const Identifier& name() { return m_name; }
        JSString* nameValue() const { return m_nameValue.get(); }
        size_t parameterCount() const { return m_parameters->size(); } // Excluding 'this'!
        unsigned capturedVariableCount() const { return m_numCapturedVariables; }
        UString paramString() const;
        SharedSymbolTable* symbolTable() const { return m_symbolTable; }

        void discardCode();
        static void visitChildren(JSCell*, SlotVisitor&);
        static FunctionExecutable* fromGlobalCode(const Identifier&, ExecState*, Debugger*, const SourceCode&, JSObject** exception);
        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue proto)
        {
            return Structure::create(globalData, globalObject, proto, TypeInfo(FunctionExecutableType, StructureFlags), &s_info);
        }
        
        static const ClassInfo s_info;
        
        void unlinkCalls();

    protected:
        void clearCode();
        static void finalize(JSCell*);

        void finishCreation(JSGlobalData& globalData, const Identifier& name, int firstLine, int lastLine)
        {
            Base::finishCreation(globalData);
            m_firstLine = firstLine;
            m_lastLine = lastLine;
            m_nameValue.set(globalData, this, jsString(&globalData, name.ustring()));
        }

    private:
        FunctionExecutable(JSGlobalData&, const Identifier& name, const SourceCode&, bool forceUsesArguments, FunctionParameters*, bool);
        FunctionExecutable(ExecState*, const Identifier& name, const SourceCode&, bool forceUsesArguments, FunctionParameters*, bool);

        JSObject* compileForCallInternal(ExecState*, ScopeChainNode*, JITCode::JITType);
        JSObject* compileForConstructInternal(ExecState*, ScopeChainNode*, JITCode::JITType);
        
        OwnPtr<FunctionCodeBlock>& codeBlockFor(CodeSpecializationKind kind)
        {
            if (kind == CodeForCall)
                return m_codeBlockForCall;
            ASSERT(kind == CodeForConstruct);
            return m_codeBlockForConstruct;
        }
        
        static const unsigned StructureFlags = OverridesVisitChildren | ScriptExecutable::StructureFlags;
        unsigned m_numCapturedVariables : 31;
        bool m_forceUsesArguments : 1;

        RefPtr<FunctionParameters> m_parameters;
        OwnPtr<FunctionCodeBlock> m_codeBlockForCall;
        OwnPtr<FunctionCodeBlock> m_codeBlockForConstruct;
        Identifier m_name;
        WriteBarrier<JSString> m_nameValue;
        SharedSymbolTable* m_symbolTable;
    };

    inline FunctionExecutable* JSFunction::jsExecutable() const
    {
        ASSERT(!isHostFunctionNonInline());
        return static_cast<FunctionExecutable*>(m_executable.get());
    }

    inline bool JSFunction::isHostFunction() const
    {
        ASSERT(m_executable);
        return m_executable->isHostFunction();
    }

    inline NativeFunction JSFunction::nativeFunction()
    {
        ASSERT(isHostFunction());
        return static_cast<NativeExecutable*>(m_executable.get())->function();
    }

    inline NativeFunction JSFunction::nativeConstructor()
    {
        ASSERT(isHostFunction());
        return static_cast<NativeExecutable*>(m_executable.get())->constructor();
    }

    inline bool isHostFunction(JSValue value, NativeFunction nativeFunction)
    {
        JSFunction* function = static_cast<JSFunction*>(getJSFunction(value));
        if (!function || !function->isHostFunction())
            return false;
        return function->nativeFunction() == nativeFunction;
    }

    inline void ScriptExecutable::unlinkCalls()
    {
        switch (structure()->typeInfo().type()) {
        case EvalExecutableType:
            return jsCast<EvalExecutable*>(this)->unlinkCalls();
        case ProgramExecutableType:
            return jsCast<ProgramExecutable*>(this)->unlinkCalls();
        case FunctionExecutableType:
            return jsCast<FunctionExecutable*>(this)->unlinkCalls();
        default:
            ASSERT_NOT_REACHED();
        }
    }

}

#endif
