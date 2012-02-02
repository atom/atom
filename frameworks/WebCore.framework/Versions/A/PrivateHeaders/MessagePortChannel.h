/*
 * Copyright (C) 2009 Google Inc. All rights reserved.
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

#ifndef MessagePortChannel_h
#define MessagePortChannel_h

#include "PlatformString.h"

#include "SerializedScriptValue.h"

#include <wtf/OwnPtr.h>
#include <wtf/Forward.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace WebCore {

    class MessagePort;
    class MessagePortChannel;
    class PlatformMessagePortChannel;
    class ScriptExecutionContext;
    class SerializedScriptValue;

    // The overwhelmingly common case is sending a single port, so handle that efficiently with an inline buffer of size 1.
    typedef Vector<OwnPtr<MessagePortChannel>, 1> MessagePortChannelArray;

    // MessagePortChannel is a platform-independent interface to the remote side of a message channel.
    // It acts as a wrapper around the platform-dependent PlatformMessagePortChannel implementation which ensures that the platform-dependent close() method is invoked before destruction.
    class MessagePortChannel {
        WTF_MAKE_NONCOPYABLE(MessagePortChannel); WTF_MAKE_FAST_ALLOCATED;
    public:
        static void createChannel(PassRefPtr<MessagePort>, PassRefPtr<MessagePort>);

        // Creates a new wrapper for the passed channel.
        static PassOwnPtr<MessagePortChannel> create(PassRefPtr<PlatformMessagePortChannel>);

        // Entangles the channel with a port (called when a port has been cloned, after the clone has been marshaled to its new owning thread and is ready to receive messages).
        // Returns false if the entanglement failed because the port was closed.
        bool entangleIfOpen(MessagePort*);

        // Disentangles the channel from a given port so it no longer forwards messages to the port. Called when the port is being cloned and no new owning thread has yet been established.
        void disentangle();

        // Closes the port (ensures that no further messages can be added to either queue).
        void close();

        // Used by MessagePort.postMessage() to prevent callers from passing a port's own entangled port.
        bool isConnectedTo(MessagePort*);

        // Returns true if the proxy currently contains messages for this port.
        bool hasPendingActivity();

        class EventData {
            WTF_MAKE_NONCOPYABLE(EventData); WTF_MAKE_FAST_ALLOCATED;
        public:
            static PassOwnPtr<EventData> create(PassRefPtr<SerializedScriptValue>, PassOwnPtr<MessagePortChannelArray>);

            SerializedScriptValue* message() { return m_message.get(); }
            PassOwnPtr<MessagePortChannelArray> channels() { return m_channels.release(); }

        private:
            EventData(PassRefPtr<SerializedScriptValue> message, PassOwnPtr<MessagePortChannelArray>);
            RefPtr<SerializedScriptValue> m_message;
            OwnPtr<MessagePortChannelArray> m_channels;
        };

        // Sends a message and optional cloned port to the remote port.
        void postMessageToRemote(PassOwnPtr<EventData>);

        // Extracts a message from the message queue for this port.
        bool tryGetMessageFromRemote(OwnPtr<EventData>&);

        // Returns the entangled port if run by the same thread (see MessagePort::locallyEntangledPort() for more details).
        MessagePort* locallyEntangledPort(const ScriptExecutionContext*);

        ~MessagePortChannel();

        PlatformMessagePortChannel* channel() const { return m_channel.get(); }

    private:
        MessagePortChannel(PassRefPtr<PlatformMessagePortChannel>);
        RefPtr<PlatformMessagePortChannel> m_channel;
    };

} // namespace WebCore

#endif // MessagePortChannel_h
