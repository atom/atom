/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
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

#ifndef WebKitMutationObserver_h
#define WebKitMutationObserver_h

#if ENABLE(MUTATION_OBSERVERS)

#include <wtf/HashMap.h>
#include <wtf/HashSet.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>
#include <wtf/text/AtomicString.h>
#include <wtf/text/AtomicStringHash.h>

namespace WebCore {

class MutationCallback;
class MutationObserverRegistration;
class MutationRecord;
class Node;

typedef int ExceptionCode;

typedef unsigned char MutationObserverOptions;
typedef unsigned char MutationRecordDeliveryOptions;

class WebKitMutationObserver : public RefCounted<WebKitMutationObserver> {
public:
    enum MutationType {
        ChildList = 1 << 0,
        Attributes = 1 << 1,
        CharacterData = 1 << 2,

        AllMutationTypes = ChildList | Attributes | CharacterData
    };

    enum ObservationFlags  {
        Subtree = 1 << 3,
        AttributeFilter = 1 << 4
    };

    enum DeliveryFlags {
        AttributeOldValue = 1 << 5,
        CharacterDataOldValue = 1 << 6,
    };

    static PassRefPtr<WebKitMutationObserver> create(PassRefPtr<MutationCallback>);
    static void deliverAllMutations();

    ~WebKitMutationObserver();

    void observe(Node*, MutationObserverOptions, const HashSet<AtomicString>& attributeFilter, ExceptionCode&);
    void disconnect();
    void observationStarted(MutationObserverRegistration*);
    void observationEnded(MutationObserverRegistration*);
    void enqueueMutationRecord(PassRefPtr<MutationRecord>);

private:
    WebKitMutationObserver(PassRefPtr<MutationCallback>);
    void deliver();

    static bool validateOptions(MutationObserverOptions);

    RefPtr<MutationCallback> m_callback;
    Vector<RefPtr<MutationRecord> > m_records;
    HashSet<MutationObserverRegistration*> m_registrations;
};

}

#endif // ENABLE(MUTATION_OBSERVERS)

#endif // WebKitMutationObserver_h
