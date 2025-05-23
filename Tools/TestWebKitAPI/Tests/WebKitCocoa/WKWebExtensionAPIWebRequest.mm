/*
 * Copyright (C) 2022-2024 Apple Inc. All rights reserved.
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

#import "config.h"

#if ENABLE(WK_WEB_EXTENSIONS)

#import "HTTPServer.h"
#import "PlatformUtilities.h"
#import "WebExtensionUtilities.h"
#import <WebKit/_WKWebExtensionWebRequestFilter.h>

namespace TestWebKitAPI {

static auto *webRequestManifest = @{ @"manifest_version": @3, @"permissions": @[ @"webRequest" ], @"background": @{ @"scripts": @[ @"background.js" ], @"type": @"module" } };

#if PLATFORM(MAC)

TEST(WKWebExtensionAPIWebRequest, ManifestV2Persistent)
{
    auto *backgroundScript = Util::constructScript(@[
        @"browser.test.assertEq(typeof browser.webRequest, 'object', 'webRequest should be defined')",

        @"browser.test.notifyPass()"
    ]);

    auto *manifest = @{ @"manifest_version": @2, @"permissions": @[ @"webRequest" ], @"background": @{ @"scripts": @[ @"background.js" ], @"type": @"module", @"persistent": @YES } };

    Util::loadAndRunExtension(manifest, @{ @"background.js": backgroundScript });
}

#endif // PLATFORM(MAC)

TEST(WKWebExtensionAPIWebRequest, ManifestV2NonPersistent)
{
    auto *backgroundScript = Util::constructScript(@[
        @"browser.test.assertEq(typeof browser.webRequest, 'object', 'webRequest should be defined')",

        @"browser.test.notifyPass()"
    ]);

    auto *manifest = @{ @"manifest_version": @2, @"permissions": @[ @"webRequest" ], @"background": @{ @"scripts": @[ @"background.js" ], @"type": @"module", @"persistent": @NO } };

    Util::loadAndRunExtension(manifest, @{ @"background.js": backgroundScript });
}

TEST(WKWebExtensionAPIWebRequest, EventListenerRegistration)
{
    auto *backgroundScript = Util::constructScript(@[
        @"function listener() { browser.test.notifyFail('This listener should not have been called') }",
        @"browser.test.assertFalse(browser.webRequest.onCompleted.hasListener(listener), 'Should not have listener')",

        @"browser.webRequest.onCompleted.addListener(listener)",
        @"browser.test.assertTrue(browser.webRequest.onCompleted.hasListener(listener), 'Should have listener')",

        @"browser.webRequest.onCompleted.removeListener(listener)",
        @"browser.test.assertFalse(browser.webRequest.onCompleted.hasListener(listener), 'Should not have listener')",

        @"browser.test.notifyPass()"
    ]);

    Util::loadAndRunExtension(webRequestManifest, @{ @"background.js": backgroundScript });
}

TEST(WKWebExtensionAPIWebRequest, BeforeRequestEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRequest.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.requestBody, undefined, 'details.requestBody should be undefined')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeRequestEventForSubresource)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='/image.png'>"_s } },
        { "/image.png"_s, { { { "Content-Type"_s, "image/png"_s } }, "..."_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRequest.addListener((details) => {",
        @"  if (details?.type !== 'image')",
        @"    return",

        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('/image.png'), 'details.url should include /image.png')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",

        @"  browser.test.assertEq(details?.requestBody, undefined, 'details.requestBody should be undefined')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeRequestEventWithRequestBodyAndFormData)
{
    auto *pageScript = Util::constructScript(@[
        @"const formData = new FormData()",
        @"formData.append('username', 'user1')",
        @"formData.append('username', 'user2')",
        @"formData.append('age', '42')",

        @"const response = await fetch('/test', {",
        @"  method: 'POST',",
        @"  body: formData",
        @"})",

        @"const text = await response.text()",
        @"browser.test.assertEq(text, 'OK', 'Response body should be OK')"
    ]);

    TestWebKitAPI::HTTPServer server({
        { "/"_s, {
            { { "Content-Type"_s, "text/html"_s } },
            "<script type='module' src='/form.js'></script>"_s
        } },
        { "/form.js"_s, {
            { { "Content-Type"_s, "application/javascript"_s } },
            pageScript
        } },
        { "/test"_s, {
            { { "Content-Type"_s, "text/plain"_s } },
            "OK"_s
        } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRequest.addListener((details) => {",
        @"  if (!details.url.includes('/test'))",
        @"    return",

        @"  browser.test.assertEq(details.method, 'POST', 'details.method should be POST')",
        @"  browser.test.assertEq(details.requestBody?.raw?.length, 1, 'There should be one raw item')",

        @"  const decoder = new TextDecoder()",
        @"  const rawData = details.requestBody?.raw?.[0]?.bytes",
        @"  const bodyText = decoder.decode(rawData ?? new Uint8Array())",

        @"  browser.test.assertTrue(bodyText.includes('Content-Disposition: form-data; name=\"username\"'), 'Username field should exist in multipart data')",
        @"  browser.test.assertTrue(bodyText.includes('user1'), 'Multipart data should include user1')",
        @"  browser.test.assertTrue(bodyText.includes('user2'), 'Multipart data should include user2')",
        @"  browser.test.assertTrue(bodyText.includes('Content-Disposition: form-data; name=\"age\"'), 'Age field should exist in multipart data')",
        @"  browser.test.assertTrue(bodyText.includes('42'), 'Multipart data should include age value 42')",

        @"  browser.test.notifyPass()",
        @"}, { urls: [ '<all_urls>' ] }, [ 'requestBody' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeRequestEventWithRequestBodyAndBlob)
{
    auto *pageScript = Util::constructScript(@[
        @"const blob = new Blob(['This is some text blob content'], { type: 'text/plain' })",

        @"const response = await fetch('/test', {",
        @"  method: 'POST',",
        @"  body: blob",
        @"})",

        @"const text = await response.text()",
        @"browser.test.assertEq(text, 'OK', 'Response body should be')"
    ]);

    TestWebKitAPI::HTTPServer server({
        { "/"_s, {
            { { "Content-Type"_s, "text/html"_s } },
            "<script type='module' src='/blob.js'></script>"_s
        } },
        { "/blob.js"_s, {
            { { "Content-Type"_s, "application/javascript"_s } },
            pageScript
        } },
        { "/test"_s, {
            { { "Content-Type"_s, "text/plain"_s } },
            "OK"_s
        } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRequest.addListener((details) => {",
        @"  if (!details.url.includes('/test'))",
        @"    return",

        @"  browser.test.assertEq(details.method, 'POST', 'details.method should be')",
        @"  browser.test.assertEq(details.requestBody?.raw?.length, 1, 'There should be one raw item')",

        @"  const decoder = new TextDecoder()",
        @"  const bodyText = decoder.decode(details.requestBody?.raw?.[0]?.bytes ?? new Uint8Array())",
        @"  browser.test.assertTrue(bodyText.includes('This is some text blob content'), 'Blob content should match')",

        @"  browser.test.notifyPass()",
        @"}, { urls: [ '<all_urls>' ] }, [ 'requestBody' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeRequestEventWithRequestBodyAndJSON)
{
    auto *pageScript = Util::constructScript(@[
        @"const response = await fetch('/test', {",
        @"  method: 'POST',",
        @"  headers: { 'Content-Type': 'application/json' },",
        @"  body: JSON.stringify({ key: 'value', count: 10 })",
        @"})",

        @"const text = await response.text()",
        @"browser.test.assertEq(text, 'OK', 'Response body should be')"
    ]);

    TestWebKitAPI::HTTPServer server({
        { "/"_s, {
            { { "Content-Type"_s, "text/html"_s } },
            "<script type='module' src='/fetch.js'></script>"_s
        } },
        { "/fetch.js"_s, {
            { { "Content-Type"_s, "application/javascript"_s } },
            pageScript
        } },
        { "/test"_s, {
            { { "Content-Type"_s, "text/plain"_s } },
            "OK"_s
        } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRequest.addListener((details) => {",
        @"  if (!details.url.includes('/test'))",
        @"    return",

        @"  browser.test.assertEq(details.method, 'POST', 'details.method should be')",
        @"  browser.test.assertEq(typeof details.requestBody, 'object', 'details.requestBody type should be')",
        @"  browser.test.assertTrue(details.requestBody?.raw?.[0]?.bytes?.byteLength > 0, 'details.requestBody.raw should contain data')",

        @"  const decoder = new TextDecoder()",
        @"  const bodyText = decoder.decode(details.requestBody?.raw?.[0]?.bytes ?? new Uint8Array())",
        @"  const jsonData = JSON.parse(bodyText ?? '{}')",

        @"  browser.test.assertEq(jsonData?.key, 'value', 'Request body key should be')",
        @"  browser.test.assertEq(jsonData?.count, 10, 'Request body count should be')",

        @"  browser.test.notifyPass()",
        @"}, { urls: [ '<all_urls>' ] }, [ 'requestBody' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeRequestEventWithRequestBodyAndForm)
{
    auto *pageScript = Util::constructScript(@[
        @"const form = document.createElement('form')",
        @"form.action = '/test'",
        @"form.method = 'POST'",

        @"const inputText1 = document.createElement('input')",
        @"inputText1.type = 'text'",
        @"inputText1.name = 'username'",
        @"inputText1.value = 'user1'",
        @"form.appendChild(inputText1)",

        @"const inputText2 = document.createElement('input')",
        @"inputText2.type = 'text'",
        @"inputText2.name = 'username'",
        @"inputText2.value = 'user2'",
        @"form.appendChild(inputText2)",

        @"const inputNumber = document.createElement('input')",
        @"inputNumber.type = 'number'",
        @"inputNumber.name = 'age'",
        @"inputNumber.value = '42'",
        @"form.appendChild(inputNumber)",

        @"document.body.appendChild(form)",
        @"form.submit()"
    ]);

    TestWebKitAPI::HTTPServer server({
        { "/"_s, {
            { { "Content-Type"_s, "text/html"_s } },
            "<script type='module' src='/form.js'></script>"_s
        } },
        { "/form.js"_s, {
            { { "Content-Type"_s, "application/javascript"_s } },
            pageScript
        } },
        { "/test"_s, {
            { { "Content-Type"_s, "text/plain"_s } },
            "OK"_s
        } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRequest.addListener((details) => {",
        @"  if (!details.url.includes('/test'))",
        @"    return",

        @"  browser.test.assertEq(details.method, 'POST', 'details.method should be')",
        @"  browser.test.assertEq(typeof details.requestBody, 'object', 'details.requestBody type should be')",
        @"  browser.test.assertEq(typeof details.requestBody?.formData, 'object', 'details.requestBody.formData type should be')",

        @"  const formData = details.requestBody?.formData",
        @"  browser.test.assertEq(formData?.username?.length, 2, 'username array length should be')",
        @"  browser.test.assertEq(formData?.username?.[0], 'user1', 'First username should be')",
        @"  browser.test.assertEq(formData?.username?.[1], 'user2', 'Second username should be')",
        @"  browser.test.assertEq(formData?.age?.length, 1, 'age array length should be')",
        @"  browser.test.assertEq(formData?.age?.[0], '42', 'age should be')",

        @"  browser.test.notifyPass()",
        @"}, { urls: [ '<all_urls>' ] }, [ 'requestBody' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeSendHeadersEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeSendHeaders.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.requestHeaders, undefined, 'details.requestHeaders should be undefined')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeSendHeadersEventWithRequestHeaders)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeSendHeaders.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.requestHeaders), 'details.requestHeaders should be an array')",
        @"  browser.test.assertTrue(details?.requestHeaders?.some((header) => header.name === 'User-Agent'), 'details.requestHeaders should include User-Agent')",

        @"  browser.test.notifyPass()",
        @"}, null, [ 'requestHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, BeforeSendHeadersEventForSubresource)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='/image.png'>"_s } },
        { "/image.png"_s, { { { "Content-Type"_s, "image/png"_s } }, "..."_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeSendHeaders.addListener((details) => {",
        @"  if (details?.type !== 'image')",
        @"    return",

        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('/image.png'), 'details.url should include /image.png')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.requestHeaders), 'details.requestHeaders should be an array')",
        @"  browser.test.assertTrue(details?.requestHeaders?.some((header) => header.name === 'User-Agent'), 'details.requestHeaders should include User-Agent')",

        @"  browser.test.notifyPass()",
        @"}, [ 'requestHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, SendHeadersEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onSendHeaders.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.requestHeaders, undefined, 'details.requestHeaders should be undefined')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, SendHeadersEventWithRequestHeaders)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onSendHeaders.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.requestHeaders), 'details.requestHeaders should be an array')",
        @"  browser.test.assertTrue(details?.requestHeaders?.some((header) => header.name === 'User-Agent'), 'details.requestHeaders should include User-Agent')",

        @"  browser.test.notifyPass()",
        @"}, null, [ 'requestHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, SendHeadersEventForSubresource)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='/image.png'>"_s } },
        { "/image.png"_s, { { { "Content-Type"_s, "image/png"_s } }, "..."_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onSendHeaders.addListener((details) => {",
        @"  if (details?.type !== 'image')",
        @"    return",

        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('/image.png'), 'details.url should include /image.png')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.requestHeaders), 'details.requestHeaders should be an array')",
        @"  browser.test.assertTrue(details?.requestHeaders?.some((header) => header.name === 'User-Agent'), 'details.requestHeaders should include User-Agent')",

        @"  browser.test.notifyPass()",
        @"}, [ 'requestHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, HeadersReceivedEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onHeadersReceived.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertEq(details?.responseHeaders, undefined, 'details.responseHeaders should be undefined')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, HeadersReceivedEventWithResponseHeaders)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onHeadersReceived.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.responseHeaders), 'details.responseHeaders should be an array')",
        @"  browser.test.assertTrue(details?.responseHeaders?.some((header) => header.name === 'Content-Type' && header.value === 'text/html'), 'details.responseHeaders should include Content-Type: text/html')",

        @"  browser.test.notifyPass()",
        @"}, null, [ 'responseHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, HeadersReceivedEventForSubresource)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='/image.png'>"_s } },
        { "/image.png"_s, { { { "Content-Type"_s, "image/png"_s }, { "Cache-Control"_s, "no-cache"_s } }, "..."_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onHeadersReceived.addListener((details) => {",
        @"  if (details?.type !== 'image')",
        @"    return",

        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('/image.png'), 'details.url should include /image.png')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.responseHeaders), 'details.responseHeaders should be an array')",
        @"  browser.test.assertTrue(details?.responseHeaders?.some((header) => header.name === 'Content-Type' && header.value === 'image/png'), 'details.responseHeaders should include Content-Type: image/png')",
        @"  browser.test.assertTrue(details?.responseHeaders?.some((header) => header.name === 'Cache-Control' && header.value === 'no-cache'), 'details.responseHeaders should include Cache-Control: no-cache')",

        @"  browser.test.notifyPass()",
        @"}, [ 'responseHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, ErrorOccurredEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='nonexistent.png' />"_s } },
        { "/nonexistent.png"_s, { HTTPResponse::Behavior::TerminateConnectionAfterReceivingRequest } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onErrorOccurred.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'image', 'details.type should be')",

        @"  browser.test.assertEq(typeof details?.error, 'string', 'details.error should be a string')",
        @"  browser.test.assertTrue(details?.error?.length > 0, 'details.error should not be empty')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, RedirectOccurredEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { 301, {{ "Location"_s, "/target.html"_s }}, "redirecting..."_s } },
        { "/target.html"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    });

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRedirect.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertTrue(details?.redirectUrl?.includes('/target.html'), 'details.redirectUrl should include /target.html')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, RedirectOccurredEventForSubresource)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='/redirecting.png' />"_s } },
        { "/redirecting.png"_s, { 301, {{ "Location"_s, "/final.png"_s }}, "redirecting..."_s } },
        { "/final.png"_s, { { { "Content-Type"_s, "image/png"_s } }, "..."_s } },
    });

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onBeforeRedirect.addListener((details) => {",
        @"  if (details?.type !== 'image')",
        @"    return",

        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('/redirecting.png'), 'details.url should include /redirecting.png')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",

        @"  browser.test.assertTrue(details?.redirectUrl?.includes('/final.png'), 'details.redirectUrl should include /final.png')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, ResponseStartedEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onResponseStarted.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertEq(details?.responseHeaders, undefined, 'details.responseHeaders should be undefined')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, ResponseStartedEventWithResponseHeaders)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onResponseStarted.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.responseHeaders), 'details.responseHeaders should be an array')",
        @"  browser.test.assertTrue(details?.responseHeaders?.some((header) => header.name === 'Content-Type' && header.value === 'text/html'), 'details.responseHeaders should include Content-Type: text/html')",

        @"  browser.test.notifyPass()",
        @"}, null, [ 'responseHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, ResponseStartedEventForSubresource)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='/image.png'>"_s } },
        { "/image.png"_s, { { { "Content-Type"_s, "image/png"_s } }, "..."_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onResponseStarted.addListener((details) => {",
        @"  if (details?.type !== 'image')",
        @"    return",

        @"  browser.test.assertEq(typeof details?.requestId, 'string', 'details.requestId should be')",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('/image.png'), 'details.url should include /image.png')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'image', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.responseHeaders), 'details.responseHeaders should be an array')",
        @"  browser.test.assertTrue(details?.responseHeaders?.some((header) => header.name === 'Content-Type' && header.value === 'image/png'), 'details.responseHeaders should include Content-Type: image/png')",

        @"  browser.test.notifyPass()",
        @"}, [ 'responseHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, CompletedEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onCompleted.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertEq(details?.responseHeaders, undefined, 'details.responseHeaders should be undefined')",

        @"  browser.test.notifyPass()",
        @"}, [ 'bogus' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, CompletedEventWithResponseHeaders)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onCompleted.addListener((details) => {",
        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('http://localhost'), 'details.url should include http://localhost')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'main_frame', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.responseHeaders), 'details.responseHeaders should be an array')",
        @"  browser.test.assertTrue(details?.responseHeaders?.some((header) => header.name === 'Content-Type' && header.value === 'text/html'), 'details.responseHeaders should include Content-Type: text/html')",

        @"  browser.test.notifyPass()",
        @"}, [ 'responseHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, CompletedEventForSubresource)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, "<img src='/image.png'>"_s } },
        { "/image.png"_s, { { { "Content-Type"_s, "image/png"_s } }, "..."_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"browser.webRequest.onCompleted.addListener((details) => {",
        @"  if (details?.type !== 'image')",
        @"    return",

        @"  browser.test.assertEq(typeof details?.tabId, 'number', 'details.tabId should be')",
        @"  browser.test.assertEq(details?.frameId, 0, 'details.frameId should be')",
        @"  browser.test.assertEq(details?.parentFrameId, -1, 'details.parentFrameId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  browser.test.assertTrue(details?.url?.includes('/image.png'), 'details.url should include /image.png')",
        @"  browser.test.assertEq(details?.method, 'GET', 'details.method should be')",
        @"  browser.test.assertEq(details?.type, 'image', 'details.type should be')",

        @"  browser.test.assertEq(details?.statusCode, 200, 'details.statusCode should be')",
        @"  browser.test.assertEq(details?.statusLine, 'OK', 'details.statusLine should be')",

        @"  browser.test.assertTrue(Array.isArray(details?.responseHeaders), 'details.responseHeaders should be an array')",
        @"  browser.test.assertTrue(details?.responseHeaders?.some((header) => header.name === 'Content-Type' && header.value === 'image/png'), 'details.responseHeaders should include Content-Type: image/png')",

        @"  browser.test.notifyPass()",
        @"}, null, [ 'responseHeaders' ])",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, AllowedFilter)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"function passListener() { browser.test.notifyPass() }",

        @"browser.webRequest.onCompleted.addListener(passListener, { 'urls': [ '*://*.localhost/*' ] })",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    // Grant the webRequest permission.
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, DeniedFilter)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"function passListener() { browser.test.notifyPass() }",
        @"function failListener() { browser.test.notifyFail('This listener should not have been called') }",

        @"browser.webRequest.onCompleted.addListener(failListener, { 'urls': [ '*://*.example.com/*' ] })",
        @"browser.webRequest.onCompleted.addListener(passListener)",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    // Grant the webRequest permission.
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, AllEventsFired)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"let beforeRequestFired = false",
        @"let beforeSendHeadersFired = false",
        @"let sendHeadersFired = false",
        @"let headersReceivedFired = false",
        @"let responseStartedFired = false",

        @"browser.webRequest.onBeforeRequest.addListener(() => { beforeRequestFired = true })",
        @"browser.webRequest.onBeforeSendHeaders.addListener(() => { beforeSendHeadersFired = true })",
        @"browser.webRequest.onSendHeaders.addListener(() => { sendHeadersFired = true })",
        @"browser.webRequest.onHeadersReceived.addListener(() => { headersReceivedFired = true })",
        @"browser.webRequest.onResponseStarted.addListener(() => { responseStartedFired = true })",

        @"function completedHandler() {",
        @"  browser.test.assertTrue(beforeRequestFired)",
        @"  browser.test.assertTrue(beforeSendHeadersFired)",
        @"  browser.test.assertTrue(sendHeadersFired)",
        @"  browser.test.assertTrue(headersReceivedFired)",
        @"  browser.test.assertTrue(responseStartedFired)",

        @"  browser.test.notifyPass()",
        @"}",

        @"browser.webRequest.onCompleted.addListener(completedHandler)",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    // Grant the webRequest permission.
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, DocumentIdAcrossEvents)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"let documentId = null",

        @"browser.webRequest.onBeforeRequest.addListener((details) => {",
        @"  browser.test.assertEq(documentId, null, 'documentId should be')",

        @"  browser.test.assertEq(typeof details?.documentId, 'string', 'details.documentId should be')",
        @"  browser.test.assertEq(details?.documentId?.length, 36, 'details.documentId.length should be')",

        @"  documentId = details?.documentId",
        @"})",

        @"browser.webRequest.onBeforeSendHeaders.addListener((details) => {",
        @"  browser.test.assertEq(documentId, details?.documentId, 'details.documentId should stay consistent in onBeforeSendHeaders')",
        @"})",

        @"browser.webRequest.onSendHeaders.addListener((details) => {",
        @"  browser.test.assertEq(documentId, details?.documentId, 'details.documentId should stay consistent in onSendHeaders')",
        @"})",

        @"browser.webRequest.onHeadersReceived.addListener((details) => {",
        @"  browser.test.assertEq(documentId, details?.documentId, 'details.documentId should stay consistent in onHeadersReceived')",
        @"})",

        @"browser.webRequest.onResponseStarted.addListener((details) => {",
        @"  browser.test.assertEq(documentId, details?.documentId, 'details.documentId should stay consistent in onResponseStarted')",
        @"})",

        @"browser.webRequest.onCompleted.addListener((details) => {",
        @"  browser.test.assertEq(documentId, details?.documentId, 'details.documentId should stay consistent in onCompleted')",

        @"  browser.test.notifyPass()",
        @"})",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, RemoveListenerDuringEvent)
{
    TestWebKitAPI::HTTPServer server({
        { "/"_s, { { { "Content-Type"_s, "text/html"_s } }, ""_s } },
    }, TestWebKitAPI::HTTPServer::Protocol::Http);

    auto *backgroundScript = Util::constructScript(@[
        @"function requestListener() {",
        @"  browser.webRequest.onCompleted.removeListener(requestListener)",
        @"  browser.test.assertFalse(browser.webRequest.onCompleted.hasListener(requestListener), 'Listener should be removed')",
        @"}",

        @"browser.webRequest.onCompleted.addListener(requestListener)",
        @"browser.webRequest.onCompleted.addListener(() => browser.test.notifyPass())",

        @"browser.test.assertTrue(browser.webRequest.onCompleted.hasListener(requestListener), 'Listener should be registered')",

        @"browser.test.sendMessage('Load Tab')"
    ]);

    auto manager = Util::loadExtension(webRequestManifest, @{ @"background.js": backgroundScript });

    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forPermission:WKWebExtensionPermissionWebRequest];

    auto *urlRequest = server.requestWithLocalhost();
    [manager.get().context setPermissionStatus:WKWebExtensionContextPermissionStatusGrantedExplicitly forURL:urlRequest.URL];

    [manager runUntilTestMessage:@"Load Tab"];

    [manager.get().defaultTab.webView loadRequest:urlRequest];

    [manager run];
}

TEST(WKWebExtensionAPIWebRequest, Initialization)
{
    NSString *error;
    _WKWebExtensionWebRequestFilter *filter;

    filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:@{
        @"urls": @[ @"http://foo.com/*", @"http://bar.org/*" ]
    } outErrorMessage:&error];
    EXPECT_NOT_NULL(filter);
    EXPECT_NULL(error);

    filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:@{
        @"urls": @[ @"http://foo.com/*", @"http://bar.org/*" ],
        @"types": @[ @"main_frame", @"sub_frame" ],
        @"tabId": @123
    } outErrorMessage:&error];
    EXPECT_NOT_NULL(filter);
    EXPECT_NULL(error);

    filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:@{
        @"urls": @[ @"http://foo.com/*", @"http://bar.org/*" ],
        @"types": @[ @"main_frame", @"sub_frame" ],
        @"windowId": @123
    } outErrorMessage:&error];
    EXPECT_NOT_NULL(filter);
    EXPECT_NULL(error);

    filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:@{
        @"urls": @[ @"http://has.both.a.tab.id.and.window.id.com/*" ],
        @"types": @[ @"main_frame", @"sub_frame" ],
        @"windowId": @123,
        @"tabId": @9001
    } outErrorMessage:&error];
    EXPECT_NOT_NULL(filter);
    EXPECT_NULL(error);

    filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:@{
        @"urls": @[ ],
    } outErrorMessage:&error];
    EXPECT_NOT_NULL(filter);
    EXPECT_NULL(error);

    filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:@{
        @"urls": @[ @"http://foo.com/*", @3 ],
    } outErrorMessage:&error];
    EXPECT_NULL(filter);
    EXPECT_NS_EQUAL(error, @"'urls' is expected to be an array of strings, but a number was provided in the array");

    filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:@{
        @"urls": @[ @"$" ]
    } outErrorMessage:&error];
    EXPECT_NULL(filter);

    EXPECT_NS_EQUAL(error, @"The 'urls' value is invalid, because '$' is an invalid match pattern. \"$\" cannot be parsed because it doesn't have a scheme.");
}

static _WKWebExtensionWebRequestFilter *filterWithDictionary(NSDictionary *dictionary)
{
    NSString *error;
    _WKWebExtensionWebRequestFilter *filter = [[_WKWebExtensionWebRequestFilter alloc] initWithDictionary:dictionary outErrorMessage:&error];
    EXPECT_NOT_NULL(filter);
    EXPECT_NULL(error);

    return filter;
}

TEST(WKWebExtensionAPIWebRequest, TabIDMatch)
{
    NSURL *url = [NSURL URLWithString:@"http://example.com/a"];
    _WKWebExtensionWebRequestResourceType type = _WKWebExtensionWebRequestResourceTypeOther;

    auto filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*" ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:100 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*" ],
        @"tabId": @(-1),
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:100 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*" ],
        @"tabId": @(100),
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:100 windowID:1]);
    EXPECT_FALSE([filter matchesRequestForResourceOfType:type URL:url tabID:200 windowID:1]);
}

TEST(WKWebExtensionAPIWebRequest, WindowIDMatch)
{
    NSURL *url = [NSURL URLWithString:@"http://example.com/a"];
    _WKWebExtensionWebRequestResourceType type = _WKWebExtensionWebRequestResourceTypeOther;

    auto filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*" ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:-1 windowID:-1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*" ],
        @"windowId": @(-1),
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*" ],
        @"windowId": @(100),
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:100]);
    EXPECT_FALSE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:200]);
}

TEST(WKWebExtensionAPIWebRequest, URLMatch)
{
    NSURL *url = [NSURL URLWithString:@"http://example.com/a/b"];
    NSURL *otherURL = [NSURL URLWithString:@"http://some-other-website.biz/a/b"];
    _WKWebExtensionWebRequestResourceType type = _WKWebExtensionWebRequestResourceTypeOther;

    auto filter = filterWithDictionary(@{
        @"urls": @[ ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:1]);
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:otherURL tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*" ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:1]);
    EXPECT_FALSE([filter matchesRequestForResourceOfType:type URL:otherURL tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://not-example.com/*", @"http://not-some-other-website.biz/*" ],
    });
    EXPECT_FALSE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*", @"http://not-some-other-website.biz/*" ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:1]);
    EXPECT_FALSE([filter matchesRequestForResourceOfType:type URL:otherURL tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ @"http://example.com/*/b", @"http://example.com/a/*" ]
    });

    EXPECT_TRUE([filter matchesRequestForResourceOfType:type URL:url tabID:1 windowID:1]);
}

TEST(WKWebExtensionAPIWebRequest, ResourceTypesMatch)
{
    NSURL *url = [NSURL URLWithString:@"http://example.com/a/b"];

    auto filter = filterWithDictionary(@{
        @"urls": @[ ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeImage URL:url tabID:1 windowID:1]);
    EXPECT_TRUE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeScript URL:url tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ ],
        @"types": @[ ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeImage URL:url tabID:1 windowID:1]);
    EXPECT_TRUE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeScript URL:url tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ ],
        @"types": @[ @"image" ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeImage URL:url tabID:1 windowID:1]);
    EXPECT_FALSE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeScript URL:url tabID:1 windowID:1]);

    filter = filterWithDictionary(@{
        @"urls": @[ ],
        @"types": @[ @"image", @"script" ],
    });
    EXPECT_TRUE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeImage URL:url tabID:1 windowID:1]);
    EXPECT_TRUE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeScript URL:url tabID:1 windowID:1]);
    EXPECT_FALSE([filter matchesRequestForResourceOfType:_WKWebExtensionWebRequestResourceTypeWebsocket URL:url tabID:1 windowID:1]);
}

} // namespace TestWebKitAPI

#endif // ENABLE(WK_WEB_EXTENSIONS)
