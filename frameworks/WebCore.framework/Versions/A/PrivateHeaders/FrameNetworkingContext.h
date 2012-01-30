/*
    Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies)

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this library; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

#ifndef FrameNetworkingContext_h
#define FrameNetworkingContext_h

#include "Frame.h"
#include "NetworkingContext.h"

namespace WebCore {

class FrameNetworkingContext : public NetworkingContext {
public:
    void invalidate()
    {
        m_frame = 0;
    }

protected:
    FrameNetworkingContext(Frame* frame)
        : m_frame(frame)
    {
    }

    Frame* frame() const { return m_frame; }

private:
    virtual bool isValid() const { return m_frame; }

    Frame* m_frame;
};

}

#endif // FrameNetworkingContext_h
