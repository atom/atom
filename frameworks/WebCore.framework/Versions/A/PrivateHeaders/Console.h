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

#ifndef Console_h
#define Console_h

#include "ConsoleTypes.h"
#include "DOMWindowProperty.h"
#include "ScriptCallStack.h"
#include "ScriptProfile.h"
#include "ScriptState.h"
#include <wtf/Forward.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>

namespace WebCore {

class Frame;
class MemoryInfo;
class Page;
class ScriptArguments;
class ScriptCallStack;

#if ENABLE(JAVASCRIPT_DEBUGGER)
typedef Vector<RefPtr<ScriptProfile> > ProfilesArray;
#endif

class Console : public RefCounted<Console>, public DOMWindowProperty {
public:
    static PassRefPtr<Console> create(Frame* frame) { return adoptRef(new Console(frame)); }
    virtual ~Console();

    void addMessage(MessageSource, MessageType, MessageLevel, const String& message, const String& sourceURL = String(), unsigned lineNumber = 0, PassRefPtr<ScriptCallStack> = 0);
    void addMessage(MessageSource, MessageType, MessageLevel, const String& message, PassRefPtr<ScriptCallStack>);

    void debug(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void error(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void info(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void log(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void warn(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void dir(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void dirxml(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void trace(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void assertCondition(bool condition, PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void count(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void markTimeline(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
#if ENABLE(JAVASCRIPT_DEBUGGER)
    const ProfilesArray& profiles() const { return m_profiles; }
    void profile(const String&, ScriptState*, PassRefPtr<ScriptCallStack>);
    void profileEnd(const String&, ScriptState*, PassRefPtr<ScriptCallStack>);
#endif
    void time(const String&);
    void timeEnd(const String&, PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void timeStamp(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void group(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void groupCollapsed(PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>);
    void groupEnd();

    static bool shouldPrintExceptions();
    static void setShouldPrintExceptions(bool);

    PassRefPtr<MemoryInfo> memory() const;

private:
    inline Page* page() const;
    void addMessage(MessageType, MessageLevel, PassRefPtr<ScriptArguments>, PassRefPtr<ScriptCallStack>, bool acceptNoArguments = false);

    explicit Console(Frame*);

#if ENABLE(JAVASCRIPT_DEBUGGER)
    ProfilesArray m_profiles;
#endif
};

} // namespace WebCore

#endif // Console_h
