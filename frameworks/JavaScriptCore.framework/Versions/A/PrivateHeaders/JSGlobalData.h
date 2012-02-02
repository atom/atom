/*
 * Copyright (C) 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef JSGlobalData_h
#define JSGlobalData_h

#include "CachedTranscendentalFunction.h"
#include "Intrinsic.h"
#include "DateInstanceCache.h"
#include "ExecutableAllocator.h"
#include "Heap.h"
#include "Strong.h"
#include "JITStubs.h"
#include "JSValue.h"
#include "NumericStrings.h"
#include "SmallStrings.h"
#include "Terminator.h"
#include "TimeoutChecker.h"
#include "WeakRandom.h"
#include <wtf/BumpPointerAllocator.h>
#include <wtf/Forward.h>
#include <wtf/HashMap.h>
#include <wtf/RefCounted.h>
#include <wtf/ThreadSpecific.h>
#include <wtf/WTFThreadData.h>
#if ENABLE(REGEXP_TRACING)
#include <wtf/ListHashSet.h>
#endif

struct OpaqueJSClass;
struct OpaqueJSClassContextData;

namespace JSC {

    class CodeBlock;
    class CommonIdentifiers;
    class HandleStack;
    class IdentifierTable;
    class Interpreter;
    class JSGlobalObject;
    class JSObject;
    class Keywords;
    class NativeExecutable;
    class ParserArena;
    class RegExpCache;
    class Stringifier;
    class Structure;
    class UString;
#if ENABLE(REGEXP_TRACING)
    class RegExp;
#endif

    struct HashTable;
    struct Instruction;

    struct DSTOffsetCache {
        DSTOffsetCache()
        {
            reset();
        }
        
        void reset()
        {
            offset = 0.0;
            start = 0.0;
            end = -1.0;
            increment = 0.0;
        }

        double offset;
        double start;
        double end;
        double increment;
    };

    enum ThreadStackType {
        ThreadStackTypeLarge,
        ThreadStackTypeSmall
    };

    struct TypedArrayDescriptor {
        TypedArrayDescriptor()
            : m_classInfo(0)
            , m_storageOffset(0)
            , m_lengthOffset(0)
        {
        }
        TypedArrayDescriptor(const ClassInfo* classInfo, size_t storageOffset, size_t lengthOffset)
            : m_classInfo(classInfo)
            , m_storageOffset(storageOffset)
            , m_lengthOffset(lengthOffset)
        {
        }
        const ClassInfo* m_classInfo;
        size_t m_storageOffset;
        size_t m_lengthOffset;
    };
    
    class JSGlobalData : public RefCounted<JSGlobalData> {
    public:
        // WebCore has a one-to-one mapping of threads to JSGlobalDatas;
        // either create() or createLeaked() should only be called once
        // on a thread, this is the 'default' JSGlobalData (it uses the
        // thread's default string uniquing table from wtfThreadData).
        // API contexts created using the new context group aware interface
        // create APIContextGroup objects which require less locking of JSC
        // than the old singleton APIShared JSGlobalData created for use by
        // the original API.
        enum GlobalDataType { Default, APIContextGroup, APIShared };
        
        struct ClientData {
            JS_EXPORT_PRIVATE virtual ~ClientData() = 0;
        };

        bool isSharedInstance() { return globalDataType == APIShared; }
        bool usingAPI() { return globalDataType != Default; }
        static bool sharedInstanceExists();
        JS_EXPORT_PRIVATE static JSGlobalData& sharedInstance();

        JS_EXPORT_PRIVATE static PassRefPtr<JSGlobalData> create(ThreadStackType, HeapSize = SmallHeap);
        JS_EXPORT_PRIVATE static PassRefPtr<JSGlobalData> createLeaked(ThreadStackType, HeapSize = SmallHeap);
        static PassRefPtr<JSGlobalData> createContextGroup(ThreadStackType, HeapSize = SmallHeap);
        JS_EXPORT_PRIVATE ~JSGlobalData();

        void makeUsableFromMultipleThreads() { heap.machineThreads().makeUsableFromMultipleThreads(); }

        GlobalDataType globalDataType;
        ClientData* clientData;
        CallFrame* topCallFrame;

        const HashTable* arrayConstructorTable;
        const HashTable* arrayPrototypeTable;
        const HashTable* booleanPrototypeTable;
        const HashTable* dateTable;
        const HashTable* dateConstructorTable;
        const HashTable* errorPrototypeTable;
        const HashTable* globalObjectTable;
        const HashTable* jsonTable;
        const HashTable* mathTable;
        const HashTable* numberConstructorTable;
        const HashTable* numberPrototypeTable;
        const HashTable* objectConstructorTable;
        const HashTable* objectPrototypeTable;
        const HashTable* regExpTable;
        const HashTable* regExpConstructorTable;
        const HashTable* regExpPrototypeTable;
        const HashTable* stringTable;
        const HashTable* stringConstructorTable;
        
        Strong<Structure> structureStructure;
        Strong<Structure> debuggerActivationStructure;
        Strong<Structure> activationStructure;
        Strong<Structure> interruptedExecutionErrorStructure;
        Strong<Structure> terminatedExecutionErrorStructure;
        Strong<Structure> staticScopeStructure;
        Strong<Structure> strictEvalActivationStructure;
        Strong<Structure> stringStructure;
        Strong<Structure> notAnObjectStructure;
        Strong<Structure> propertyNameIteratorStructure;
        Strong<Structure> getterSetterStructure;
        Strong<Structure> apiWrapperStructure;
        Strong<Structure> scopeChainNodeStructure;
        Strong<Structure> executableStructure;
        Strong<Structure> nativeExecutableStructure;
        Strong<Structure> evalExecutableStructure;
        Strong<Structure> programExecutableStructure;
        Strong<Structure> functionExecutableStructure;
        Strong<Structure> regExpStructure;
        Strong<Structure> structureChainStructure;

        IdentifierTable* identifierTable;
        CommonIdentifiers* propertyNames;
        const MarkedArgumentBuffer* emptyList; // Lists are supposed to be allocated on the stack to have their elements properly marked, which is not the case here - but this list has nothing to mark.
        SmallStrings smallStrings;
        NumericStrings numericStrings;
        DateInstanceCache dateInstanceCache;
        Vector<CodeBlock*> codeBlocksBeingCompiled;
        void startedCompiling(CodeBlock* codeBlock)
        {
            codeBlocksBeingCompiled.append(codeBlock);
        }

        void finishedCompiling(CodeBlock* codeBlock)
        {
            ASSERT_UNUSED(codeBlock, codeBlock == codeBlocksBeingCompiled.last());
            codeBlocksBeingCompiled.removeLast();
        }

#if ENABLE(ASSEMBLER)
        ExecutableAllocator executableAllocator;
#endif

#if !ENABLE(JIT)
        bool canUseJIT() { return false; } // interpreter only
#elif !ENABLE(INTERPRETER)
        bool canUseJIT() { return true; } // jit only
#else
        bool canUseJIT() { return m_canUseJIT; }
#endif

        OwnPtr<ParserArena> parserArena;
        OwnPtr<Keywords> keywords;
        Interpreter* interpreter;
#if ENABLE(JIT)
        OwnPtr<JITThunks> jitStubs;
        MacroAssemblerCodeRef getCTIStub(ThunkGenerator generator)
        {
            return jitStubs->ctiStub(this, generator);
        }
        NativeExecutable* getHostFunction(NativeFunction, Intrinsic);
#endif
        NativeExecutable* getHostFunction(NativeFunction, NativeFunction constructor);

        TimeoutChecker timeoutChecker;
        Terminator terminator;
        Heap heap;

        JSValue exception;
#if ENABLE(JIT)
        ReturnAddressPtr exceptionLocation;
        JSValue hostCallReturnValue;
        CallFrame* callFrameForThrow;
        void* targetMachinePCForThrow;
        Instruction* targetInterpreterPCForThrow;
#if ENABLE(DFG_JIT)
        uint32_t osrExitIndex;
        void* osrExitJumpDestination;
        Vector<void*> scratchBuffers;
        size_t sizeOfLastScratchBuffer;
        
        void* scratchBufferForSize(size_t size)
        {
            if (!size)
                return 0;
            
            if (size > sizeOfLastScratchBuffer) {
                // Protect against a N^2 memory usage pathology by ensuring
                // that at worst, we get a geometric series, meaning that the
                // total memory usage is somewhere around
                // max(scratch buffer size) * 4.
                sizeOfLastScratchBuffer = size * 2;
                
                scratchBuffers.append(fastMalloc(sizeOfLastScratchBuffer));
            }
            
            return scratchBuffers.last();
        }
#endif
#endif

        HashMap<OpaqueJSClass*, OwnPtr<OpaqueJSClassContextData> > opaqueJSClassData;

        JSGlobalObject* dynamicGlobalObject;

        HashSet<JSObject*> stringRecursionCheckVisitedObjects;

        double cachedUTCOffset;
        DSTOffsetCache dstOffsetCache;
        
        UString cachedDateString;
        double cachedDateStringValue;

        int maxReentryDepth;

        RegExpCache* m_regExpCache;
        BumpPointerAllocator m_regExpAllocator;

#if ENABLE(REGEXP_TRACING)
        typedef ListHashSet<RefPtr<RegExp> > RTTraceList;
        RTTraceList* m_rtTraceList;
#endif

#ifndef NDEBUG
        ThreadIdentifier exclusiveThread;
#endif

        CachedTranscendentalFunction<sin> cachedSin;

        JS_EXPORT_PRIVATE void resetDateCache();

        JS_EXPORT_PRIVATE void startSampling();
        JS_EXPORT_PRIVATE void stopSampling();
        JS_EXPORT_PRIVATE void dumpSampleData(ExecState* exec);
        void recompileAllJSFunctions();
        RegExpCache* regExpCache() { return m_regExpCache; }
#if ENABLE(REGEXP_TRACING)
        void addRegExpToTrace(PassRefPtr<RegExp> regExp);
#endif
        JS_EXPORT_PRIVATE void dumpRegExpTrace();
        JS_EXPORT_PRIVATE void clearBuiltinStructures();

        bool isCollectorBusy() { return heap.isBusy(); }
        JS_EXPORT_PRIVATE void releaseExecutableMemory();

#if ENABLE(GC_VALIDATION)
        bool isInitializingObject() const; 
        void setInitializingObject(bool);
#endif

#if CPU(X86) && ENABLE(JIT)
        unsigned m_timeoutCount;
#endif

#define registerTypedArrayFunction(type, capitalizedType) \
        void registerTypedArrayDescriptor(const capitalizedType##Array*, const TypedArrayDescriptor& descriptor) \
        { \
            ASSERT(!m_##type##ArrayDescriptor.m_classInfo || m_##type##ArrayDescriptor.m_classInfo == descriptor.m_classInfo); \
            m_##type##ArrayDescriptor = descriptor; \
        } \
        const TypedArrayDescriptor& type##ArrayDescriptor() const { return m_##type##ArrayDescriptor; }

        registerTypedArrayFunction(int8, Int8);
        registerTypedArrayFunction(int16, Int16);
        registerTypedArrayFunction(int32, Int32);
        registerTypedArrayFunction(uint8, Uint8);
        registerTypedArrayFunction(uint8Clamped, Uint8Clamped);
        registerTypedArrayFunction(uint16, Uint16);
        registerTypedArrayFunction(uint32, Uint32);
        registerTypedArrayFunction(float32, Float32);
        registerTypedArrayFunction(float64, Float64);
#undef registerTypedArrayFunction

    private:
        JSGlobalData(GlobalDataType, ThreadStackType, HeapSize);
        static JSGlobalData*& sharedInstanceInternal();
        void createNativeThunk();
#if ENABLE(JIT) && ENABLE(INTERPRETER)
        bool m_canUseJIT;
#endif
#if ENABLE(GC_VALIDATION)
        bool m_isInitializingObject;
#endif
        TypedArrayDescriptor m_int8ArrayDescriptor;
        TypedArrayDescriptor m_int16ArrayDescriptor;
        TypedArrayDescriptor m_int32ArrayDescriptor;
        TypedArrayDescriptor m_uint8ArrayDescriptor;
        TypedArrayDescriptor m_uint8ClampedArrayDescriptor;
        TypedArrayDescriptor m_uint16ArrayDescriptor;
        TypedArrayDescriptor m_uint32ArrayDescriptor;
        TypedArrayDescriptor m_float32ArrayDescriptor;
        TypedArrayDescriptor m_float64ArrayDescriptor;
    };

#if ENABLE(GC_VALIDATION)
    inline bool JSGlobalData::isInitializingObject() const
    {
        return m_isInitializingObject;
    }

    inline void JSGlobalData::setInitializingObject(bool initializingObject)
    {
        m_isInitializingObject = initializingObject;
    }
#endif

} // namespace JSC

#endif // JSGlobalData_h
