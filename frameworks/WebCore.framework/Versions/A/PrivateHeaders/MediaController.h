/*
 * Copyright (C) 2011 Apple Inc.  All rights reserved.
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

#ifndef MediaController_h
#define MediaController_h

#if ENABLE(VIDEO)

#include "ActiveDOMObject.h"
#include "Event.h"
#include "EventListener.h"
#include "EventTarget.h"
#include "MediaControllerInterface.h"
#include "Timer.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/Vector.h>

namespace WebCore {

class Clock;
class HTMLMediaElement;
class Event;
class ScriptExecutionContext;

class MediaController : public RefCounted<MediaController>, public MediaControllerInterface, public EventTarget {
public:
    static PassRefPtr<MediaController> create(ScriptExecutionContext*);
    virtual ~MediaController();

    void addMediaElement(HTMLMediaElement*);
    void removeMediaElement(HTMLMediaElement*);
    bool containsMediaElement(HTMLMediaElement*) const;

    const String& mediaGroup() const { return m_mediaGroup; }
    
    virtual PassRefPtr<TimeRanges> buffered() const;
    virtual PassRefPtr<TimeRanges> seekable() const;
    virtual PassRefPtr<TimeRanges> played();
    
    virtual float duration() const;
    virtual float currentTime() const;
    virtual void setCurrentTime(float, ExceptionCode&);
    
    virtual bool paused() const { return m_paused; }
    virtual void play();
    virtual void pause();
    
    virtual float defaultPlaybackRate() const { return m_defaultPlaybackRate; }
    virtual void setDefaultPlaybackRate(float);
    
    virtual float playbackRate() const;
    virtual void setPlaybackRate(float);
    
    virtual float volume() const { return m_volume; }
    virtual void setVolume(float, ExceptionCode&);
    
    virtual bool muted() const { return m_muted; }
    virtual void setMuted(bool);
    
    virtual ReadyState readyState() const { return m_readyState; }

    enum PlaybackState { WAITING, PLAYING, ENDED };
    virtual PlaybackState playbackState() const { return m_playbackState; }

    virtual bool supportsFullscreen() const { return false; }
    virtual bool isFullscreen() const { return false; }
    virtual void enterFullscreen() { }

    virtual bool hasAudio() const;
    virtual bool hasVideo() const;
    virtual bool hasClosedCaptions() const;
    virtual void setClosedCaptionsVisible(bool);
    virtual bool closedCaptionsVisible() const { return m_closedCaptionsVisible; }
    
    virtual bool supportsScanning() const;
    
    virtual void beginScrubbing();
    virtual void endScrubbing();
    
    virtual bool canPlay() const;
    
    virtual bool isLiveStream() const;
    
    virtual bool hasCurrentSrc() const;
    
    virtual void returnToRealtime();

    bool isBlocked() const;

    // EventTarget
    using RefCounted<MediaController>::ref;
    using RefCounted<MediaController>::deref;

private:
    MediaController(ScriptExecutionContext*);
    void reportControllerState();
    void updateReadyState();
    void updatePlaybackState();
    void updateMediaElements();
    void bringElementUpToSpeed(HTMLMediaElement*);
    void scheduleEvent(const AtomicString& eventName);
    void asyncEventTimerFired(Timer<MediaController>*);
    bool hasEnded() const;

    // EventTarget
    virtual void refEventTarget() { ref(); }
    virtual void derefEventTarget() { deref(); }
    virtual const AtomicString& interfaceName() const;
    virtual ScriptExecutionContext* scriptExecutionContext() const { return m_scriptExecutionContext; };
    virtual EventTargetData* eventTargetData() { return &m_eventTargetData; }
    virtual EventTargetData* ensureEventTargetData() { return &m_eventTargetData; }
    EventTargetData m_eventTargetData;

    friend class HTMLMediaElement;
    friend class MediaControllerEventListener;
    Vector<HTMLMediaElement*> m_mediaElements;
    bool m_paused;
    float m_defaultPlaybackRate;
    float m_volume;
    bool m_muted;
    ReadyState m_readyState;
    PlaybackState m_playbackState;
    Vector<RefPtr<Event> > m_pendingEvents;
    Timer<MediaController> m_asyncEventTimer;
    String m_mediaGroup;
    bool m_closedCaptionsVisible;
    PassRefPtr<Clock> m_clock;
    ScriptExecutionContext* m_scriptExecutionContext;
};

} // namespace WebCore

#endif
#endif
