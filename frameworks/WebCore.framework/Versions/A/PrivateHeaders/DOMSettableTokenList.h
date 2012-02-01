/*
 * Copyright (C) 2010 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef DOMSettableTokenList_h
#define DOMSettableTokenList_h

#include "DOMTokenList.h"
#include "SpaceSplitString.h"
#include <wtf/PassOwnPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/text/AtomicString.h>

namespace WebCore {

typedef int ExceptionCode;

class DOMSettableTokenList : public DOMTokenList, public RefCounted<DOMSettableTokenList> {
    WTF_MAKE_FAST_ALLOCATED;
public:
    static PassRefPtr<DOMSettableTokenList> create()
    {
        return adoptRef(new DOMSettableTokenList());
    }
    virtual ~DOMSettableTokenList();

    virtual void ref() { RefCounted<DOMSettableTokenList>::ref(); }
    virtual void deref() { RefCounted<DOMSettableTokenList>::deref(); }

    virtual unsigned length() const { return m_tokens.size(); }
    virtual const AtomicString item(unsigned index) const;
    virtual bool contains(const AtomicString&, ExceptionCode&) const;
    virtual void add(const AtomicString&, ExceptionCode&);
    virtual void remove(const AtomicString&, ExceptionCode&);
    virtual bool toggle(const AtomicString&, ExceptionCode&);
    virtual String toString() const { return value(); }

    String value() const { return m_value; }
    const SpaceSplitString& tokens() const { return m_tokens; }
    void setValue(const String&);

private:
    DOMSettableTokenList();

    void removeInternal(const AtomicString&);
    void addInternal(const AtomicString&);

    String m_value;
    SpaceSplitString m_tokens;
};

} // namespace WebCore

#endif // DOMSettableTokenList_h
