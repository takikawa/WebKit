/*
 * Copyright (C) 2010-2020 Apple Inc. All rights reserved.
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

#if PLATFORM(MAC)

#include "FrameInfoData.h"
#include "WebContextMenuProxy.h"
#include <wtf/RetainPtr.h>
#include <wtf/WeakObjCPtr.h>

OBJC_CLASS NSMenu;
OBJC_CLASS NSMenuItem;
OBJC_CLASS NSView;
OBJC_CLASS NSWindow;
OBJC_CLASS WKMenuDelegate;

#if ENABLE(WRITING_TOOLS)
namespace WebCore::WritingTools {
enum class RequestedTool : uint16_t;
}
#endif

namespace WebKit {

class WebContextMenuItemData;

class WebContextMenuProxyMac final : public WebContextMenuProxy {
public:
    static auto create(NSView *webView, WebPageProxy& page, FrameInfoData&& frameInfo, ContextMenuContextData&& context, const UserData& userData)
    {
        return adoptRef(*new WebContextMenuProxyMac(webView, page, WTFMove(frameInfo), WTFMove(context), userData));
    }
    ~WebContextMenuProxyMac();

    void contextMenuItemSelected(const WebContextMenuItemData&);

#if ENABLE(WRITING_TOOLS)
    void handleContextMenuWritingTools(WebCore::WritingTools::RequestedTool);
#endif

    void handleShareMenuItem();

#if ENABLE(SERVICE_CONTROLS)
    void clearServicesMenu();
    void removeBackgroundFromControlledImage();
#endif

    NSWindow *window() const;

#if ENABLE(IMAGE_ANALYSIS_ENHANCEMENTS)
    RetainPtr<CGImageRef> imageForCopySubject() const final { return m_copySubjectResult; }
#endif

private:
    WebContextMenuProxyMac(NSView *, WebPageProxy&, FrameInfoData&&, ContextMenuContextData&&, const UserData&);

    void show() override;
    void showContextMenuWithItems(Vector<Ref<WebContextMenuItem>>&&) override;
    void useContextMenuItems(Vector<Ref<WebContextMenuItem>>&&) override;

    bool showAfterPostProcessingContextData();

    void getContextMenuItem(const WebContextMenuItemData&, CompletionHandler<void(NSMenuItem *)>&&);
    void getContextMenuFromItems(const Vector<WebContextMenuItemData>&, CompletionHandler<void(NSMenu *)>&&);

#if ENABLE(SERVICE_CONTROLS)
    enum class ShareMenuItemType : uint8_t { Placeholder, Popover };
    RetainPtr<NSMenuItem> createShareMenuItem(ShareMenuItemType);

    void showServicesMenu();
    void setupServicesMenu();
    void appendRemoveBackgroundItemToControlledImageMenuIfNeeded();
#endif

    NSMenu *platformMenu() const override;
    RetainPtr<NSArray> platformData() const override;

    RetainPtr<NSMenu> m_menu;
    RetainPtr<WKMenuDelegate> m_menuDelegate;
    WeakObjCPtr<NSView> m_webView;
#if ENABLE(IMAGE_ANALYSIS_ENHANCEMENTS)
    RetainPtr<CGImageRef> m_copySubjectResult;
#endif
    const FrameInfoData m_frameInfo;
};

} // namespace WebKit

#endif // PLATFORM(MAC)
