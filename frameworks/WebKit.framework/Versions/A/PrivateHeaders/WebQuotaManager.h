/*
 * Copyright (C) 2010 Apple Inc. All Rights Reserved.
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
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

@class WebSecurityOrigin;

/*!
    @protocol WebQuotaManager
    @discussion This protocol is used to view and manipulate a per-origin storage quota.
*/
@protocol WebQuotaManager

/*!
    @method initWithOrigin:
    @param The security origin this will manage.
    @result A new WebQuotaManager object.
*/
- (id)initWithOrigin:(WebSecurityOrigin *)origin;

/*!
    @method origin
    @result The security origin this manager is managing.
*/
- (WebSecurityOrigin *)origin;

/*!
    @method usage
    @result The current total usage of all relevant items in this security origin in bytes.
*/
- (unsigned long long)usage;

/*!
    @method quota
    @result The current quota of security origin in bytes.
*/
- (unsigned long long)quota;

/*!
    @method setQuota:
    @param Sets a new quota, in bytes, on this security origin.
*/
- (void)setQuota:(unsigned long long)quota;

@end
