/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
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
 
#ifndef Profile_h
#define Profile_h

#include "ProfileNode.h"
#include <runtime/UString.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace JSC {

    class Profile : public RefCounted<Profile> {
    public:
        static PassRefPtr<Profile> create(const UString& title, unsigned uid);
        virtual ~Profile();

        const UString& title() const { return m_title; }
        ProfileNode* head() const { return m_head.get(); }
        void setHead(PassRefPtr<ProfileNode> head) { m_head = head; }
        double totalTime() const { return m_head->totalTime(); }
        unsigned int uid() const { return m_uid; }

        JS_EXPORT_PRIVATE void forEach(void (ProfileNode::*)());

        JS_EXPORT_PRIVATE void focus(const ProfileNode*);
        JS_EXPORT_PRIVATE void exclude(const ProfileNode*);
        JS_EXPORT_PRIVATE void restoreAll();

#ifndef NDEBUG
        void debugPrintData() const;
        void debugPrintDataSampleStyle() const;
#endif

    protected:
        Profile(const UString& title, unsigned uid);

    private:
        void removeProfileStart();
        void removeProfileEnd();
 
        UString m_title;
        RefPtr<ProfileNode> m_head;
        unsigned int m_uid;
    };

} // namespace JSC

#endif // Profile_h
