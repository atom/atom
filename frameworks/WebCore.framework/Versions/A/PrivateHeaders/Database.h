/*
 * Copyright (C) 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef Database_h
#define Database_h

#if ENABLE(SQL_DATABASE)

#include "AbstractDatabase.h"
#include "PlatformString.h"

#include <wtf/Deque.h>
#include <wtf/Forward.h>

namespace WebCore {

class DatabaseCallback;
class ScriptExecutionContext;
class SecurityOrigin;
class SQLTransaction;
class SQLTransactionCallback;
class SQLTransactionClient;
class SQLTransactionCoordinator;
class SQLTransactionErrorCallback;
class VoidCallback;

typedef int ExceptionCode;

class Database : public AbstractDatabase {
public:
    virtual ~Database();

    // Direct support for the DOM API
    static PassRefPtr<Database> openDatabase(ScriptExecutionContext*, const String& name, const String& expectedVersion, const String& displayName,
                                             unsigned long estimatedSize, PassRefPtr<DatabaseCallback>, ExceptionCode&);
    virtual String version() const;
    void changeVersion(const String& oldVersion, const String& newVersion, PassRefPtr<SQLTransactionCallback>,
                       PassRefPtr<SQLTransactionErrorCallback>, PassRefPtr<VoidCallback> successCallback);
    void transaction(PassRefPtr<SQLTransactionCallback>, PassRefPtr<SQLTransactionErrorCallback>, PassRefPtr<VoidCallback> successCallback);
    void readTransaction(PassRefPtr<SQLTransactionCallback>, PassRefPtr<SQLTransactionErrorCallback>, PassRefPtr<VoidCallback> successCallback);

    // Internal engine support
    Vector<String> tableNames();

    virtual SecurityOrigin* securityOrigin() const;

    virtual void markAsDeletedAndClose();
    bool deleted() const { return m_deleted; }

    void close();
    virtual void closeImmediately();

    unsigned long long databaseSize() const;
    unsigned long long maximumSize() const;

    void scheduleTransactionCallback(SQLTransaction*);
    void scheduleTransactionStep(SQLTransaction*, bool immediately = false);

    SQLTransactionClient* transactionClient() const;
    SQLTransactionCoordinator* transactionCoordinator() const;

private:
    class DatabaseOpenTask;
    class DatabaseCloseTask;
    class DatabaseTransactionTask;
    class DatabaseTableNamesTask;

    Database(ScriptExecutionContext*, const String& name, const String& expectedVersion,
             const String& displayName, unsigned long estimatedSize);
    void runTransaction(PassRefPtr<SQLTransactionCallback>, PassRefPtr<SQLTransactionErrorCallback>,
                        PassRefPtr<VoidCallback> successCallback, bool readOnly);

    bool openAndVerifyVersion(bool setVersionInNewDatabase, ExceptionCode&, String& errorMessage);
    virtual bool performOpenAndVerify(bool setVersionInNewDatabase, ExceptionCode&, String& errorMessage);

    void inProgressTransactionCompleted();
    void scheduleTransaction();

    Vector<String> performGetTableNames();

    static void deliverPendingCallback(void*);

    Deque<RefPtr<SQLTransaction> > m_transactionQueue;
    Mutex m_transactionInProgressMutex;
    bool m_transactionInProgress;
    bool m_isTransactionQueueEnabled;

    RefPtr<SecurityOrigin> m_databaseThreadSecurityOrigin;

    bool m_deleted;
};

} // namespace WebCore

#endif // ENABLE(SQL_DATABASE)

#endif // Database_h
