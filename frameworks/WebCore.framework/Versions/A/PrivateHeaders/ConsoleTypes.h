/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ConsoleTypes_h
#define ConsoleTypes_h

namespace WebCore {

enum MessageSource {
    HTMLMessageSource,
    XMLMessageSource,
    JSMessageSource,
    NetworkMessageSource,
    ConsoleAPIMessageSource,
    OtherMessageSource,
};

// FIXME: make this enum private to inspector, remove it from client callbacks.
// https://bugs.webkit.org/show_bug.cgi?id=66371
enum MessageType {
    LogMessageType,
    DirMessageType,
    DirXMLMessageType,
    TraceMessageType,
    StartGroupMessageType,
    StartGroupCollapsedMessageType,
    EndGroupMessageType,
    AssertMessageType
};

enum MessageLevel {
    TipMessageLevel,
    LogMessageLevel,
    WarningMessageLevel,
    ErrorMessageLevel,
    DebugMessageLevel
};

} // namespace WebCore

#endif // ConsoleTypes_h
