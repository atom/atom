/*
 * Copyright (C) 2010 Google Inc.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef FileStream_h
#define FileStream_h

#if ENABLE(BLOB) || ENABLE(FILE_SYSTEM)

#include "FileSystem.h"
#include <wtf/Forward.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>

namespace WebCore {

class KURL;

// All methods are synchronous.
class FileStream : public RefCounted<FileStream> {
public:
    static PassRefPtr<FileStream> create()
    {
        return adoptRef(new FileStream());
    }
    ~FileStream();

    // FIXME: To be removed when we switch to using BlobData.
    void start();

    // Aborts the operation.
    void stop();

    // Gets the size of a file. Also validates if the file has been changed or not if the expected modification time is provided, i.e. non-zero.
    // Returns total number of bytes if successful. -1 otherwise.
    long long getSize(const String& path, double expectedModificationTime);

    // Opens a file for reading. The reading starts at the specified offset and lasts till the specified length.
    // Returns true on success. False otherwise.
    bool openForRead(const String& path, long long offset, long long length);

    // Opens a file for writing.
    // Returns true on success. False otherwise.
    bool openForWrite(const String& path);

    // Closes the file.
    void close();

    // Reads a file into the provided data buffer.
    // Returns number of bytes being read on success. -1 otherwise.
    // If 0 is returned, it means that the reading is completed.
    int read(char* buffer, int length);

    // Writes a blob to the file.
    // Returns number of bytes being written on success. -1 otherwise.
    int write(const KURL& blobURL, long long position, int length);

    // Truncates the file to the specified position.
    // Returns true on success. False otherwise.
    bool truncate(long long position);

private:
    FileStream();

    PlatformFileHandle m_handle;
    long long m_bytesProcessed;
    long long m_totalBytesToRead;
};

} // namespace WebCore

#endif // ENABLE(BLOB) || ENABLE(FILE_SYSTEM)

#endif // FileStream_h
