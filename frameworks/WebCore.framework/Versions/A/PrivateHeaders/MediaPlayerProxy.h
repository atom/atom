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

#ifndef MediaPlayerProxy_h
#define MediaPlayerProxy_h

OBJC_CLASS WebMediaPlayerProxy;

enum MediaPlayerProxyNotificationType {

    MediaPlayerNotificationMediaValidated = 1,
    MediaPlayerNotificationMediaFailedToValidate,
    
    MediaPlayerNotificationStartUsingNetwork,
    MediaPlayerNotificationStopUsingNetwork,

    MediaPlayerNotificationEnteredFullscreen,
    MediaPlayerNotificationExitedFullscreen,
    
    MediaPlayerNotificationReadyForInspection,
    MediaPlayerNotificationReadyForPlayback,
    MediaPlayerNotificationDidPlayToTheEnd,

    MediaPlayerNotificationPlaybackFailed,

    MediaPlayerNotificationStreamLikelyToKeepUp,
    MediaPlayerNotificationStreamUnlikelyToKeepUp,
    MediaPlayerNotificationStreamBufferFull,
    MediaPlayerNotificationStreamRanDry,
    MediaPlayerNotificationFileLoaded,

    MediaPlayerNotificationSizeDidChange,
    MediaPlayerNotificationVolumeDidChange,
    MediaPlayerNotificationMutedDidChange,
    MediaPlayerNotificationTimeJumped,
    
    MediaPlayerNotificationPlayPauseButtonPressed,
};

#ifdef __OBJC__
@interface NSObject (WebMediaPlayerProxy)

- (int)_interfaceVersion;

- (void)_disconnect;

- (void)_load:(NSURL *)url;
- (void)_cancelLoad;

- (void)_setPoster:(NSURL *)url;

- (void)_play;
- (void)_pause;

- (NSSize)_naturalSize;

- (BOOL)_hasVideo;
- (BOOL)_hasAudio;

- (NSTimeInterval)_duration;

- (double)_currentTime;
- (void)_setCurrentTime:(double)time;
- (BOOL)_seeking;

- (void)_setEndTime:(double)time;

- (float)_rate;
- (void)_setRate:(float)rate;

- (float)_volume;
- (void)_setVolume:(float)newVolume;

- (BOOL)_muted;
- (void)_setMuted:(BOOL)muted;

- (float)_maxTimeBuffered;
- (float)_maxTimeSeekable;
- (NSArray *)_bufferedTimeRanges;

- (int)_dataRate;

- (BOOL)_totalBytesKnown;
- (unsigned)_totalBytes;
- (unsigned)_bytesLoaded;

- (NSArray *)_mimeTypes;

@end
#endif

#endif
