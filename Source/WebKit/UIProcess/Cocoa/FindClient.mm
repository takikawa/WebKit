/*
 * Copyright (C) 2014 Apple Inc. All rights reserved.
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
#import "FindClient.h"

#import "_WKFindDelegate.h"
#import <wtf/TZoneMallocInlines.h>

namespace WebKit {

WTF_MAKE_TZONE_ALLOCATED_IMPL(FindClient);

FindClient::FindClient(WKWebView *webView)
    : m_webView(webView)
{
}
    
RetainPtr<id <_WKFindDelegate>> FindClient::delegate()
{
    return m_delegate.get();
}

void FindClient::setDelegate(id <_WKFindDelegate> delegate)
{
    m_delegate = delegate;

    m_delegateMethods.webviewDidCountStringMatches = [delegate respondsToSelector:@selector(_webView:didCountMatches:forString:)];
    m_delegateMethods.webviewDidFindString = [delegate respondsToSelector:@selector(_webView:didFindMatches:forString:withMatchIndex:)];
    m_delegateMethods.webviewDidFailToFindString = [delegate respondsToSelector:@selector(_webView:didFailToFindString:)];
    m_delegateMethods.webviewDidAddLayerForFindOverlay = [delegate respondsToSelector:@selector(_webView:didAddLayerForFindOverlay:)];
    m_delegateMethods.webviewDidRemoveLayerForFindOverlay = [delegate respondsToSelector:@selector(_webViewDidRemoveLayerForFindOverlay:)];
}
    
void FindClient::didCountStringMatches(WebPageProxy*, const String& string, uint32_t matchCount)
{
    if (m_delegateMethods.webviewDidCountStringMatches)
        [m_delegate.get() _webView:m_webView.get().get() didCountMatches:matchCount forString:string.createNSString().get()];
}

void FindClient::didFindString(WebPageProxy*, const String& string, const Vector<WebCore::IntRect>&, uint32_t matchCount, int32_t matchIndex, bool)
{
    if (m_delegateMethods.webviewDidFindString)
        [m_delegate.get() _webView:m_webView.get().get() didFindMatches:matchCount forString:string.createNSString().get() withMatchIndex:matchIndex];
}

void FindClient::didFailToFindString(WebPageProxy*, const String& string)
{
    if (m_delegateMethods.webviewDidFailToFindString)
        [m_delegate.get() _webView:m_webView.get().get() didFailToFindString:string.createNSString().get()];
}

void FindClient::didAddLayerForFindOverlay(WebKit::WebPageProxy*, PlatformLayer* layer)
{
    if (m_delegateMethods.webviewDidAddLayerForFindOverlay)
        [m_delegate _webView:m_webView.get().get() didAddLayerForFindOverlay:layer];
}

void FindClient::didRemoveLayerForFindOverlay(WebKit::WebPageProxy*)
{
    if (m_delegateMethods.webviewDidRemoveLayerForFindOverlay)
        [m_delegate _webViewDidRemoveLayerForFindOverlay:m_webView.get().get()];
}

} // namespace WebKit
