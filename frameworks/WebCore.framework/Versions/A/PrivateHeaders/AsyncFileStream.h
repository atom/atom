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

#ifndef AsyncFileStream_h
#define AsyncFileStream_h

#if ENABLE(BLOB) || ENABLE(FILE_SYSTEM)

#include "FileStreamClient.h"
#include <wtf/Forward.h>
#include <wtf/RefCounted.h>

namespace WebCore {

class KURL;

class AsyncFileStream : public RefCounted<AsyncFileStream> {
public:
    virtual ~AsyncFileStream() { }

    virtual void getSize(const String& path, double expectedModificationTime) = 0;
    virtual void openForRead(const String& path, long long offset, long long length) = 0;
    virtual void openForWrite(const String& path) = 0;
    virtual void close() = 0;
    virtual void read(char* buffer, int length) = 0;
    virtual void write(const KURL& blobURL, long long position, int length) = 0;
    virtual void truncate(long long position) = 0;
    virtual void stop() = 0;

    FileStreamClient* client() const { return m_client; }
    void setClient(FileStreamClient* client) { m_client = client; }

protected:
    AsyncFileStream(FileStreamClient* client)
        : m_client(client)
    {
    }

private:
    FileStreamClient* m_client;
};

} // namespace WebCore

#endif // ENABLE(BLOB) || ENABLE(FILE_SYSTEM)

#endif // AsyncFileStream_h
