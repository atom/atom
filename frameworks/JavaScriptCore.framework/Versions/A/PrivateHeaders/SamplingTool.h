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

#ifndef SamplingTool_h
#define SamplingTool_h

#include "Strong.h"
#include "Nodes.h"
#include "Opcode.h"
#include "SamplingCounter.h"
#include <wtf/Assertions.h>
#include <wtf/Atomics.h>
#include <wtf/HashMap.h>
#include <wtf/MainThread.h>
#include <wtf/Threading.h>

namespace JSC {

    class ScriptExecutable;

    class SamplingFlags {
    public:
        JS_EXPORT_PRIVATE static void start();
        JS_EXPORT_PRIVATE static void stop();

#if ENABLE(SAMPLING_FLAGS)
        static void setFlag(unsigned flag)
        {
            ASSERT(flag >= 1);
            ASSERT(flag <= 32);
            s_flags |= 1u << (flag - 1);
        }

        static void clearFlag(unsigned flag)
        {
            ASSERT(flag >= 1);
            ASSERT(flag <= 32);
            s_flags &= ~(1u << (flag - 1));
        }

        static void sample();

        class ScopedFlag {
        public:
            ScopedFlag(int flag)
                : m_flag(flag)
            {
                setFlag(flag);
            }

            ~ScopedFlag()
            {
                clearFlag(m_flag);
            }

        private:
            int m_flag;
        };
    
        static const void* addressOfFlags()
        {
            return &s_flags;
        }

#endif
    private:
        JS_EXPORTDATA static uint32_t s_flags;
#if ENABLE(SAMPLING_FLAGS)
        static uint64_t s_flagCounts[33];
#endif
    };

#if ENABLE(SAMPLING_REGIONS)
    class SamplingRegion {
    public:
        // Create a scoped sampling region using a C string constant name that describes
        // what you are doing. This must be a string constant that persists for the
        // lifetime of the process and is immutable.
        SamplingRegion(const char* name)
        {
            if (!isMainThread()) {
                m_name = 0;
                return;
            }
            
            m_name = name;
            exchangeCurrent(this, &m_previous);
            ASSERT(!m_previous || m_previous > this);
        }
        
        ~SamplingRegion()
        {
            if (!m_name)
                return;
            
            ASSERT(bitwise_cast<SamplingRegion*>(s_currentOrReserved & ~1) == this);
            exchangeCurrent(m_previous);
        }
        
        static void sample();
        
        static void dump();
        
    private:
        const char* m_name;
        SamplingRegion* m_previous;

        static void exchangeCurrent(SamplingRegion* current, SamplingRegion** previousPtr = 0)
        {
            uintptr_t previous;
            while (true) {
                previous = s_currentOrReserved;
                
                // If it's reserved (i.e. sampling thread is reading it), loop around.
                if (previous & 1) {
#if OS(UNIX)
                    sched_yield();
#endif
                    continue;
                }
                
                // If we're going to CAS, then make sure previous is set.
                if (previousPtr)
                    *previousPtr = bitwise_cast<SamplingRegion*>(previous);
                
                if (WTF::weakCompareAndSwap(&s_currentOrReserved, previous, bitwise_cast<uintptr_t>(current)))
                    break;
            }
        }
        
        static void dumpInternal();

        class Locker {
        public:
            Locker();
            ~Locker();
        };

        static volatile uintptr_t s_currentOrReserved;
        
        // rely on identity hashing of string constants
        static Spectrum<const char*>* s_spectrum;
        
        static unsigned long s_noneOfTheAbove;
        
        static unsigned s_numberOfSamplesSinceDump;
    };
#else // ENABLE(SAMPLING_REGIONS)
    class SamplingRegion {
    public:
        SamplingRegion(const char*) { }
        JS_EXPORT_PRIVATE void dump();
    };
#endif // ENABLE(SAMPLING_REGIONS)

    class CodeBlock;
    class ExecState;
    class Interpreter;
    class ScopeNode;
    struct Instruction;

    struct ScriptSampleRecord {
        ScriptSampleRecord(JSGlobalData& globalData, ScriptExecutable* executable)
            : m_executable(globalData, executable)
            , m_codeBlock(0)
            , m_sampleCount(0)
            , m_opcodeSampleCount(0)
            , m_samples(0)
            , m_size(0)
        {
        }
        
        ~ScriptSampleRecord()
        {
            if (m_samples)
                free(m_samples);
        }
        
        void sample(CodeBlock*, Instruction*);

        Strong<ScriptExecutable> m_executable;
        CodeBlock* m_codeBlock;
        int m_sampleCount;
        int m_opcodeSampleCount;
        int* m_samples;
        unsigned m_size;
    };

    typedef HashMap<ScriptExecutable*, OwnPtr<ScriptSampleRecord> > ScriptSampleRecordMap;

