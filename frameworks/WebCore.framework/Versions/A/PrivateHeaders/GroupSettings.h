/*
 * Copyright (C) 2010 Google Inc. All rights reserved.
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
 
#ifndef GroupSettings_h
#define GroupSettings_h

#include "PlatformString.h"
#include <wtf/PassOwnPtr.h>

namespace WebCore {

class PageGroup;

class GroupSettings {
    WTF_MAKE_NONCOPYABLE(GroupSettings); WTF_MAKE_FAST_ALLOCATED;
public:
    static PassOwnPtr<GroupSettings> create()
    {
        return adoptPtr(new GroupSettings());
    }

    void setLocalStorageQuotaBytes(unsigned);
    unsigned localStorageQuotaBytes() const { return m_localStorageQuotaBytes; }

    void setIndexedDBQuotaBytes(int64_t);
    int64_t indexedDBQuotaBytes() const { return m_indexedDBQuotaBytes; }

    void setIndexedDBDatabasePath(const String&);
    const String& indexedDBDatabasePath() const { return m_indexedDBDatabasePath; }

private:
    GroupSettings();

    unsigned m_localStorageQuotaBytes;
    String m_indexedDBDatabasePath;
    int64_t m_indexedDBQuotaBytes;
};

} // namespace WebCore

#endif // GroupSettings_h
