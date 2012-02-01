/*
 * Copyright (C) 2007 Apple Inc. All rights reserved.
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
#ifndef SQLStatement_h
#define SQLStatement_h

#if ENABLE(SQL_DATABASE)

#include "PlatformString.h"
#include "SQLCallbackWrapper.h"
#include "SQLResultSet.h"
#include "SQLValue.h"
#include <wtf/Forward.h>
#include <wtf/Vector.h>

namespace WebCore {

class Database;
class SQLError;
class SQLStatementCallback;
class SQLStatementErrorCallback;
class SQLTransaction;

class SQLStatement : public ThreadSafeRefCounted<SQLStatement> {
public:
    static PassRefPtr<SQLStatement> create(Database*, const String&, const Vector<SQLValue>&, PassRefPtr<SQLStatementCallback>, PassRefPtr<SQLStatementErrorCallback>, int permissions);

    bool execute(Database*);
    bool lastExecutionFailedDueToQuota() const;

    bool hasStatementCallback() const { return m_statementCallbackWrapper.hasCallback(); }
    bool hasStatementErrorCallback() const { return m_statementErrorCallbackWrapper.hasCallback(); }

    void setDatabaseDeletedError(Database*);
    void setVersionMismatchedError(Database*);

    bool performCallback(SQLTransaction*);

    SQLError* sqlError() const { return m_error.get(); }
private:
    SQLStatement(Database*, const String& statement, const Vector<SQLValue>& arguments, PassRefPtr<SQLStatementCallback>, PassRefPtr<SQLStatementErrorCallback>, int permissions);

    void setFailureDueToQuota(Database*);
    void clearFailureDueToQuota();

    String m_statement;
    Vector<SQLValue> m_arguments;
    SQLCallbackWrapper<SQLStatementCallback> m_statementCallbackWrapper;
    SQLCallbackWrapper<SQLStatementErrorCallback> m_statementErrorCallbackWrapper;

    RefPtr<SQLError> m_error;
    RefPtr<SQLResultSet> m_resultSet;

    int m_permissions;
};

} // namespace WebCore

#endif // ENABLE(SQL_DATABASE)

#endif // SQLStatement_h
