/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2007, 2008, 2009 Apple Inc. All rights reserved.
 *  Copyright (C) 2009 Torch Mobile, Inc.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#ifndef RegExp_h
#define RegExp_h

#include "UString.h"
#include "ExecutableAllocator.h"
#include "Structure.h"
#include "RegExpKey.h"
#include "yarr/Yarr.h"
#include <wtf/Forward.h>
#include <wtf/RefCounted.h>

namespace JSC {

    struct RegExpRepresentation;
    class JSGlobalData;

    JS_EXPORT_PRIVATE RegExpFlags regExpFlags(const UString&);

    class RegExp : public JSCell {
    public:
        typedef JSCell Base;

        JS_EXPORT_PRIVATE static RegExp* create(JSGlobalData&, const UString& pattern, RegExpFlags);
        static void destroy(JSCell*);

        bool global() const { return m_flags & FlagGlobal; }
        bool ignoreCase() const { return m_flags & FlagIgnoreCase; }
        bool multiline() const { return m_flags & FlagMultiline; }

        const UString& pattern() const { return m_patternString; }

        bool isValid() const { return !m_constructionError && m_flags != InvalidFlags; }
        const char* errorMessage() const { return m_constructionError; }

        JS_EXPORT_PRIVATE int match(JSGlobalData&, const UString&, unsigned startOffset, Vector<int, 32>* ovector = 0);
        unsigned numSubpatterns() const { return m_numSubpatterns; }

        bool hasCode()
        {
            return m_representation;
        }

        void invalidateCode();
        
#if ENABLE(REGEXP_TRACING)
        void printTraceData();
#endif

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(LeafType, 0), &s_info);
        }
        
        static JS_EXPORTDATA const ClassInfo s_info;

        RegExpKey key() { return RegExpKey(m_flags, m_patternString); }

    protected:
        void finishCreation(JSGlobalData&);

    private:
        friend class RegExpCache;
        RegExp(JSGlobalData&, const UString&, RegExpFlags);

        static RegExp* createWithoutCaching(JSGlobalData&, const UString&, RegExpFlags);

        enum RegExpState {
            ParseError,
            JITCode,
            ByteCode,
            NotCompiled
        } m_state;

        void compile(JSGlobalData*, Yarr::YarrCharSize);
        void compileIfNecessary(JSGlobalData&, Yarr::YarrCharSize);

#if ENABLE(YARR_JIT_DEBUG)
        void matchCompareWithInterpreter(const UString&, int startOffset, int* offsetVector, int jitResult);
#endif

        UString m_patternString;
        RegExpFlags m_flags;
        const char* m_constructionError;
        unsigned m_numSubpatterns;
#if ENABLE(REGEXP_TRACING)
        unsigned m_rtMatchCallCount;
        unsigned m_rtMatchFoundCount;
#endif

        OwnPtr<RegExpRepresentation> m_representation;
    };

} // namespace JSC

#endif // RegExp_h
