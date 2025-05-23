/*
 * Copyright (C) 2022-2023 Apple Inc. All rights reserved.
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

#include "config.h"
#include "WaiterListManager.h"

#include "DeferredWorkTimerInlines.h"
#include "HeapCellInlines.h"
#include "JSGlobalObject.h"
#include "JSLock.h"
#include "JSObjectInlines.h"
#include "ObjectConstructor.h"
#include <wtf/DataLog.h>
#include <wtf/NeverDestroyed.h>
#include <wtf/RawPointer.h>
#include <wtf/TZoneMallocInlines.h>

WTF_ALLOW_UNSAFE_BUFFER_USAGE_BEGIN

namespace JSC {

namespace WaiterListsManagerInternal {
static constexpr bool verbose = false;
}

WTF_MAKE_TZONE_ALLOCATED_IMPL(Waiter);
WTF_MAKE_TZONE_ALLOCATED_IMPL(WaiterList);

Waiter::Waiter(VM* vm)
    : m_vm(vm)
    , m_isAsync(false)
{
}

Waiter::Waiter(JSPromise* promise)
    : m_vm(&promise->vm())
    , m_ticket(m_vm->deferredWorkTimer->addPendingWork(DeferredWorkTimer::WorkType::AtSomePoint, *m_vm, promise, { }))
    , m_isAsync(true)
{
}


WaiterListManager& WaiterListManager::singleton()
{
    static LazyNeverDestroyed<WaiterListManager> manager;
    static std::once_flag onceKey;
    std::call_once(onceKey, [&] {
        manager.construct();
    });
    return manager;
}

template <typename ValueType>
WaiterListManager::WaitSyncResult WaiterListManager::waitSyncImpl(VM& vm, ValueType* ptr, ValueType expectedValue, Seconds timeout)
{
    dataLogLnIf(WaiterListsManagerInternal::verbose, "<WaiterListManager> <Thread:", Thread::currentSingleton(), "> waitSyncImpl starts totalWaiterCount=", totalWaiterCount());

    Ref<Waiter> syncWaiter = vm.syncWaiter();
    Ref<WaiterList> list = findOrCreateList(ptr);
    MonotonicTime time = MonotonicTime::timePointFromNow(timeout);

    {
        Locker listLocker { list->lock };
        if (WTF::atomicLoad(ptr) != expectedValue)
            return WaitSyncResult::NotEqual;

        list->addLast(listLocker, syncWaiter);
        dataLogLnIf(WaiterListsManagerInternal::verbose, "<WaiterListManager> <Thread:", Thread::currentSingleton(), "> added a new SyncWaiter=", syncWaiter.get(), " to a waiterList for ptr ", RawPointer(ptr));

        while (syncWaiter->isOnList() && time.now() < time && !vm.hasTerminationRequest())
            syncWaiter->condition().waitUntil(list->lock, time.approximateWallTime());

        // At this point, syncWaiter should be either notified (dequeued) or timeout (not dequeued).
        bool didGetDequeued = !syncWaiter->isOnList();
        if (didGetDequeued)
            return WaitSyncResult::OK;

        didGetDequeued = list->findAndRemove(listLocker, syncWaiter);
        ASSERT(didGetDequeued);
        return vm.hasTerminationRequest() ? WaitSyncResult::Terminated : WaitSyncResult::TimedOut;
    }
}

template <typename ValueType>
JSValue WaiterListManager::waitAsyncImpl(JSGlobalObject* globalObject, VM& vm, ValueType* ptr, ValueType expectedValue, Seconds timeout)
{
    dataLogLnIf(WaiterListsManagerInternal::verbose, "<WaiterListManager> <Thread:", Thread::currentSingleton(), "> waitAsyncImpl starts totalWaiterCount=", totalWaiterCount());

    JSObject* object = constructEmptyObject(globalObject);

    bool isAsync = false;
    JSValue value;

    Ref<WaiterList> list = findOrCreateList(ptr);
    JSPromise* promise = JSPromise::create(vm, globalObject->promiseStructure());

    {
        Locker listLocker { list->lock };
        if (WTF::atomicLoad(ptr) != expectedValue)
            value = vm.smallStrings.notEqualString();
        else if (!timeout)
            value = vm.smallStrings.timedOutString();
        else {
            isAsync = true;

            Ref<Waiter> waiter = adoptRef(*new Waiter(promise));
            list->addLast(listLocker, waiter);

            if (timeout != Seconds::infinity()) {
                Ref<RunLoop::DispatchTimer> timer = RunLoop::currentSingleton().dispatchAfter(timeout, [this, ptr, waiter = waiter.copyRef()]() mutable {
                    timeoutAsyncWaiter(ptr, WTFMove(waiter));
                });
                waiter->setTimer(listLocker, WTFMove(timer));
            }

            dataLogLnIf(WaiterListsManagerInternal::verbose, "<WaiterListManager> <Thread:", Thread::currentSingleton(), "> added a new AsyncWaiter=", *waiter.ptr(), " to a waiterList for ptr ", RawPointer(ptr));
            value = promise;
        }
    }

    object->putDirect(vm, vm.propertyNames->async, jsBoolean(isAsync));
    object->putDirect(vm, vm.propertyNames->value, value);
    return object;
}

JSValue WaiterListManager::waitAsync(JSGlobalObject* globalObject, VM& vm, int32_t* ptr, int32_t expected, Seconds timeout)
{
    return waitAsyncImpl(globalObject, vm, ptr, expected, timeout);
}

JSValue WaiterListManager::waitAsync(JSGlobalObject* globalObject, VM& vm, int64_t* ptr, int64_t expected, Seconds timeout)
{
    return waitAsyncImpl(globalObject, vm, ptr, expected, timeout);
}

WaiterListManager::WaitSyncResult WaiterListManager::waitSync(VM& vm, int32_t* ptr, int32_t expected, Seconds timeout)
{
    return waitSyncImpl(vm, ptr, expected, timeout);
}

WaiterListManager::WaitSyncResult WaiterListManager::waitSync(VM& vm, int64_t* ptr, int64_t expected, Seconds timeout)
{
    return waitSyncImpl(vm, ptr, expected, timeout);
}

void WaiterListManager::timeoutAsyncWaiter(void* ptr, Ref<Waiter>&& waiter)
{
    dataLogLnIf(WaiterListsManagerInternal::verbose, "<WaiterListManager> <Thread:", Thread::currentSingleton(), "> timeoutAsyncWaiter ", waiter.get(), ") for ptr ", RawPointer(ptr));
    if (RefPtr<WaiterList> list = findList(ptr)) {
        Locker listLocker { list->lock };
        if (waiter->isOnList()) {
            bool didGetDequeued = list->findAndRemove(listLocker, waiter);
            ASSERT_UNUSED(didGetDequeued, didGetDequeued);
        }
        notifyWaiterImpl(listLocker,  WTFMove(waiter), ResolveResult::Timeout);
        return;
    }

    ASSERT(!waiter->isOnList());
    notifyWaiterImpl(NoLockingNecessary, WTFMove(waiter), ResolveResult::Timeout);
}

unsigned WaiterListManager::notifyWaiter(void* ptr, unsigned count)
{
    ASSERT(ptr);
    unsigned notified = 0;
    RefPtr<WaiterList> list = findList(ptr);
    if (list) {
        Locker listLocker { list->lock };
        while (notified < count && list->size()) {
            notifyWaiterImpl(listLocker, list->takeFirst(listLocker), ResolveResult::Ok);
            notified++;
        }
    }

    dataLogLnIf(WaiterListsManagerInternal::verbose, "<WaiterListManager> <Thread:", Thread::currentSingleton(), "> notified waiters (count ", notified, ") for ptr ", RawPointer(ptr));
    return notified;
}

void WaiterListManager::notifyWaiterImpl(const AbstractLocker& listLocker, Ref<Waiter>&& waiter, const ResolveResult resolveResult)
{
    ASSERT(!waiter->isOnList());

    if (waiter->isAsync()) {
        waiter->scheduleWorkAndClear(listLocker, [resolveResult](DeferredWorkTimer::Ticket ticket) {
            JSPromise* promise = jsCast<JSPromise*>(ticket->target());
            JSGlobalObject* globalObject = promise->globalObject();
            VM& vm = promise->vm();
            JSValue result = resolveResult == ResolveResult::Ok ? vm.smallStrings.okString() : vm.smallStrings.timedOutString();
            promise->resolve(globalObject, result);
        });
        return;
    }

    waiter->condition().notifyOne();
}

size_t WaiterListManager::waiterListSize(void* ptr)
{
    RefPtr<WaiterList> list = findList(ptr);
    size_t size = 0;
    if (list) {
        Locker listLocker { list->lock };
        size = list->size();
    }
    return size;
}

size_t WaiterListManager::totalWaiterCount()
{
    Locker waiterListsLocker { m_waiterListsLock };
    size_t totalCount = 0;
    for (auto& entry : m_waiterLists) {
        Ref<WaiterList> list = entry.value;
        Locker listLocker { list->lock };
        totalCount += list->size();
    }
    return totalCount;
}

void Waiter::scheduleWorkAndClear(const AbstractLocker& listLocker, DeferredWorkTimer::Task&& task)
{
    ASSERT(m_isAsync && m_vm && !isOnList());
    if (auto ticket = this->ticket(listLocker)) {
        m_vm->deferredWorkTimer->scheduleWorkSoon(ticket.get(), WTFMove(task));
        clearTicket(listLocker);
    }
    clearTimer(listLocker);
}

void Waiter::cancelAndClear(const AbstractLocker& listLocker)
{
    ASSERT(m_isAsync);
    if (auto ticket = this->ticket(listLocker)) {
        m_vm->deferredWorkTimer->cancelPendingWork(ticket.get());
        m_vm->deferredWorkTimer->scheduleWorkSoon(ticket.get(), [](DeferredWorkTimer::Ticket) { });
        clearTicket(listLocker);
    }
    clearTimer(listLocker);
}

void WaiterListManager::unregister(VM* vm)
{
    Locker waiterListsLocker { m_waiterListsLock };
    for (auto& entry : m_waiterLists) {
        Ref<WaiterList> list = entry.value;
        Locker listLocker { list->lock };
        list->removeIf(listLocker, [&](Waiter* waiter) {
            if (waiter->vm() == vm) {
                dataLogLnIf(WaiterListsManagerInternal::verbose,
                    "<WaiterListManager> <Thread:", Thread::currentSingleton(),
                    "> unregister VM is cancelling waiter=", *waiter,
                    " in WaiterList for ptr ", RawPointer(entry.key));

                // If the vm is about destructing, then it shouldn't
                // been blocked. That means we shouldn't find any SyncWaiter.
                ASSERT(waiter->isAsync());
                waiter->cancelAndClear(listLocker);
                return true;
            }
            return false;
        });
    }
}

void WaiterListManager::unregister(JSGlobalObject* globalObject)
{
    Locker waiterListsLocker { m_waiterListsLock };
    for (auto& entry : m_waiterLists) {
        Ref<WaiterList> list = entry.value;
        Locker listLocker { list->lock };
        list->removeIf(listLocker, [&](Waiter* waiter) {
            if (waiter->isAsync()) {
                if (auto ticket = waiter->ticket(listLocker); ticket && !ticket->isCancelled() && ticket->target()->globalObject() == globalObject) {
                    dataLogLnIf(WaiterListsManagerInternal::verbose,
                        "<WaiterListManager> <Thread:", Thread::currentSingleton(),
                        "> unregister JSGlobalObject is cancelling waiter=", *waiter,
                        " in WaiterList for ptr ", RawPointer(entry.key));

                    waiter->cancelAndClear(listLocker);
                    return true;
                }
            }
            return false;
        });
    }
}

void WaiterListManager::unregister(uint8_t* arrayPtr, size_t size)
{
    Locker waiterListsLocker { m_waiterListsLock };
    m_waiterLists.removeIf([&](auto& entry) {
        if (entry.key >= arrayPtr && entry.key < arrayPtr + size) {
            Ref<WaiterList> list = entry.value;
            Locker listLocker { list->lock };
            list->removeIf(listLocker, [&](Waiter* waiter) {
                dataLogLnIf(WaiterListsManagerInternal::verbose,
                    "<WaiterListManager> <Thread:", Thread::currentSingleton(),
                    "> unregister SAB is cancelling waiter=", *waiter,
                    " in WaiterList for ptr ", RawPointer(entry.key));

                // If the SharedArrayBuffer is about destructing, then no VM is
                // referencing the buffer. That means no blocking SyncWaiter
                // on the buffer for any VM.
                ASSERT(waiter->isAsync());
                // If the AsyncWaiter has a valid timer, then let it timeout. Otherwise un-task it.
                // See example, waitasync-timeout-finite-gc.js.
                //
                // OK, let's say if the ticket has a valid timer and its globalObject is about being
                // destructed later but before the timeout. Then, we cannot cancel the work from
                // `unregister(JSGlobalObject* globalObject)` since the waiter is already removed
                // from the lists by this code. So, should we keep it in the list? No, in either
                // case, we have to remove it since all lists associating to the SAB (about destructing)
                // must be removed. This is because there may be a new SAB with a waiter at the same address.
                // Therefore, we will let `clearWeakTickets` to handle this special case.
                if (!waiter->hasTimer(listLocker))
                    waiter->cancelAndClear(listLocker);
                return true;
            });

            ASSERT(!list->size());
            return true;
        }
        return false;
    });
}

Ref<WaiterList> WaiterListManager::findOrCreateList(void* ptr)
{
    Locker waiterListsLocker { m_waiterListsLock };
    return m_waiterLists.ensure(ptr, [] {
        return adoptRef(*new WaiterList()); 
    }).iterator->value.get();
}

RefPtr<WaiterList> WaiterListManager::findList(void* ptr)
{
    Locker waiterListsLocker { m_waiterListsLock };
    auto it = m_waiterLists.find(ptr);
    if (it == m_waiterLists.end())
        return nullptr;
    return it->value.ptr();
}

void Waiter::dump(PrintStream& out) const
{
    out.print("[this=");
    out.print(RawPointer(this));
    out.print(", vm=", RawPointer(m_vm));
    out.print(", isAsync=", m_isAsync);
    if (!m_isAsync) {
        out.print("]");
        return;
    }

    auto ticket = this->ticket(NoLockingNecessary);
    out.print(", ticket=", RawPointer(ticket.get()));
    if (ticket && !ticket->isCancelled()) {
        out.print(", m_ticket->globalObject=", RawPointer(ticket->target()->globalObject()));
        out.print(", m_ticket->target=", RawPointer(jsCast<JSObject*>(ticket->dependencies().last())));
        out.print(", m_ticket->scriptExecutionOwner=", RawPointer(ticket->scriptExecutionOwner()));
    }

    out.print(", m_timer=", RawPointer(m_timer.get()));
    out.print("]");
}

} // namespace JSC

WTF_ALLOW_UNSAFE_BUFFER_USAGE_END
