/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
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

#ifndef CSSReflectValue_h
#define CSSReflectValue_h

#include "CSSReflectionDirection.h"
#include "CSSValue.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class CSSPrimitiveValue;

class CSSReflectValue : public CSSValue {
public:
    static PassRefPtr<CSSReflectValue> create(CSSReflectionDirection direction,
        PassRefPtr<CSSPrimitiveValue> offset, PassRefPtr<CSSValue> mask)
    {
        return adoptRef(new CSSReflectValue(direction, offset, mask));
    }

    CSSReflectionDirection direction() const { return m_direction; }
    CSSPrimitiveValue* offset() const { return m_offset.get(); }
    CSSValue* mask() const { return m_mask.get(); }

    String customCssText() const;

    void addSubresourceStyleURLs(ListHashSet<KURL>&, const CSSStyleSheet*);

private:
    CSSReflectValue(CSSReflectionDirection direction, PassRefPtr<CSSPrimitiveValue> offset, PassRefPtr<CSSValue> mask)
        : CSSValue(ReflectClass)
        , m_direction(direction)
        , m_offset(offset)
        , m_mask(mask)
    {
    }

    CSSReflectionDirection m_direction;
    RefPtr<CSSPrimitiveValue> m_offset;
    RefPtr<CSSValue> m_mask;
};

} // namespace WebCore

#endif // CSSReflectValue_h
