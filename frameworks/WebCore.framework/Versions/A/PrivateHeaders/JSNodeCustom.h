/*
 * Copyright (C) 2007, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef JSNodeCustom_h
#define JSNodeCustom_h

#include "JSDOMBinding.h"
#include <wtf/AlwaysInline.h>

namespace WebCore {

inline JSDOMWrapper* getInlineCachedWrapper(DOMWrapperWorld* world, Node* node)
{
    if (!world->isNormal())
        return 0;
    return node->wrapper();
}

inline bool setInlineCachedWrapper(DOMWrapperWorld* world, Node* node, JSDOMWrapper* wrapper)
{
    if (!world->isNormal())
        return false;
    ASSERT(!node->wrapper());
    node->setWrapper(*world->globalData(), wrapper, wrapperOwner(world, node), wrapperContext(world, node));
    return true;
}

inline bool clearInlineCachedWrapper(DOMWrapperWorld* world, Node* node, JSDOMWrapper* wrapper)
{
    if (!world->isNormal())
        return false;
    ASSERT_UNUSED(wrapper, node->wrapper() == wrapper);
    node->clearWrapper();
    return true;
}

JSC::JSValue createWrapper(JSC::ExecState*, JSDOMGlobalObject*, Node*);

inline JSC::JSValue toJS(JSC::ExecState* exec, JSDOMGlobalObject* globalObject, Node* node)
{
    if (!node)
        return JSC::jsNull();

    JSNode* wrapper = static_cast<JSNode*>(getCachedWrapper(currentWorld(exec), node));
    if (wrapper)
        return wrapper;

    return createWrapper(exec, globalObject, node);
}

}

#endif // JSDOMNodeCustom_h
