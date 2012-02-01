/*
 * Copyright (C) 2005, 2008, 2009 Apple Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef JSLock_h
#define JSLock_h

#include <wtf/Assertions.h>
#include <wtf/Noncopyable.h>

namespace JSC {

    // To make it safe to use JavaScript on multiple threads, it is
    // important to lock before doing anything that allocates a
    // JavaScript data structure or that interacts with shared state
    // such as the protect count hash table. The simplest way to lock
    // is to create a local JSLock object in the scope where the lock 
    // must be held. The lock is recursive so nesting is ok. The JSLock 
    // object also acts as a convenience short-hand for running important
    // initialization routines.

    // To avoid deadlock, sometimes it is necessary to temporarily
    // release the lock. Since it is recursive you actually have to
    // release all locks held by your thread. This is safe to do if
    // you are executing code that doesn't require the lock, and you
    // reacquire the right number of locks at the end. You can do this
    // by constructing a locally scoped JSLock::DropAllLocks object. The 
    // DropAllLocks object takes care to release the JSLock only if your
    // thread acquired it to begin with.

    // For contexts other than the single shared one, implicit locking is not done,
    // but we still need to perform all the counting in order to keep debug
    // assertions working, so that clients that use the shared context don't break.

    class ExecState;
    class JSGlobalData;

    enum JSLockBehavior { SilenceAssertionsOnly, LockForReal };

    class JSLock {
        WTF_MAKE_NONCOPYABLE(JSLock);
    public:
        JS_EXPORT_PRIVATE JSLock(ExecState*);
        JSLock(JSGlobalData*);

        JSLock(JSLockBehavior lockBehavior)
            : m_lockBehavior(lockBehavior)
        {
#ifdef NDEBUG
            // Locking "not for real" is a debug-only feature.
            if (lockBehavior == SilenceAssertionsOnly)
                return;
#endif
            lock(lockBehavior);
        }

        ~JSLock()
        { 
#ifdef NDEBUG
            // Locking "not for real" is a debug-only feature.
            if (m_lockBehavior == SilenceAssertionsOnly)
                return;
#endif
            unlock(m_lockBehavior); 
        }
        
        JS_EXPORT_PRIVATE static void lock(JSLockBehavior);
        JS_EXPORT_PRIVATE static void unlock(JSLockBehavior);
        static void lock(ExecState*);
        static void unlock(ExecState*);

        JS_EXPORT_PRIVATE static intptr_t lockCount();
        JS_EXPORT_PRIVATE static bool currentThreadIsHoldingLock();

        JSLockBehavior m_lockBehavior;

        class DropAllLocks {
            WTF_MAKE_NONCOPYABLE(DropAllLocks);
        public:
            JS_EXPORT_PRIVATE DropAllLocks(ExecState* exec);
            JS_EXPORT_PRIVATE DropAllLocks(JSLockBehavior);
            JS_EXPORT_PRIVATE ~DropAllLocks();
            
        private:
            intptr_t m_lockCount;
            JSLockBehavior m_lockBehavior;
        };
    };

} // namespace

#endif // JSLock_h
