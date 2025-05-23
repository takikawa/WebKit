/*
 * Copyright (C) 2011-2025 Apple Inc. All rights reserved.
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
 * 3.  Neither the name of Apple Inc. ("Apple") nor the names of
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

#import "config.h"
#import <wtf/HashMap.h>
#import <wtf/RetainPtr.h>
#import <wtf/URL.h>

#if __has_feature(objc_arc)
#ifndef RETAIN_PTR_TEST_NAME
#error This tests RetainPtr.h with ARC disabled.
#endif
#define autorelease self
#endif

#ifndef RETAIN_PTR_TEST_NAME
#define RETAIN_PTR_TEST_NAME RetainPtr
#endif

#if __has_feature(objc_arc) && !defined(NDEBUG)
// Debug builds with ARC enabled cause objects to be autoreleased
// when assigning adoptNS() result to a different RetainPtr<> type,
// and when calling RetainPtr<>::get().
#define AUTORELEASEPOOL_FOR_ARC_DEBUG @autoreleasepool
#else
#define AUTORELEASEPOOL_FOR_ARC_DEBUG
#endif

namespace TestWebKitAPI {

TEST(RETAIN_PTR_TEST_NAME, AdoptNS)
{
    RetainPtr<NSObject> object1 = adoptNS([[NSObject alloc] init]);
    uintptr_t objectPtr1 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        objectPtr1 = reinterpret_cast<uintptr_t>(object1.get());
    }
    EXPECT_EQ(1L, CFGetRetainCount((CFTypeRef)objectPtr1));

    RetainPtr<NSObject *> object2;
    uintptr_t objectPtr2 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        object2 = adoptNS([[NSObject alloc] init]);
        objectPtr2 = reinterpret_cast<uintptr_t>(object2.get());
    }
    EXPECT_EQ(1L, CFGetRetainCount((CFTypeRef)objectPtr2));

    RetainPtr<id> object3;
    uintptr_t objectPtr3 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        object3 = adoptNS([[NSObject alloc] init]);
        objectPtr3 = reinterpret_cast<uintptr_t>(object3.get());
    }
    EXPECT_EQ(1, CFGetRetainCount((CFTypeRef)objectPtr3));
}

TEST(RETAIN_PTR_TEST_NAME, ConstructionFromMutableNSType)
{
    static_assert(std::is_convertible_v<NSMutableString*, NSString*>, "NSMutableString must convert to NSString");

    NSMutableString *string = [NSMutableString stringWithUTF8String:"foo"];

    // This should invoke RetainPtr's move constructor.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    RetainPtr<NSString> ptr = RetainPtr<NSMutableString>(string);

    EXPECT_EQ(string, ptr);

    RetainPtr<NSMutableString> temp = string;

    // This should invoke RetainPtr's move constructor.
    RetainPtr<NSString> ptr2(WTFMove(temp));

    EXPECT_EQ(string, ptr2);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, ConstructionFromSameNSType)
{
    NSString *string = @"foo";

    // This should invoke RetainPtr's move constructor.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    RetainPtr<NSString> ptr = RetainPtr<NSString>(string);

    EXPECT_EQ(string, ptr);

    RetainPtr<NSString> temp = string;

    // This should invoke RetainPtr's move constructor.
    RetainPtr<NSString> ptr2(WTFMove(temp));

    EXPECT_EQ(string, ptr2);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, ConstructionFromSimilarNSType)
{
    NSString *string = @"foo";

    // This should invoke RetainPtr's move constructor.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    RetainPtr<NSString> ptr = RetainPtr<NSString>(string);

    EXPECT_EQ(string, ptr);

    RetainPtr<NSString> temp = string;

    // This should invoke RetainPtr's move constructor.
    RetainPtr<NSString> ptr2(WTFMove(temp));

    EXPECT_EQ(string, ptr2);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, ConstructionFromSimilarNSTypeReversed)
{
    NSString *string = @"foo";

    // This should invoke RetainPtr's move constructor.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    RetainPtr<NSString> ptr = RetainPtr<NSString>(string);

    EXPECT_EQ(string, ptr);

    RetainPtr<NSString> temp = string;

    // This should invoke RetainPtr's move constructor.
    RetainPtr<NSString> ptr2(WTFMove(temp));

    EXPECT_EQ(string, ptr2);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, MoveAssignmentFromMutableNSType)
{
    NSMutableString *string = [NSMutableString stringWithUTF8String:"foo"];
    RetainPtr<NSString> ptr;

    // This should invoke RetainPtr's move assignment operator.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    ptr = RetainPtr<NSMutableString>(string);

    EXPECT_EQ(string, ptr);

    ptr = nil;
    RetainPtr<NSMutableString> temp = string;

    // This should invoke RetainPtr's move assignment operator.
    ptr = WTFMove(temp);

    EXPECT_EQ(string, ptr);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, MoveAssignmentFromSameNSType)
{
    NSString *string = @"foo";
    RetainPtr<NSString> ptr;

    // This should invoke RetainPtr's move assignment operator.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    ptr = RetainPtr<NSString>(string);

    EXPECT_EQ(string, ptr);

    ptr = nil;
    RetainPtr<NSString> temp = string;

    // This should invoke RetainPtr's move assignment operator.
    ptr = WTFMove(temp);

    EXPECT_EQ(string, ptr);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, MoveAssignmentFromSimilarNSType)
{
    NSString *string = @"foo";
    RetainPtr<NSString> ptr;

    // This should invoke RetainPtr's move assignment operator.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    ptr = RetainPtr<NSString>(string);

    EXPECT_EQ(string, ptr);

    ptr = nil;
    RetainPtr<NSString> temp = string;

    // This should invoke RetainPtr's move assignment operator.
    ptr = WTFMove(temp);

    EXPECT_EQ(string, ptr);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, MoveAssignmentFromSimilarNSTypeReversed)
{
    NSString *string = @"foo";
    RetainPtr<NSString> ptr;

    // This should invoke RetainPtr's move assignment operator.
    // FIXME: This doesn't actually test that we moved the value. We should use a mock
    // NSObject that logs -retain and -release calls.
    ptr = RetainPtr<NSString>(string);

    EXPECT_EQ(string, ptr);

    ptr = nil;
    RetainPtr<NSString> temp = string;

    // This should invoke RetainPtr's move assignment operator.
    ptr = WTFMove(temp);

    EXPECT_EQ(string, ptr);
    SUPPRESS_USE_AFTER_MOVE EXPECT_EQ((NSString *)nil, temp.get());
}

TEST(RETAIN_PTR_TEST_NAME, OptionalRetainPtrNS)
{
    // Test assignment from adoptNS().
    std::optional<RetainPtr<NSObject>> optionalObject1;

    uintptr_t optionalObjectPtr1 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        optionalObject1 = adoptNS([NSObject new]);
        optionalObjectPtr1 = reinterpret_cast<uintptr_t>(optionalObject1.value().get());
    }
    EXPECT_EQ(1L, CFGetRetainCount((CFTypeRef)optionalObjectPtr1));

    RetainPtr<NSObject> object1;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        object1 = optionalObject1.value();
        EXPECT_EQ(optionalObject1.value(), object1);
    }

    // Test assignment from retainPtr().
    std::optional<RetainPtr<NSObject>> optionalObject2;
    @autoreleasepool {
        optionalObject2 = retainPtr([[NSObject new] autorelease]);
    }

    uintptr_t optionalObjectPtr2 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        optionalObjectPtr2 = reinterpret_cast<uintptr_t>(optionalObject2.value().get());
    }
    EXPECT_EQ(1L, CFGetRetainCount((CFTypeRef)optionalObjectPtr2));

    RetainPtr<NSObject> object2;
    uintptr_t objectPtr2 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        object2 = optionalObject2.value();
        objectPtr2 = reinterpret_cast<uintptr_t>(object2.get());

        EXPECT_EQ(optionalObject2.value(), object2);

        EXPECT_NE(object1, object2);

        // Test assignment from std::optional<RetainPtr<NSObject>>.
        optionalObject1 = optionalObject2;
        EXPECT_TRUE(optionalObject1.value());
        EXPECT_TRUE(optionalObject1.value().get());
        EXPECT_EQ(optionalObject1.value(), object2);
        EXPECT_TRUE(optionalObject2.value());
        EXPECT_TRUE(optionalObject2.value().get());
        EXPECT_EQ(optionalObject2.value(), object2);

        // Reset after assignment test.
        optionalObject1 = object1;
        EXPECT_EQ(optionalObject1.value(), object1);
        EXPECT_EQ(optionalObject2.value(), object2);
    }

    // Test move from std::optional<RetainPtr<NSObject>>.
    EXPECT_EQ(2L, CFGetRetainCount((CFTypeRef)objectPtr2));
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        optionalObject1 = WTFMove(optionalObject2);
    }
    EXPECT_EQ(2L, CFGetRetainCount((CFTypeRef)objectPtr2));
    EXPECT_TRUE(optionalObject1.value());
    EXPECT_TRUE(optionalObject1.value().get());
    EXPECT_EQ(optionalObject1.value(), object2);
}

TEST(RETAIN_PTR_TEST_NAME, RetainPtrNS)
{
    RetainPtr<NSObject> object1;
    @autoreleasepool {
        object1 = retainPtr([[NSObject new] autorelease]);
    }
    uintptr_t objectPtr1 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        objectPtr1 = reinterpret_cast<uintptr_t>(object1.get());
    }
    EXPECT_EQ(1L, CFGetRetainCount((CFTypeRef)objectPtr1));

    RetainPtr<NSObject *> object2;
    @autoreleasepool {
        object2 = retainPtr([[NSObject new] autorelease]);
    }
    uintptr_t objectPtr2 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        objectPtr2 = reinterpret_cast<uintptr_t>(object2.get());
    }
    EXPECT_EQ(1L, CFGetRetainCount((CFTypeRef)objectPtr2));

    RetainPtr<id> object3;
    @autoreleasepool {
        object3 = retainPtr([[NSObject new] autorelease]);
    }
    uintptr_t objectPtr3 = 0;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        objectPtr3 = reinterpret_cast<uintptr_t>(object3.get());
    }
    EXPECT_EQ(1L, CFGetRetainCount((CFTypeRef)objectPtr3));
}

TEST(RETAIN_PTR_TEST_NAME, LeakRef)
{
    RetainPtr<NSObject> foo;
    uintptr_t fooPtr;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        foo = adoptNS([[NSObject alloc] init]);
        fooPtr = reinterpret_cast<uintptr_t>(foo.get());
    }
    EXPECT_EQ(1, CFGetRetainCount((CFTypeRef)fooPtr));

    NSObject *object;
    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        object = foo.leakRef();
    }
    EXPECT_EQ(nullptr, foo.get());
    EXPECT_EQ(1, CFGetRetainCount((CFTypeRef)object));

    (void)adoptNS(object);
}

TEST(RETAIN_PTR_TEST_NAME, BridgingAutorelease)
{
    NSString *nsString;
    uintptr_t nsStringPtr;

    AUTORELEASEPOOL_FOR_ARC_DEBUG {
        RetainPtr<CFStringRef> string = adoptCF(CFStringCreateWithCString(nullptr, "hello world", kCFStringEncodingASCII));
        nsString = string.bridgingAutorelease();
        nsStringPtr = reinterpret_cast<uintptr_t>(nsString);
    }

    EXPECT_EQ(1, CFGetRetainCount((CFTypeRef)nsStringPtr));
}

TEST(RETAIN_PTR_TEST_NAME, URLBridgeCast)
{
    RetainPtr<NSURL> nsURL;
    uintptr_t nsURLPtr;
    @autoreleasepool {
        URL url("https://www.webkit.org"_str);
        nsURL = url.createNSURL().get();
        nsURLPtr = reinterpret_cast<uintptr_t>(nsURL.get());
    }

    EXPECT_EQ(1, CFGetRetainCount((CFTypeRef)nsURLPtr));
}

TEST(RETAIN_PTR_TEST_NAME, HashMapCFTypeDeletedValue)
{
    HashMap<RetainPtr<CFStringRef>, int> map;

    auto key = adoptCF(CFStringCreateWithCString(nullptr, "hello world", kCFStringEncodingASCII));
    map.add(key, 1);
    EXPECT_EQ(true, map.contains(key));
    map.remove(key);

    EXPECT_EQ(1, CFGetRetainCount(key.get()));
}

TEST(RETAIN_PTR_TEST_NAME, RetainPtrType)
{
    // CF Types.
    static_assert(std::is_same_v<RetainPtr<CFTypeRef>, RetainPtr<WTF::RetainPtrType<CFTypeRef>>>);
    static_assert(std::is_same_v<RetainPtr<CFStringRef>, RetainPtr<WTF::RetainPtrType<CFStringRef>>>);
    static_assert(std::is_same_v<RetainPtr<CFMutableStringRef>, RetainPtr<WTF::RetainPtrType<CFMutableStringRef>>>);

    // Cocoa Types.
    static_assert(std::is_same_v<RetainPtr<id>, RetainPtr<WTF::RetainPtrType<id>>>);
    static_assert(std::is_same_v<RetainPtr<NSString>, RetainPtr<WTF::RetainPtrType<NSString>>>);
    static_assert(std::is_same_v<RetainPtr<NSString>, RetainPtr<WTF::RetainPtrType<NSString *>>>);
    static_assert(std::is_same_v<RetainPtr<NSMutableString>, RetainPtr<WTF::RetainPtrType<NSMutableString>>>);
    static_assert(std::is_same_v<RetainPtr<NSMutableString>, RetainPtr<WTF::RetainPtrType<NSMutableString *>>>);
}

} // namespace TestWebKitAPI
