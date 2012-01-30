/*
 *  Copyright (C) 2006, 2007 Apple Inc. All rights reserved.
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
 */

#ifndef ExceptionCode_h
#define ExceptionCode_h

// FIXME: Move this header into the files that actually need it.
#include "ExceptionCodeDescription.h"

namespace WebCore {

    // The DOM standards use unsigned short for exception codes.
    // In our DOM implementation we use int instead, and use different
    // numerical ranges for different types of DOM exception, so that
    // an exception of any type can be expressed with a single integer.
    typedef int ExceptionCode;

    enum {
        INDEX_SIZE_ERR = 1,
        DOMSTRING_SIZE_ERR = 2,
        HIERARCHY_REQUEST_ERR = 3,
        WRONG_DOCUMENT_ERR = 4,
        INVALID_CHARACTER_ERR = 5,
        NO_DATA_ALLOWED_ERR = 6,
        NO_MODIFICATION_ALLOWED_ERR = 7,
        NOT_FOUND_ERR = 8,
        NOT_SUPPORTED_ERR = 9,
        INUSE_ATTRIBUTE_ERR = 10,

        // Introduced in DOM Level 2:
        INVALID_STATE_ERR = 11,
        SYNTAX_ERR = 12,
        INVALID_MODIFICATION_ERR = 13,
        NAMESPACE_ERR = 14,
        INVALID_ACCESS_ERR = 15,

        // Introduced in DOM Level 3:
        VALIDATION_ERR = 16,
        TYPE_MISMATCH_ERR = 17,

        // XMLHttpRequest extension:
        SECURITY_ERR = 18,

        // Others introduced in HTML5:
        NETWORK_ERR = 19,
        ABORT_ERR = 20,
        URL_MISMATCH_ERR = 21,
        QUOTA_EXCEEDED_ERR = 22,
        TIMEOUT_ERR = 23,
        INVALID_NODE_TYPE_ERR = 24,
        DATA_CLONE_ERR = 25
    };

} // namespace WebCore

#endif // ExceptionCode_h
