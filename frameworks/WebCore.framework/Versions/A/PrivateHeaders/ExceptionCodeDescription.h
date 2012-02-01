/*
 * THIS FILE WAS AUTOMATICALLY GENERATED, DO NOT EDIT.
 *
 * Copyright (C) 2011 Google Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY GOOGLE, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ExceptionCodeDescription_h
#define ExceptionCodeDescription_h

namespace WebCore {

typedef int ExceptionCode;

enum ExceptionType {
    DOMCoreExceptionType,
    EventExceptionType,
#if ENABLE(BLOB)
    FileExceptionType,
#endif
#if ENABLE(INDEXED_DATABASE)
    IDBDatabaseExceptionType,
#endif
#if ENABLE(BLOB)
    OperationNotAllowedExceptionType,
#endif
    RangeExceptionType,
#if ENABLE(SQL_DATABASE)
    SQLExceptionType,
#endif
#if ENABLE(SVG)
    SVGExceptionType,
#endif
    XMLHttpRequestExceptionType,
    XPathExceptionType,
};

struct ExceptionCodeDescription {
    explicit ExceptionCodeDescription(ExceptionCode);

    // |typeName| has spaces and is suitable for use in exception
    // description strings; maximum length is 10 characters.
    const char* typeName; 

    // |name| is the exception name, also intended for use in exception
    // description strings; 0 if name not known; maximum length is 27
    // characters.
    const char* name; 

    // |description| is the exception description, intended for use in
    // exception strings. It is a more readable explanation of error.
    const char* description;

    // |code| is the numeric value of the exception within a particular type.
    int code; 

    ExceptionType type;
};

} // namespace WebCore

#endif // ExceptionCodeDescription_h
