/*
 * Copyright (C) 2008, 2009 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef LegacyWebArchive_h
#define LegacyWebArchive_h

#include "Archive.h"

namespace WebCore {

class Frame;
class Node;
class Range;

class LegacyWebArchive : public Archive {
public:
    static PassRefPtr<LegacyWebArchive> create();
    static PassRefPtr<LegacyWebArchive> create(SharedBuffer*);
    static PassRefPtr<LegacyWebArchive> create(const KURL&, SharedBuffer*);
    static PassRefPtr<LegacyWebArchive> create(PassRefPtr<ArchiveResource> mainResource, Vector<PassRefPtr<ArchiveResource> >& subresources, Vector<PassRefPtr<LegacyWebArchive> >& subframeArchives);
    static PassRefPtr<LegacyWebArchive> create(Node*);
    static PassRefPtr<LegacyWebArchive> create(Frame*);
    static PassRefPtr<LegacyWebArchive> createFromSelection(Frame*);
    static PassRefPtr<LegacyWebArchive> create(Range*);

    virtual Type type() const;

    RetainPtr<CFDataRef> rawDataRepresentation();

private:
    LegacyWebArchive() { }

    enum MainResourceStatus { Subresource, MainResource };

    static PassRefPtr<LegacyWebArchive> create(const String& markupString, Frame*, const Vector<Node*>& nodes);
    static PassRefPtr<ArchiveResource> createResource(CFDictionaryRef);
    static ResourceResponse createResourceResponseFromMacArchivedData(CFDataRef);
    static ResourceResponse createResourceResponseFromPropertyListData(CFDataRef, CFStringRef responseDataType);
    static RetainPtr<CFDataRef> createPropertyListRepresentation(const ResourceResponse&);
    static RetainPtr<CFDictionaryRef> createPropertyListRepresentation(Archive*);
    static RetainPtr<CFDictionaryRef> createPropertyListRepresentation(ArchiveResource*, MainResourceStatus);

    bool extract(CFDictionaryRef);
};

}

#endif // Archive
