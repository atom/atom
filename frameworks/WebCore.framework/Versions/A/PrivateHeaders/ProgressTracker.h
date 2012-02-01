/*
 * Copyright (C) 2007 Apple Inc.  All rights reserved.
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

#ifndef ProgressTracker_h
#define ProgressTracker_h

#include <wtf/Forward.h>
#include <wtf/HashMap.h>
#include <wtf/Noncopyable.h>
#include <wtf/OwnPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class Frame;
class ResourceResponse;
struct ProgressItem;

class ProgressTracker {
    WTF_MAKE_NONCOPYABLE(ProgressTracker); WTF_MAKE_FAST_ALLOCATED;
public:
    ~ProgressTracker();

    static PassOwnPtr<ProgressTracker> create();
    static unsigned long createUniqueIdentifier();

    double estimatedProgress() const;

    void progressStarted(Frame*);
    void progressCompleted(Frame*);
    
    void incrementProgress(unsigned long identifier, const ResourceResponse&);
    void incrementProgress(unsigned long identifier, const char*, int);
    void completeProgress(unsigned long identifier);

    long long totalPageAndResourceBytesToLoad() const { return m_totalPageAndResourceBytesToLoad; }
    long long totalBytesReceived() const { return m_totalBytesReceived; }

private:
    ProgressTracker();

    void reset();
    void finalProgressComplete();
    
    static unsigned long s_uniqueIdentifier;
    
    long long m_totalPageAndResourceBytesToLoad;
    long long m_totalBytesReceived;
    double m_lastNotifiedProgressValue;
    double m_lastNotifiedProgressTime;
    double m_progressNotificationInterval;
    double m_progressNotificationTimeInterval;
    bool m_finalProgressChangedSent;    
    double m_progressValue;
    RefPtr<Frame> m_originatingProgressFrame;
    
    int m_numProgressTrackedFrames;
    HashMap<unsigned long, OwnPtr<ProgressItem> > m_progressItems;
};
    
}

#endif
