/*
 * Copyright (C) 2013-2019 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#pragma once

#include <wtf/FastMalloc.h>
#include <wtf/MallocCommon.h>
#include <wtf/Noncopyable.h>
#include <wtf/Packed.h>
#include <wtf/RawPtrTraits.h>

namespace WTF {

template<typename T, typename PassedPtrTraits = RawPtrTraits<T>>
class BagNode {
public:
    using PtrTraits = typename PassedPtrTraits::template RebindTraits<BagNode>;

    template<typename... Args>
    BagNode(Args&&... args)
        : m_item(std::forward<Args>(args)...)
    { }
    
    T m_item;
    typename PtrTraits::StorageType m_next { nullptr };
};

template<typename T, typename PassedPtrTraits = RawPtrTraits<T>, typename Malloc = FastMalloc>
class Bag final {
    WTF_MAKE_NONCOPYABLE(Bag);
    WTF_MAKE_CONFIGURABLE_ALLOCATED(Malloc);
    using Node = BagNode<T, PassedPtrTraits>;
    using PtrTraits = typename PassedPtrTraits::template RebindTraits<Node>;

public:
    Bag() = default;

    template<typename U>
    Bag(Bag<T, U>&& other)
    {
        ASSERT(!m_head);
        m_head = other.unwrappedHead();
        other.m_head = nullptr;
    }

    template<typename U>
    Bag& operator=(Bag<T, U>&& other)
    {
        if (unwrappedHead() == other.unwrappedHead())
            return *this;

        Bag destroy;
        destroy.m_head = unwrappedHead();
        m_head = other.unwrappedHead();
        other.m_head = nullptr;

        return *this;
    }

    ~Bag()
    {
        clear();
    }
    
    void clear()
    {
        Node* head = this->unwrappedHead();
        while (head) {
            Node* current = head;
            head = Node::PtrTraits::unwrap(current->m_next);
            current->~Node();
            Malloc::free(current);
        }
        m_head = nullptr;
    }
    
    template<typename... Args>
    T* add(Args&&... args)
    {
        Node* newNode = static_cast<Node*>(Malloc::malloc(sizeof(Node)));
        new (NotNull, newNode) Node(std::forward<Args>(args)...);
        newNode->m_next = unwrappedHead();
        m_head = newNode;
        return &newNode->m_item;
    }
    
    class iterator {
        WTF_MAKE_CONFIGURABLE_ALLOCATED(Malloc);
    public:
        iterator()
            : m_node(0)
        {
        }
        
        // This is sort of cheating; it's equivalent to iter == end().
        bool operator!() const { return !m_node; }
        
        T* operator*() const { return &m_node->m_item; }
        
        iterator& operator++()
        {
            m_node = Node::PtrTraits::unwrap(m_node->m_next);
            return *this;
        }
        
        friend bool operator==(iterator, iterator) = default;

    private:
        template<typename, typename, typename> friend class WTF::Bag;
        Node* m_node;
    };
    
    iterator begin() LIFETIME_BOUND
    {
        iterator result;
        result.m_node = unwrappedHead();
        return result;
    }

    const iterator begin() const LIFETIME_BOUND
    {
        iterator result;
        result.m_node = unwrappedHead();
        return result;
    }


    iterator end() const LIFETIME_BOUND { return iterator(); }
    
    bool isEmpty() const { return !m_head; }
    
private:
    Node* unwrappedHead() const { return PtrTraits::unwrap(m_head); }

    typename PtrTraits::StorageType m_head { nullptr };
};

template<typename T>
using PackedBag = Bag<T, PackedPtrTraits<T>>;

} // namespace WTF

using WTF::Bag;
using WTF::PackedBag;
