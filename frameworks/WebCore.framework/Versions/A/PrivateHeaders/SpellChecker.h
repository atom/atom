/*
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

#ifndef SpellChecker_h
#define SpellChecker_h

#include "Element.h"
#include "PlatformString.h"
#include "Range.h"
#include "TextChecking.h"
#include "Timer.h"
#include <wtf/Deque.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>
#include <wtf/Noncopyable.h>
#include <wtf/Vector.h>

namespace WebCore {

class Frame;
class Node;
class TextCheckerClient;
struct TextCheckingResult;

class SpellCheckRequest : public RefCounted<SpellCheckRequest> {
public:
    SpellCheckRequest(int sequence, PassRefPtr<Range> checkingRange, PassRefPtr<Range> paragraphRange, const String&, TextCheckingTypeMask);
    ~SpellCheckRequest();

    static PassRefPtr<SpellCheckRequest> create(TextCheckingTypeMask, PassRefPtr<Range> checkingRange, PassRefPtr<Range> paragraphRange);

    void setSequence(int sequence) { m_sequence = sequence; }
    int sequence() const { return m_sequence; }
    PassRefPtr<Range> checkingRange() const { return m_checkingRange; }
    PassRefPtr<Range> paragraphRange() const { return m_paragraphRange; }
    const String& text() const { return m_text; }
    TextCheckingTypeMask mask() const { return m_mask; }
    PassRefPtr<Element> rootEditableElement() const { return m_rootEditableElement; }
private:

    int m_sequence;
    RefPtr<Range> m_checkingRange;
    RefPtr<Range> m_paragraphRange;
    String m_text;
    TextCheckingTypeMask m_mask;
    RefPtr<Element> m_rootEditableElement;
};

class SpellChecker {
    WTF_MAKE_NONCOPYABLE(SpellChecker);
public:
    explicit SpellChecker(Frame*);
    ~SpellChecker();

    bool isAsynchronousEnabled() const;
    bool isCheckable(Range*) const;

    void requestCheckingFor(PassRefPtr<SpellCheckRequest>);
    void didCheck(int sequence, const Vector<TextCheckingResult>&);

    int lastRequestSequence() const
    {
        return m_lastRequestSequence;
    }

    int lastProcessedSequence() const
    {
        return m_lastProcessedSequence;
    }

private:
    typedef Deque<RefPtr<SpellCheckRequest> > RequestQueue;

    bool canCheckAsynchronously(Range*) const;
    TextCheckerClient* client() const;
    void timerFiredToProcessQueuedRequest(Timer<SpellChecker>*);
    void invokeRequest(PassRefPtr<SpellCheckRequest>);
    void enqueueRequest(PassRefPtr<SpellCheckRequest>);

    Frame* m_frame;
    int m_lastRequestSequence;
    int m_lastProcessedSequence;

    Timer<SpellChecker> m_timerToProcessQueuedRequest;

    RefPtr<SpellCheckRequest> m_processingRequest;
    RequestQueue m_requestQueue;
};

} // namespace WebCore

#endif // SpellChecker_h
