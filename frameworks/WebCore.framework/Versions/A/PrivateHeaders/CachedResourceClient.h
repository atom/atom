/*
    Copyright (C) 1998 Lars Knoll (knoll@mpi-hd.mpg.de)
    Copyright (C) 2001 Dirk Mueller <mueller@kde.org>
    Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011 Apple Inc. All rights reserved.

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

    This class provides all functionality needed for loading images, style sheets and html
    pages from the web. It has a memory cache for these objects.
*/

#ifndef CachedResourceClient_h
#define CachedResourceClient_h

#include <wtf/FastAllocBase.h>
#include <wtf/Forward.h>

namespace WebCore {
class CachedResource;

class CachedResourceClient {
    WTF_MAKE_FAST_ALLOCATED;
public:
    enum CachedResourceClientType {
        BaseResourceType,
        ImageType,
        FontType,
        StyleSheetType,
        RawResourceType
    };

    virtual ~CachedResourceClient() { }
    virtual void notifyFinished(CachedResource*) { }
    virtual void didReceiveData(CachedResource*) { };
    
    static CachedResourceClientType expectedType() { return BaseResourceType; }
    virtual CachedResourceClientType resourceClientType() { return expectedType(); }

protected:
    CachedResourceClient() { }
};
}

#endif
