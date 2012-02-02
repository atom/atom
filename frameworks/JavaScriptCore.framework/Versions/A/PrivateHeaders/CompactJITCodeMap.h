/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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

#ifndef CompactJITCodeMap_h
#define CompactJITCodeMap_h

#include <wtf/Assertions.h>
#include <wtf/FastAllocBase.h>
#include <wtf/FastMalloc.h>
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/UnusedParam.h>
#include <wtf/Vector.h>

namespace JSC {

// Gives you a compressed map between between bytecode indices and machine code
// entry points. The compression simply tries to use either 1, 2, or 4 bytes for
// any given offset. The largest offset that can be stored is 2^30.

// Example use:
//
// CompactJITCodeMap::Encoder encoder(map);
// encoder.append(a, b);
// encoder.append(c, d); // preconditions: c >= a, d >= b
// OwnPtr<CompactJITCodeMap> map = encoder.finish();
//
// At some later time:
//
// Vector<BytecodeAndMachineOffset> decoded;
// map->decode(decoded);

struct BytecodeAndMachineOffset {
    BytecodeAndMachineOffset() { }
    
    BytecodeAndMachineOffset(unsigned bytecodeIndex, unsigned machineCodeOffset)
        : m_bytecodeIndex(bytecodeIndex)
        , m_machineCodeOffset(machineCodeOffset)
    {
    }
    
    unsigned m_bytecodeIndex;
    unsigned m_machineCodeOffset;
    
    static inline unsigned getBytecodeIndex(BytecodeAndMachineOffset* mapping)
    {
        return mapping->m_bytecodeIndex;
    }
    
    static inline unsigned getMachineCodeOffset(BytecodeAndMachineOffset* mapping)
    {
        return mapping->m_machineCodeOffset;
    }
};

class CompactJITCodeMap {
    WTF_MAKE_FAST_ALLOCATED;
public:
    ~CompactJITCodeMap()
    {
        if (m_buffer)
            fastFree(m_buffer);
    }
    
    unsigned numberOfEntries() const
    {
        return m_numberOfEntries;
    }
    
    void decode(Vector<BytecodeAndMachineOffset>& result) const;
    
private:
    CompactJITCodeMap(uint8_t* buffer, unsigned size, unsigned numberOfEntries)
        : m_buffer(buffer)
#if !ASSERT_DISABLED
        , m_size(size)
#endif
        , m_numberOfEntries(numberOfEntries)
    {
        UNUSED_PARAM(size);
    }
    
    uint8_t at(unsigned index) const
    {
        ASSERT(index < m_size);
        return m_buffer[index];
    }
    
    unsigned decodeNumber(unsigned& index) const
    {
        uint8_t headValue = at(index++);
        if (!(headValue & 128))
            return headValue;
        if (!(headValue & 64))
            return (static_cast<unsigned>(headValue & ~128) << 8) | at(index++);
        unsigned second = at(index++);
        unsigned third  = at(index++);
        unsigned fourth = at(index++);
        return (static_cast<unsigned>(headValue & ~(128 + 64)) << 24) | (second << 16) | (third << 8) | fourth;
    }
    
    uint8_t* m_buffer;
#if !ASSERT_DISABLED
    unsigned m_size;
#endif
    unsigned m_numberOfEntries;
    
public:
    class Encoder {
        WTF_MAKE_NONCOPYABLE(Encoder);
    public:
        Encoder();
        ~Encoder();
        
        void ensureCapacityFor(unsigned numberOfEntriesToAdd);
        void append(unsigned bytecodeIndex, unsigned machineCodeOffset);
        PassOwnPtr<CompactJITCodeMap> finish();
        
    private:
        void appendByte(uint8_t value);
        void encodeNumber(uint32_t value);
    
        uint8_t* m_buffer;
        unsigned m_size;
        unsigned m_capacity;
        unsigned m_numberOfEntries;
        
        unsigned m_previousBytecodeIndex;
        unsigned m_previousMachineCodeOffset;
    };
    
    class Decoder {
        WTF_MAKE_NONCOPYABLE(Decoder);
    public:
        Decoder(const CompactJITCodeMap*);
        
        unsigned numberOfEntriesRemaining() const;
        void read(unsigned& bytecodeIndex, unsigned& machineCodeOffset);
        
