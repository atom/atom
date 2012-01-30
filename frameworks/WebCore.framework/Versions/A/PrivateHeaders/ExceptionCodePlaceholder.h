/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
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

#ifndef ExceptionCodePlaceholder_h
#define ExceptionCodePlaceholder_h

#include <wtf/Assertions.h>
#include <wtf/Noncopyable.h>

namespace WebCore {

typedef int ExceptionCode;

class ExceptionCodePlaceholder {
    WTF_MAKE_NONCOPYABLE(ExceptionCodePlaceholder);
public:
    ExceptionCodePlaceholder() { }
    explicit ExceptionCodePlaceholder(ExceptionCode);

    operator ExceptionCode& () const { return m_code; }

protected:
    mutable ExceptionCode m_code;
};

inline ExceptionCodePlaceholder::ExceptionCodePlaceholder(ExceptionCode code)
    : m_code(code)
{
}

class IgnorableExceptionCode : public ExceptionCodePlaceholder {
};

#if ASSERT_DISABLED

#define ASSERT_NO_EXCEPTION ::WebCore::IgnorableExceptionCode()

#else

class NoExceptionAssertionChecker : public ExceptionCodePlaceholder {
public:
    NoExceptionAssertionChecker(const char* file, int line);
    ~NoExceptionAssertionChecker();

private:
    const char* m_file;
    int m_line;
};

#define ASSERT_NO_EXCEPTION ::WebCore::NoExceptionAssertionChecker(__FILE__, __LINE__)

#endif

}

#endif