    class SamplingThread {
    public:
        // Sampling thread state.
        static bool s_running;
        static unsigned s_hertz;
        static ThreadIdentifier s_samplingThread;

        JS_EXPORT_PRIVATE static void start(unsigned hertz=10000);
        JS_EXPORT_PRIVATE static void stop();

        static void* threadStartFunc(void*);
    };

    class SamplingTool {
    public:
        friend struct CallRecord;
        friend class HostCallRecord;
        
#if ENABLE(OPCODE_SAMPLING)
        class CallRecord {
            WTF_MAKE_NONCOPYABLE(CallRecord);
        public:
            CallRecord(SamplingTool* samplingTool)
                : m_samplingTool(samplingTool)
                , m_savedSample(samplingTool->m_sample)
                , m_savedCodeBlock(samplingTool->m_codeBlock)
            {
            }

            ~CallRecord()
            {
                m_samplingTool->m_sample = m_savedSample;
                m_samplingTool->m_codeBlock = m_savedCodeBlock;
            }

        private:
            SamplingTool* m_samplingTool;
            intptr_t m_savedSample;
            CodeBlock* m_savedCodeBlock;
        };
        
        class HostCallRecord : public CallRecord {
        public:
            HostCallRecord(SamplingTool* samplingTool)
                : CallRecord(samplingTool)
            {
                samplingTool->m_sample |= 0x1;
            }
        };
#else
        class CallRecord {
            WTF_MAKE_NONCOPYABLE(CallRecord);
        public:
            CallRecord(SamplingTool*)
            {
            }
        };

        class HostCallRecord : public CallRecord {
        public:
            HostCallRecord(SamplingTool* samplingTool)
                : CallRecord(samplingTool)
            {
            }
        };
#endif        

        SamplingTool(Interpreter* interpreter)
            : m_interpreter(interpreter)
            , m_codeBlock(0)
            , m_sample(0)
            , m_sampleCount(0)
            , m_opcodeSampleCount(0)
#if ENABLE(CODEBLOCK_SAMPLING)
            , m_scopeSampleMap(adoptPtr(new ScriptSampleRecordMap))
#endif
        {
            memset(m_opcodeSamples, 0, sizeof(m_opcodeSamples));
            memset(m_opcodeSamplesInCTIFunctions, 0, sizeof(m_opcodeSamplesInCTIFunctions));
        }

        JS_EXPORT_PRIVATE void setup();
        void dump(ExecState*);

        void notifyOfScope(JSGlobalData&, ScriptExecutable* scope);

        void sample(CodeBlock* codeBlock, Instruction* vPC)
        {
            ASSERT(!(reinterpret_cast<intptr_t>(vPC) & 0x3));
            m_codeBlock = codeBlock;
            m_sample = reinterpret_cast<intptr_t>(vPC);
        }

        CodeBlock** codeBlockSlot() { return &m_codeBlock; }
        intptr_t* sampleSlot() { return &m_sample; }

        void* encodeSample(Instruction* vPC, bool inCTIFunction = false, bool inHostFunction = false)
        {
            ASSERT(!(reinterpret_cast<intptr_t>(vPC) & 0x3));
            return reinterpret_cast<void*>(reinterpret_cast<intptr_t>(vPC) | (static_cast<intptr_t>(inCTIFunction) << 1) | static_cast<intptr_t>(inHostFunction));
        }

        static void sample();

    private:
        class Sample {
        public:
            Sample(volatile intptr_t sample, CodeBlock* volatile codeBlock)
                : m_sample(sample)
                , m_codeBlock(codeBlock)
            {
            }
            
            bool isNull() { return !m_sample; }
            CodeBlock* codeBlock() { return m_codeBlock; }
            Instruction* vPC() { return reinterpret_cast<Instruction*>(m_sample & ~0x3); }
            bool inHostFunction() { return m_sample & 0x1; }
            bool inCTIFunction() { return m_sample & 0x2; }

        private:
            intptr_t m_sample;
            CodeBlock* m_codeBlock;
        };

        void doRun();
        static SamplingTool* s_samplingTool;
        
        Interpreter* m_interpreter;
        
        // State tracked by the main thread, used by the sampling thread.
        CodeBlock* m_codeBlock;
        intptr_t m_sample;

        // Gathered sample data.
        long long m_sampleCount;
        long long m_opcodeSampleCount;
        unsigned m_opcodeSamples[numOpcodeIDs];
        unsigned m_opcodeSamplesInCTIFunctions[numOpcodeIDs];
        
#if ENABLE(CODEBLOCK_SAMPLING)
        Mutex m_scriptSampleMapMutex;
        OwnPtr<ScriptSampleRecordMap> m_scopeSampleMap;
#endif
    };

} // namespace JSC

#endif // SamplingTool_h
