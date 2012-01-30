/*
 * Copyright (C) 2010 Google Inc. All rights reserved.
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

#ifndef FormSubmission_h
#define FormSubmission_h

#include "FormState.h"
#include "KURL.h"

namespace WebCore {

class Document;
class Event;
class FormData;
struct FrameLoadRequest;
class HTMLFormElement;
class TextEncoding;

class FormSubmission : public RefCounted<FormSubmission> {
public:
    enum Method { GetMethod, PostMethod };

    class Attributes {
        WTF_MAKE_NONCOPYABLE(Attributes);
    public:
        Attributes()
            : m_method(GetMethod)
            , m_isMultiPartForm(false)
            , m_encodingType("application/x-www-form-urlencoded")
        {
        }

        Method method() const { return m_method; }
        static Method parseMethodType(const String&);
        void updateMethodType(const String&);
        static String methodString(Method method) { return method == PostMethod ? "post" : "get"; }

        const String& action() const { return m_action; }
        void parseAction(const String&);

        const String& target() const { return m_target; }
        void setTarget(const String& target) { m_target = target; }

        const String& encodingType() const { return m_encodingType; }
        static String parseEncodingType(const String&);
        void updateEncodingType(const String&);
        bool isMultiPartForm() const { return m_isMultiPartForm; }

        const String& acceptCharset() const { return m_acceptCharset; }
        void setAcceptCharset(const String& value) { m_acceptCharset = value; }

        void copyFrom(const Attributes&);

    private:
        Method m_method;
        bool m_isMultiPartForm;

        String m_action;
        String m_target;
        String m_encodingType;
        String m_acceptCharset;
    };

    static PassRefPtr<FormSubmission> create(HTMLFormElement*, const Attributes&, PassRefPtr<Event> event, bool lockHistory, FormSubmissionTrigger);

    void populateFrameLoadRequest(FrameLoadRequest&);
    
    KURL requestURL() const;

    Method method() const { return m_method; }
    const KURL& action() const { return m_action; }
    const String& target() const { return m_target; }
    void clearTarget() { m_target = String(); }
    const String& contentType() const { return m_contentType; }
    FormState* state() const { return m_formState.get(); }
    FormData* data() const { return m_formData.get(); }
    const String boundary() const { return m_boundary; }
    bool lockHistory() const { return m_lockHistory; }
    Event* event() const { return m_event.get(); }

    const String& referrer() const { return m_referrer; }
    void setReferrer(const String& referrer) { m_referrer = referrer; }
    const String& origin() const { return m_origin; }
    void setOrigin(const String& origin) { m_origin = origin; }

private:
    FormSubmission(Method, const KURL& action, const String& target, const String& contentType, PassRefPtr<FormState>, PassRefPtr<FormData>, const String& boundary, bool lockHistory, PassRefPtr<Event>);

    // FIXME: Hold an instance of Attributes instead of individual members.
    Method m_method;
    KURL m_action;
    String m_target;
    String m_contentType;
    RefPtr<FormState> m_formState;
    RefPtr<FormData> m_formData;
    String m_boundary;
    bool m_lockHistory;
    RefPtr<Event> m_event;
    String m_referrer;
    String m_origin;
};

}

#endif // FormSubmission_h
