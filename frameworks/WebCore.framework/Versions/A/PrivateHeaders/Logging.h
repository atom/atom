/*
 * Copyright (C) 2003, 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef Logging_h
#define Logging_h

#include <wtf/Assertions.h>
#include <wtf/Forward.h>

#ifndef LOG_CHANNEL_PREFIX
#define LOG_CHANNEL_PREFIX Log
#endif

namespace WebCore {

    extern WTFLogChannel LogNotYetImplemented;
    extern WTFLogChannel LogFrames;
    extern WTFLogChannel LogLoading;
    extern WTFLogChannel LogPopupBlocking;
    extern WTFLogChannel LogEvents;
    extern WTFLogChannel LogEditing;
    extern WTFLogChannel LogLiveConnect;
    extern WTFLogChannel LogIconDatabase;
    extern WTFLogChannel LogSQLDatabase;
    extern WTFLogChannel LogSpellingAndGrammar;
    extern WTFLogChannel LogBackForward;
    extern WTFLogChannel LogHistory;
    extern WTFLogChannel LogPageCache;
    extern WTFLogChannel LogPlatformLeaks;
    extern WTFLogChannel LogResourceLoading;
    extern WTFLogChannel LogNetwork;
    extern WTFLogChannel LogFTP;
    extern WTFLogChannel LogThreading;
    extern WTFLogChannel LogStorageAPI;
    extern WTFLogChannel LogMedia;
    extern WTFLogChannel LogPlugins;
    extern WTFLogChannel LogArchives;
    extern WTFLogChannel LogProgress;
    extern WTFLogChannel LogFileAPI;
    extern WTFLogChannel LogWebAudio;

    void initializeLoggingChannelsIfNecessary();
    WTFLogChannel* getChannelFromName(const String& channelName);
}

#endif // Logging_h
