/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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

#ifndef BinaryPropertyList_h
#define BinaryPropertyList_h

#include <CoreFoundation/CoreFoundation.h>

#include <wtf/Forward.h>
#include <wtf/Vector.h>

namespace WebCore {

// Writes a limited subset of binary property lists.
// Covers only what's needed for writing browser history as of this writing.
class BinaryPropertyListObjectStream {
public:
    // Call writeBooleanTrue to write the boolean true value.
    // A single shared object will be used in the serialized list.
    virtual void writeBooleanTrue() = 0;

    // Call writeInteger to write an integer value.
    // A single shared object will be used for each integer in the serialized list.
    virtual void writeInteger(int) = 0;

    // Call writeString to write a string value.
    // A single shared object will be used for each string in the serialized list.
    virtual void writeString(const String&) = 0;

    // Call writeUniqueString instead of writeString when it's unlikely the
    // string will be written twice in the same property list; this saves hash
    // table overhead for such strings. A separate object will be used for each
    // of these strings in the serialized list.
    virtual void writeUniqueString(const String&) = 0;
    virtual void writeUniqueString(const char*) = 0;

    // Call writeIntegerArray instead of writeArrayStart/writeArrayEnd for
    // arrays entirely composed of integers. A single shared object will be used
    // for each identical array in the serialized list. Warning: The integer
    // pointer must remain valid until the writeBinaryPropertyList function
    // returns, because these lists are put into a hash table without copying
    // them -- that's OK if the client already has a Vector<int>.
    virtual void writeIntegerArray(const int*, size_t) = 0;

    // After calling writeArrayStart, write array elements.
    // Then call writeArrayEnd, passing in the result from writeArrayStart.
    // A separate object will be used for each of these arrays in the serialized list.
    virtual size_t writeArrayStart() = 0;
    virtual void writeArrayEnd(size_t resultFromWriteArrayStart) = 0;

    // After calling writeDictionaryStart, write all keys, then all values.
    // Then call writeDictionaryEnd, passing in the result from writeDictionaryStart.
    // A separate object will be used for each dictionary in the serialized list.
    virtual size_t writeDictionaryStart() = 0;
    virtual void writeDictionaryEnd(size_t resultFromWriteDictionaryStart) = 0;

protected:
    virtual ~BinaryPropertyListObjectStream() { }
};

class BinaryPropertyListWriter {
public:
    // Calls writeObjects once to prepare for writing and determine how big a
    // buffer is required. Then calls buffer to get the appropriately-sized
    // buffer, then calls writeObjects a second time and writes the property list.
    void writePropertyList();

protected:
    virtual ~BinaryPropertyListWriter() { }

private:
    // Called by writePropertyList.
    // Must call the object stream functions for the objects to be written
    // into the property list.
    virtual void writeObjects(BinaryPropertyListObjectStream&) = 0;

    // Called by writePropertyList.
    // Returns the buffer that the writer should write into.
    virtual UInt8* buffer(size_t) = 0;

    friend class BinaryPropertyListPlan;
    friend class BinaryPropertyListSerializer;
};

}

#endif
