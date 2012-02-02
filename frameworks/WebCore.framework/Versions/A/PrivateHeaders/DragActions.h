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

#ifndef DragActions_h
#define DragActions_h

#include <limits.h>

namespace WebCore {

    // WebCoreDragDestinationAction should be kept in sync with WebDragDestinationAction
    typedef enum {
        DragDestinationActionNone    = 0,
        DragDestinationActionDHTML   = 1,
        DragDestinationActionEdit    = 2,
        DragDestinationActionLoad    = 4,
        DragDestinationActionAny     = UINT_MAX
    } DragDestinationAction;
    
    // WebCoreDragSourceAction should be kept in sync with WebDragSourceAction
    typedef enum {
        DragSourceActionNone         = 0,
        DragSourceActionDHTML        = 1,
        DragSourceActionImage        = 2,
        DragSourceActionLink         = 4,
        DragSourceActionSelection    = 8,
        DragSourceActionAny          = UINT_MAX
    } DragSourceAction;
    
    //matches NSDragOperation
    typedef enum {
        DragOperationNone    = 0,
        DragOperationCopy    = 1,
        DragOperationLink    = 2,
        DragOperationGeneric = 4,
        DragOperationPrivate = 8,
        DragOperationMove    = 16,
        DragOperationDelete  = 32,
        DragOperationEvery   = UINT_MAX
    } DragOperation;
    
}

#endif // !DragActions_h
