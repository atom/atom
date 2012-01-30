/*
 * Copyright (C) 2011 Google Inc. All Rights Reserved.
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
 *  THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS'' AND ANY
 *  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *  DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 *  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 *  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef StyleGridData_h
#define StyleGridData_h

#if ENABLE(CSS_GRID_LAYOUT)

#include "Length.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/Vector.h>

namespace WebCore {

class StyleGridData : public RefCounted<StyleGridData> {
public:
    static PassRefPtr<StyleGridData> create() { return adoptRef(new StyleGridData); }
    PassRefPtr<StyleGridData> copy() const { return adoptRef(new StyleGridData(*this)); }

    bool operator==(const StyleGridData& o) const
    {
        return m_gridColumns == o.m_gridColumns && m_gridRows == o.m_gridRows;
    }

    bool operator!=(const StyleGridData& o) const
    {
        return !(*this == o);
    }

    // FIXME: For the moment, we only support a subset of the grammar which correspond to:
    // 'auto' | <length> | <percentage> | 'none'
    Vector<Length> m_gridColumns;
    Vector<Length> m_gridRows;

private:
    StyleGridData();
    StyleGridData(const StyleGridData&);
};

} // namespace WebCore

#endif // ENABLE(CSS_LAYOUT_GRID)

#endif // StyleGridData_h
