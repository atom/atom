/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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

#ifndef HistoryPropertyList_h
#define HistoryPropertyList_h

#include "BinaryPropertyList.h"
#include "PlatformString.h"
#include <wtf/RetainPtr.h>

namespace WebCore {

class HistoryItem;

class HistoryPropertyListWriter : public BinaryPropertyListWriter {
public:
    RetainPtr<CFDataRef> releaseData();

protected:
    HistoryPropertyListWriter();

    void writeHistoryItem(BinaryPropertyListObjectStream&, HistoryItem*);

private:
    virtual void writeHistoryItems(BinaryPropertyListObjectStream&) = 0;

    virtual void writeObjects(BinaryPropertyListObjectStream&);
    virtual UInt8* buffer(size_t);

    const String m_dailyVisitCountsKey;
    const String m_displayTitleKey;
    const String m_lastVisitWasFailureKey;
    const String m_lastVisitWasHTTPNonGetKey;
    const String m_lastVisitedDateKey;
    const String m_redirectURLsKey;
    const String m_titleKey;
    const String m_urlKey;
    const String m_visitCountKey;
    const String m_weeklyVisitCountsKey;

    UInt8* m_buffer;
    size_t m_bufferSize;
};

}

#endif
