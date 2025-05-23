/*
 * Copyright (C) 2017-2022 Apple Inc. All rights reserved.
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

#if HAVE(SCREEN_CAPTURE_KIT)

#import "PlatformUtilities.h"
#import "Test.h"
#import "TestWKWebView.h"
#import "UserMediaCaptureUIDelegate.h"
#import <WebKit/WKPagePrivate.h>
#import <WebKit/WKPreferencesPrivate.h>
#import <WebKit/WKUIDelegatePrivate.h>
#import <WebKit/WKWebViewConfiguration.h>
#import <WebKit/WKWebViewConfigurationPrivate.h>
#import <WebKit/WKWebViewPrivate.h>
#import <WebKit/WKWebViewPrivateForTesting.h>

static bool messageReceived;
@interface WKWebView ()
- (WKPageRef)_pageForTesting;
@end

@interface WindowAndScreenCaptureTestView : TestWKWebView
- (BOOL)haveStream:(BOOL)expected;
@end

@implementation WindowAndScreenCaptureTestView
- (BOOL)haveStream:(BOOL)expected
{
    int retryCount = 1000;
    while (retryCount--) {
        auto result = [self stringByEvaluatingJavaScript:@"haveStream()"];
        if (result.boolValue == expected)
            return YES;

        TestWebKitAPI::Util::spinRunLoop(10);
    }

    return NO;
}
@end

@interface DisplayCaptureObserver : NSObject {
    WKDisplayCaptureSurfaces _displayCaptureSurfaces;
    WKDisplayCaptureState _displayCaptureState;
}

@property WKDisplayCaptureState displayCaptureState;
@property WKDisplayCaptureSurfaces displayCaptureSurfaces;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context;
- (BOOL)waitForDisplayCaptureState:(WKDisplayCaptureState)expectedState;
- (BOOL)waitForDisplayCaptureSurfaces:(WKDisplayCaptureSurfaces)expectedState;
@end

@implementation DisplayCaptureObserver

@synthesize displayCaptureSurfaces = _displayCaptureSurfaces;
@synthesize displayCaptureState = _displayCaptureState;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context
{
    EXPECT_TRUE([keyPath isEqualToString:NSStringFromSelector(@selector(_displayCaptureSurfaces))] || [keyPath isEqualToString:NSStringFromSelector(@selector(_displayCaptureState))]);

    if ([keyPath isEqualToString:NSStringFromSelector(@selector(_displayCaptureSurfaces))]) {
        _displayCaptureSurfaces = (WKDisplayCaptureSurfaces)[[change objectForKey:NSKeyValueChangeNewKey] unsignedIntegerValue];
        return;
    }
    _displayCaptureState = (WKDisplayCaptureState)[[change objectForKey:NSKeyValueChangeNewKey] unsignedIntegerValue];
}

static constexpr unsigned stateChangeQueryMaxCount = 30;

- (BOOL)waitForDisplayCaptureState:(WKDisplayCaptureState)expectedState
{
    unsigned tries = 0;
    do {
        if (expectedState == _displayCaptureState)
            return YES;
        TestWebKitAPI::Util::runFor(0.1_s);
    } while (++tries <= stateChangeQueryMaxCount);

    return expectedState == _displayCaptureState;
}

- (BOOL)waitForDisplayCaptureSurfaces:(WKDisplayCaptureSurfaces)expectedState
{
    unsigned tries = 0;
    do {
        if (expectedState == _displayCaptureSurfaces)
            return YES;
        TestWebKitAPI::Util::runFor(0.1_s);
    } while (++tries <= stateChangeQueryMaxCount);

    return expectedState == _displayCaptureSurfaces;
}
@end

@interface DisplayGUMMessageHandler : NSObject <WKScriptMessageHandler>
@end

@implementation DisplayGUMMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    EXPECT_WK_STREQ(@"PASS", [message body]);
    messageReceived = true;
}
@end

namespace TestWebKitAPI {

TEST(WebKit2, GetDisplayMediaWindowAndScreenPrompt)
{
    auto configuration = adoptNS([[WKWebViewConfiguration alloc] init]);
    auto context = adoptWK(TestWebKitAPI::Util::createContextForInjectedBundleTest("InternalsInjectedBundleTest"));

    configuration.get().processPool = (WKProcessPool *)context.get();
    configuration.get()._mediaCaptureEnabled = YES;

    auto preferences = [configuration preferences];
    preferences._mediaCaptureRequiresSecureConnection = NO;
    preferences._mockCaptureDevicesEnabled = YES;

    auto delegate = adoptNS([[UserMediaCaptureUIDelegate alloc] init]);
    auto webView = adoptNS([[WindowAndScreenCaptureTestView alloc] initWithFrame:CGRectMake(0, 0, 320, 500) configuration:configuration.get()]);
    [webView setUIDelegate:delegate.get()];

    auto observer = adoptNS([[DisplayCaptureObserver alloc] init]);
    [webView addObserver:observer.get() forKeyPath:@"_displayCaptureSurfaces" options:NSKeyValueObservingOptionNew context:nil];
    [webView addObserver:observer.get() forKeyPath:@"_displayCaptureState" options:NSKeyValueObservingOptionNew context:nil];

    [webView synchronouslyLoadTestPageNamed:@"getDisplayMedia"];
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateNone);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceNone);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateNone);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceNone);

    // Check "Don’t Allow"
    [delegate setGetDisplayMediaDecision:WKDisplayCapturePermissionDecisionDeny];
    [webView stringByEvaluatingJavaScript:@"promptForCapture({ video : true })"];
    [delegate waitUntilPrompted];
    EXPECT_TRUE([webView haveStream:NO]);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateNone);
    EXPECT_TRUE([webView _displayCaptureSurfaces] == WKDisplayCaptureSurfaceNone);

    auto hasSleepDisabler = [webView stringByEvaluatingJavaScript:@"hasSleepDisabler()"].boolValue;
    EXPECT_FALSE(hasSleepDisabler);

    // Check "Allow Screen"
    [webView stringByEvaluatingJavaScript:@"stop()"];
    [delegate resetWasPrompted];

    hasSleepDisabler = [webView stringByEvaluatingJavaScript:@"hasSleepDisabler()"].boolValue;
    EXPECT_FALSE(hasSleepDisabler);

    [webView _setIndexOfGetDisplayMediaDeviceSelectedForTesting:@0];
    [delegate setGetDisplayMediaDecision:WKDisplayCapturePermissionDecisionScreenPrompt];
    [webView stringByEvaluatingJavaScript:@"promptForCapture({ video : true })"];
    [delegate waitUntilPrompted];
    EXPECT_TRUE([webView haveStream:YES]);
    auto label = [webView stringByEvaluatingJavaScript:@"stream.getVideoTracks()[0].label"];
    EXPECT_WK_STREQ(label, @"Mock screen device 1");
    EXPECT_TRUE([observer waitForDisplayCaptureState:WKDisplayCaptureStateActive]);
    EXPECT_TRUE([observer waitForDisplayCaptureSurfaces:WKDisplayCaptureSurfaceScreen]);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([observer displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([webView _displayCaptureSurfaces] == WKDisplayCaptureSurfaceScreen);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceScreen);

    hasSleepDisabler = [webView stringByEvaluatingJavaScript:@"hasSleepDisabler()"].boolValue;
    EXPECT_TRUE(hasSleepDisabler);

    // Mute and unmute screen capture
    __block bool completionCalled = false;
    [webView _setDisplayCaptureState:WKDisplayCaptureStateMuted completionHandler:^() {
        completionCalled = true;
    }];
    TestWebKitAPI::Util::run(&completionCalled);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateMuted);
    EXPECT_TRUE([observer displayCaptureState] == WKDisplayCaptureStateMuted);
    EXPECT_TRUE([webView _displayCaptureSurfaces] == WKDisplayCaptureSurfaceScreen);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceScreen);

    completionCalled = false;
    [webView _setDisplayCaptureState:WKDisplayCaptureStateActive completionHandler:^() {
        completionCalled = true;
    }];
    TestWebKitAPI::Util::run(&completionCalled);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([observer displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([webView _displayCaptureSurfaces] == WKDisplayCaptureSurfaceScreen);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceScreen);

    hasSleepDisabler = [webView stringByEvaluatingJavaScript:@"hasSleepDisabler()"].boolValue;
    EXPECT_TRUE(hasSleepDisabler);

    // Stop all capture
    [webView stringByEvaluatingJavaScript:@"stop()"];
    EXPECT_TRUE([observer waitForDisplayCaptureState:WKDisplayCaptureStateNone]);
    EXPECT_TRUE([observer waitForDisplayCaptureSurfaces:WKDisplayCaptureSurfaceNone]);

    hasSleepDisabler = [webView stringByEvaluatingJavaScript:@"hasSleepDisabler()"].boolValue;
    EXPECT_FALSE(hasSleepDisabler);

    // Check "Allow Window"
    [delegate resetWasPrompted];
    [webView _setIndexOfGetDisplayMediaDeviceSelectedForTesting:@0];
    [delegate setGetDisplayMediaDecision:WKDisplayCapturePermissionDecisionWindowPrompt];
    [webView stringByEvaluatingJavaScript:@"promptForCapture({ video : true })"];
    [delegate waitUntilPrompted];
    EXPECT_TRUE([webView haveStream:YES]);
    label = [webView stringByEvaluatingJavaScript:@"stream.getVideoTracks()[0].label"];
    EXPECT_WK_STREQ(label, @"Mock window device 1");
    EXPECT_TRUE([observer waitForDisplayCaptureState:WKDisplayCaptureStateActive]);
    EXPECT_TRUE([observer waitForDisplayCaptureSurfaces:WKDisplayCaptureSurfaceWindow]);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([observer displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([webView _displayCaptureSurfaces] == WKDisplayCaptureSurfaceWindow);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceWindow);

    // Mute and unmute with ObjC SPI
    completionCalled = false;
    [webView _setDisplayCaptureState:WKDisplayCaptureStateMuted completionHandler:^() {
        completionCalled = true;
    }];
    TestWebKitAPI::Util::run(&completionCalled);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateMuted);
    EXPECT_TRUE([observer displayCaptureState] == WKDisplayCaptureStateMuted);
    EXPECT_TRUE([webView _displayCaptureSurfaces] == WKDisplayCaptureSurfaceWindow);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceWindow);

    completionCalled = false;
    [webView _setDisplayCaptureState:WKDisplayCaptureStateActive completionHandler:^() {
        completionCalled = true;
    }];
    TestWebKitAPI::Util::run(&completionCalled);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([observer displayCaptureState] == WKDisplayCaptureStateActive);
    EXPECT_TRUE([webView _displayCaptureSurfaces] == WKDisplayCaptureSurfaceWindow);
    EXPECT_TRUE([observer displayCaptureSurfaces] == WKDisplayCaptureSurfaceWindow);

    // Mute and unmute with C SPI
    WKPageSetMuted([webView _pageForTesting], kWKMediaScreenCaptureMuted);
    EXPECT_TRUE([observer waitForDisplayCaptureState:WKDisplayCaptureStateMuted]);
    WKPageSetMuted([webView _pageForTesting], kWKMediaScreenCaptureUnmuted);
    EXPECT_TRUE([observer waitForDisplayCaptureState:WKDisplayCaptureStateActive]);

    [webView stringByEvaluatingJavaScript:@"stop()"];
    [webView _setIndexOfGetDisplayMediaDeviceSelectedForTesting:nil];

    [webView removeObserver:observer.get() forKeyPath:@"_displayCaptureSurfaces"];
    [webView removeObserver:observer.get() forKeyPath:@"_displayCaptureState"];
}

TEST(WebKit2, ToggleScreenshare)
{
    auto configuration = adoptNS([[WKWebViewConfiguration alloc] init]);
    WKPreferencesSetBoolValueForKeyForTesting((__bridge WKPreferencesRef)[configuration preferences], true, WKStringCreateWithUTF8CString("MediaSessionCaptureToggleAPIEnabled"));

    auto context = adoptWK(TestWebKitAPI::Util::createContextForInjectedBundleTest("InternalsInjectedBundleTest"));
    configuration.get().processPool = (WKProcessPool *)context.get();

    configuration.get()._mediaCaptureEnabled = YES;
    auto preferences = [configuration preferences];
    preferences._mediaCaptureRequiresSecureConnection = NO;
    preferences._mockCaptureDevicesEnabled = YES;

    auto messageHandler = adoptNS([[DisplayGUMMessageHandler alloc] init]);
    [[configuration.get() userContentController] addScriptMessageHandler:messageHandler.get() name:@"gum"];

    auto webView = adoptNS([[TestWKWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 500) configuration:configuration.get()]);

    auto delegate = adoptNS([[UserMediaCaptureUIDelegate alloc] init]);
    [webView setUIDelegate:delegate.get()];
    [webView _setMediaCaptureReportingDelayForTesting:0];

    auto observer = adoptNS([[DisplayCaptureObserver alloc] init]);
    [webView addObserver:observer.get() forKeyPath:@"_displayCaptureState" options:NSKeyValueObservingOptionNew context:nil];

    messageReceived = false;
    [webView synchronouslyLoadTestPageNamed:@"media-session-capture"];
    TestWebKitAPI::Util::run(&messageReceived);

    [delegate setGetDisplayMediaDecision:WKDisplayCapturePermissionDecisionScreenPrompt];

    messageReceived = false;
    [webView stringByEvaluatingJavaScript:@"startScreenshareCapture()"];
    TestWebKitAPI::Util::run(&messageReceived);
    EXPECT_TRUE([webView _displayCaptureState] == WKDisplayCaptureStateActive);

    // Mute capture.
    __block bool completionCalled = false;
    [webView _setDisplayCaptureState:WKDisplayCaptureStateMuted completionHandler:^() {
        completionCalled = true;
    }];
    TestWebKitAPI::Util::run(&completionCalled);
    EXPECT_EQ([webView _displayCaptureState], WKDisplayCaptureStateMuted);

    [delegate resetWasPrompted];
    [delegate setGetDisplayMediaDecision:WKDisplayCapturePermissionDecisionDeny];

    // Try unmuting via MediaSession.
    messageReceived = false;
    [webView stringByEvaluatingJavaScript:@"setScreenshareActive(true, false)"];
    TestWebKitAPI::Util::run(&messageReceived);

    EXPECT_EQ([webView _displayCaptureState], WKDisplayCaptureStateMuted);
    EXPECT_TRUE([delegate wasPrompted]);

    [delegate resetWasPrompted];
    [delegate setGetDisplayMediaDecision:WKDisplayCapturePermissionDecisionScreenPrompt];

    // Unmute via MediaSession.
    messageReceived = false;
    [webView stringByEvaluatingJavaScript:@"setScreenshareActive(true, true)"];
    TestWebKitAPI::Util::run(&messageReceived);

    EXPECT_EQ([webView _displayCaptureState], WKDisplayCaptureStateActive);
    EXPECT_TRUE([delegate wasPrompted]);

    // Validate handlers/events order.
    messageReceived = false;
    [webView stringByEvaluatingJavaScript:@"validateActionState('deactivating screenshare, muting screenshare, setScreenshareActive not successful, setScreenshareActive successful, unmuting screenshare, end')"];

    [delegate resetWasPrompted];

    // Mute via MediaSession.
    messageReceived = false;
    [webView stringByEvaluatingJavaScript:@"setScreenshareActive(false, true)"];
    TestWebKitAPI::Util::run(&messageReceived);

    EXPECT_EQ([webView _displayCaptureState], WKDisplayCaptureStateMuted);
    EXPECT_FALSE([delegate wasPrompted]);

    // Unmute via MediaSession.
    messageReceived = false;
    [webView stringByEvaluatingJavaScript:@"setScreenshareActive(true, true)"];
    TestWebKitAPI::Util::run(&messageReceived);

    EXPECT_EQ([webView _displayCaptureState], WKDisplayCaptureStateActive);
    EXPECT_FALSE([delegate wasPrompted]);

    // Validate handlers/events order.
    messageReceived = false;
    [webView stringByEvaluatingJavaScript:@"validateActionState('setScreenshareActive successful, muting screenshare, setScreenshareActive successful, unmuting screenshare, end')"];
    TestWebKitAPI::Util::run(&messageReceived);

    [webView removeObserver:observer.get() forKeyPath:@"_displayCaptureState"];
}

} // namespace TestWebKitAPI

#endif // HAVE(SCREEN_CAPTURE_KIT)