    private:
        const CompactJITCodeMap* m_jitCodeMap;
        unsigned m_previousBytecodeIndex;
        unsigned m_previousMachineCodeOffset;
        unsigned m_numberOfEntriesRemaining;
        unsigned m_bufferIndex;
    };

private:
    friend class Encoder;
    friend class Decoder;
};

inline void CompactJITCodeMap::decode(Vector<BytecodeAndMachineOffset>& result) const
{
    Decoder decoder(this);
    result.resize(decoder.numberOfEntriesRemaining());
    for (unsigned i = 0; i < result.size(); ++i)
        decoder.read(result[i].m_bytecodeIndex, result[i].m_machineCodeOffset);
    
    ASSERT(!decoder.numberOfEntriesRemaining());
}

inline CompactJITCodeMap::Encoder::Encoder()
    : m_buffer(0)
    , m_size(0)
    , m_capacity(0)
    , m_numberOfEntries(0)
    , m_previousBytecodeIndex(0)
    , m_previousMachineCodeOffset(0)
{
}

inline CompactJITCodeMap::Encoder::~Encoder()
{
    if (m_buffer)
        fastFree(m_buffer);
}
        
inline void CompactJITCodeMap::Encoder::append(unsigned bytecodeIndex, unsigned machineCodeOffset)
{
    ASSERT(bytecodeIndex >= m_previousBytecodeIndex);
    ASSERT(machineCodeOffset >= m_previousMachineCodeOffset);
    ensureCapacityFor(1);
    encodeNumber(bytecodeIndex - m_previousBytecodeIndex);
    encodeNumber(machineCodeOffset - m_previousMachineCodeOffset);
    m_previousBytecodeIndex = bytecodeIndex;
    m_previousMachineCodeOffset = machineCodeOffset;
    m_numberOfEntries++;
}

inline PassOwnPtr<CompactJITCodeMap> CompactJITCodeMap::Encoder::finish()
{
    m_capacity = m_size;
    m_buffer = static_cast<uint8_t*>(fastRealloc(m_buffer, m_capacity));
    OwnPtr<CompactJITCodeMap> result = adoptPtr(new CompactJITCodeMap(m_buffer, m_size, m_numberOfEntries));
    m_buffer = 0;
    m_size = 0;
    m_capacity = 0;
    m_numberOfEntries = 0;
    m_previousBytecodeIndex = 0;
    m_previousMachineCodeOffset = 0;
    return result.release();
}
        
inline void CompactJITCodeMap::Encoder::appendByte(uint8_t value)
{
    ASSERT(m_size + 1 <= m_capacity);
    m_buffer[m_size++] = value;
}
    
inline void CompactJITCodeMap::Encoder::encodeNumber(uint32_t value)
{
    ASSERT(m_size + 4 <= m_capacity);
    ASSERT(value < (1 << 30));
    if (value <= 127) {
        uint8_t headValue = static_cast<uint8_t>(value);
        ASSERT(!(headValue & 128));
        appendByte(headValue);
    } else if (value <= 16383) {
        uint8_t headValue = static_cast<uint8_t>(value >> 8);
        ASSERT(!(headValue & 128));
        ASSERT(!(headValue & 64));
        appendByte(headValue | 128);
        appendByte(static_cast<uint8_t>(value));
    } else {
        uint8_t headValue = static_cast<uint8_t>(value >> 24);
        ASSERT(!(headValue & 128));
        ASSERT(!(headValue & 64));
        appendByte(headValue | 128 | 64);
        appendByte(static_cast<uint8_t>(value >> 16));
        appendByte(static_cast<uint8_t>(value >> 8));
        appendByte(static_cast<uint8_t>(value));
    }
}

inline void CompactJITCodeMap::Encoder::ensureCapacityFor(unsigned numberOfEntriesToAdd)
{
    unsigned capacityNeeded = m_size + numberOfEntriesToAdd * 2 * 4;
    if (capacityNeeded > m_capacity) {
        m_capacity = capacityNeeded * 2;
        m_buffer = static_cast<uint8_t*>(fastRealloc(m_buffer, m_capacity));
    }
}

inline CompactJITCodeMap::Decoder::Decoder(const CompactJITCodeMap* jitCodeMap)
    : m_jitCodeMap(jitCodeMap)
    , m_previousBytecodeIndex(0)
    , m_previousMachineCodeOffset(0)
    , m_numberOfEntriesRemaining(jitCodeMap->m_numberOfEntries)
    , m_bufferIndex(0)
{
}

inline unsigned CompactJITCodeMap::Decoder::numberOfEntriesRemaining() const
{
    ASSERT(m_numberOfEntriesRemaining || m_bufferIndex == m_jitCodeMap->m_size);
    return m_numberOfEntriesRemaining;
}

inline void CompactJITCodeMap::Decoder::read(unsigned& bytecodeIndex, unsigned& machineCodeOffset)
{
    ASSERT(numberOfEntriesRemaining());
    
    m_previousBytecodeIndex += m_jitCodeMap->decodeNumber(m_bufferIndex);
    m_previousMachineCodeOffset += m_jitCodeMap->decodeNumber(m_bufferIndex);
    bytecodeIndex = m_previousBytecodeIndex;
    machineCodeOffset = m_previousMachineCodeOffset;
    m_numberOfEntriesRemaining--;
}

} // namespace JSC

#endif // CompactJITCodeMap_h
