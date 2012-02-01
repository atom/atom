/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef MachineThreads_h
#define MachineThreads_h

#include <pthread.h>
#include <wtf/Noncopyable.h>
#include <wtf/ThreadingPrimitives.h>

namespace JSC {

    class Heap;
    class ConservativeRoots;

    class MachineThreads {
        WTF_MAKE_NONCOPYABLE(MachineThreads);
    public:
        MachineThreads(Heap*);
        ~MachineThreads();

        void gatherConservativeRoots(ConservativeRoots&, void* stackCurrent);

        void makeUsableFromMultipleThreads();
        JS_EXPORT_PRIVATE void addCurrentThread(); // Only needs to be called by clients that can use the same heap from multiple threads.

    private:
        void gatherFromCurrentThread(ConservativeRoots&, void* stackCurrent);

        class Thread;

        static void removeThread(void*);
        void removeCurrentThread();

        void gatherFromOtherThread(ConservativeRoots&, Thread*);

        Heap* m_heap;
        Mutex m_registeredThreadsMutex;
        Thread* m_registeredThreads;
        pthread_key_t m_threadSpecific;
    };

} // namespace JSC

#endif // MachineThreads_h
