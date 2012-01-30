/*
 * Copyright (C) 2007 Apple Inc. All rights reserved.
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

#ifndef SQLError_h
#define SQLError_h

#if ENABLE(SQL_DATABASE)

#include "PlatformString.h"
#include <wtf/ThreadSafeRefCounted.h>

namespace WebCore {

class SQLError : public ThreadSafeRefCounted<SQLError> {
public:
    static PassRefPtr<SQLError> create(unsigned code, const String& message) { return adoptRef(new SQLError(code, message)); }
    static PassRefPtr<SQLError> create(unsigned code, const char* message, int sqliteCode)
    {
        return create(code, String::format("%s (%d)", message, sqliteCode));
    }
    static PassRefPtr<SQLError> create(unsigned code, const char* message, int sqliteCode, const char* sqliteMessage)
    {
        return create(code, String::format("%s (%d %s)", message, sqliteCode, sqliteMessage));
    }

    unsigned code() const { return m_code; }
    String message() const { return m_message.isolatedCopy(); }

    enum SQLErrorCode {
        UNKNOWN_ERR = 0,
        DATABASE_ERR = 1,
        VERSION_ERR = 2,
        TOO_LARGE_ERR = 3,
        QUOTA_ERR = 4,
        SYNTAX_ERR = 5,
        CONSTRAINT_ERR = 6,
        TIMEOUT_ERR = 7
    };

private:
    SQLError(unsigned code, const String& message) : m_code(code), m_message(message.isolatedCopy()) { }
    unsigned m_code;
    String m_message;
};

}

#endif

#endif // SQLError_h
