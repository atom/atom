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

#ifndef SubstituteResource_h
#define SubstituteResource_h

#include <wtf/RefCounted.h>

#include "KURL.h"
#include "ResourceResponse.h"
#include "SharedBuffer.h"

#include <wtf/RefPtr.h>

namespace WebCore {

class SubstituteResource : public RefCounted<SubstituteResource> {
public:
    virtual ~SubstituteResource() { }

    const KURL& url() const { return m_url; }
    const ResourceResponse& response() const { return m_response; }
    SharedBuffer* data() const { return m_data.get(); }

protected:
    SubstituteResource(const KURL& url, const ResourceResponse& response, PassRefPtr<SharedBuffer> data)
        : m_url(url)
        , m_response(response)
        , m_data(data)
    {
        ASSERT(m_data);
    }
    
private:
    KURL m_url;
    ResourceResponse m_response;
    RefPtr<SharedBuffer> m_data;
};
    
}

#endif // SubstituteResource_h
