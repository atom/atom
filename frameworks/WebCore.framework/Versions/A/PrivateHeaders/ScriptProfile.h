/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2010 Google Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
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

#ifndef ScriptProfile_h
#define ScriptProfile_h

#if ENABLE(JAVASCRIPT_DEBUGGER)
#include "ScriptProfileNode.h"
#include <wtf/Forward.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace JSC {
class Profile;
}

namespace WebCore {

class InspectorObject;

class ScriptProfile : public RefCounted<ScriptProfile> {
public:
    static PassRefPtr<ScriptProfile> create(PassRefPtr<JSC::Profile> profile);
    virtual ~ScriptProfile();

    String title() const;
    unsigned int uid() const;
    ScriptProfileNode* head() const;
    PassRefPtr<ScriptProfileNode> bottomUpHead() const;

#if ENABLE(INSPECTOR)
    PassRefPtr<InspectorObject> buildInspectorObjectForHead() const;
    PassRefPtr<InspectorObject> buildInspectorObjectForBottomUpHead() const;
#endif

private:
    ScriptProfile(PassRefPtr<JSC::Profile> profile);

    RefPtr<JSC::Profile> m_profile;
};


} // namespace WebCore

#endif // ENABLE(JAVASCRIPT_DEBUGGER)

#endif // ScriptProfile_h
