/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * (C) 2002-2003 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2002-2025 Apple Inc. All rights reserved.
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
 */

#include "config.h"
#include "StyleRuleImport.h"

#include "CSSStyleSheet.h"
#include "CachedCSSStyleSheet.h"
#include "CachedResourceLoader.h"
#include "CachedResourceRequest.h"
#include "CachedResourceRequestInitiatorTypes.h"
#include "Document.h"
#include "DocumentInlines.h"
#include "MediaList.h"
#include "MediaQueryParserContext.h"
#include "Page.h"
#include "SecurityOrigin.h"
#include "StyleSheetContents.h"
#include <wtf/StdLibExtras.h>

namespace WebCore {
DEFINE_ALLOCATOR_WITH_HEAP_IDENTIFIER(StyleRuleImport);

Ref<StyleRuleImport> StyleRuleImport::create(const String& href, MQ::MediaQueryList&& mediaQueries, std::optional<CascadeLayerName>&& cascadeLayerName, SupportsCondition&& supportsCondition)
{
    return adoptRef(*new StyleRuleImport(href, WTFMove(mediaQueries), WTFMove(cascadeLayerName), WTFMove(supportsCondition)));
}

StyleRuleImport::StyleRuleImport(const String& href, MQ::MediaQueryList&& mediaQueries, std::optional<CascadeLayerName>&& cascadeLayerName, SupportsCondition&& supportsCondition)
    : StyleRuleBase(StyleRuleType::Import)
    , m_styleSheetClient(this)
    , m_strHref(href)
    , m_mediaQueries(WTFMove(mediaQueries))
    , m_cascadeLayerName(WTFMove(cascadeLayerName))
    , m_supportsCondition(WTFMove(supportsCondition))
{
}

void StyleRuleImport::cancelLoad()
{
    if (!isLoading())
        return;

    m_loading = false;
    if (m_parentStyleSheet)
        m_parentStyleSheet->checkLoaded();
}

StyleRuleImport::~StyleRuleImport()
{
    if (m_styleSheet)
        m_styleSheet->clearOwnerRule();
    if (m_cachedSheet)
        m_cachedSheet->removeClient(m_styleSheetClient);
}

void StyleRuleImport::setCSSStyleSheet(const String& href, const URL& baseURL, ASCIILiteral charset, const CachedCSSStyleSheet* cachedStyleSheet)
{
    if (m_styleSheet)
        m_styleSheet->clearOwnerRule();

    CSSParserContext context = m_parentStyleSheet ? m_parentStyleSheet->parserContext() : HTMLStandardMode;
    context.charset = charset;
    if (!baseURL.isNull())
        context.baseURL = baseURL;

    Document* document = m_parentStyleSheet ? m_parentStyleSheet->singleOwnerDocument() : nullptr;
    m_styleSheet = StyleSheetContents::create(this, href, context);
    if ((m_parentStyleSheet && m_parentStyleSheet->loadedFromOpaqueSource() == LoadedFromOpaqueSource::Yes) || !cachedStyleSheet->isCORSSameOrigin())
        m_styleSheet->setAsLoadedFromOpaqueSource();

    bool parseSucceeded = m_styleSheet->parseAuthorStyleSheet(cachedStyleSheet, document ? &document->securityOrigin() : nullptr);

    m_loading = false;

    if (m_parentStyleSheet) {
        if (parseSucceeded)
            m_parentStyleSheet->notifyLoadedSheet(cachedStyleSheet);
        else
            m_parentStyleSheet->setLoadErrorOccured();
        m_parentStyleSheet->checkLoaded();
    }
}

bool StyleRuleImport::isLoading() const
{
    return m_loading || (m_styleSheet && m_styleSheet->isLoading());
}

void StyleRuleImport::requestStyleSheet()
{
    if (!m_parentStyleSheet)
        return;
    auto* document = m_parentStyleSheet->singleOwnerDocument();
    if (!document)
        return;
    auto* page = document->page();
    if (!page)
        return;

    URL absURL;
    if (!m_parentStyleSheet->baseURL().isNull())
        // use parent styleheet's URL as the base URL
        absURL = URL(m_parentStyleSheet->baseURL(), m_strHref);
    else
        absURL = document->completeURL(m_strHref);

    // Check for a cycle in our import chain.  If we encounter a stylesheet
    // in our parent chain with the same URL, then just bail.
    StyleSheetContents* rootSheet = m_parentStyleSheet;
    for (StyleSheetContents* sheet = m_parentStyleSheet; sheet; sheet = sheet->parentStyleSheet()) {
        if (equalIgnoringFragmentIdentifier(absURL, sheet->baseURL())
            || equalIgnoringFragmentIdentifier(absURL, document->completeURL(sheet->originalURL())))
            return;
        rootSheet = sheet;
    }

    // FIXME: Skip Content Security Policy check when stylesheet is in a user agent shadow tree.
    // See <https://bugs.webkit.org/show_bug.cgi?id=146663>.
    CachedResourceRequest request(WTFMove(absURL), CachedResourceLoader::defaultCachedResourceOptions(), std::nullopt, String(m_parentStyleSheet->charset()));
    request.setInitiatorType(cachedResourceRequestInitiatorTypes().css);
    if (m_cachedSheet)
        m_cachedSheet->removeClient(m_styleSheetClient);
    if (m_parentStyleSheet->isUserStyleSheet()) {
        ResourceLoaderOptions options {
            SendCallbackPolicy::DoNotSendCallbacks,
            ContentSniffingPolicy::SniffContent,
            DataBufferingPolicy::BufferData,
            StoredCredentialsPolicy::Use,
            ClientCredentialPolicy::MayAskClientForCredentials,
            FetchOptions::Credentials::Include,
            SecurityCheckPolicy::SkipSecurityCheck,
            FetchOptions::Mode::NoCors,
            CertificateInfoPolicy::DoNotIncludeCertificateInfo,
            ContentSecurityPolicyImposition::SkipPolicyCheck,
            DefersLoadingPolicy::AllowDefersLoading,
            CachingPolicy::AllowCaching
        };
        options.loadedFromOpaqueSource = m_parentStyleSheet->loadedFromOpaqueSource();

        request.setOptions(WTFMove(options));

        m_cachedSheet = document->protectedCachedResourceLoader()->requestUserCSSStyleSheet(*page, WTFMove(request));
    } else {
        auto options = request.options();
        options.loadedFromOpaqueSource = m_parentStyleSheet->loadedFromOpaqueSource();
        request.setOptions(WTFMove(options));
        m_cachedSheet = document->protectedCachedResourceLoader()->requestCSSStyleSheet(WTFMove(request)).value_or(nullptr);
    }
    if (m_cachedSheet) {
        // if the import rule is issued dynamically, the sheet may be
        // removed from the pending sheet count, so let the doc know
        // the sheet being imported is pending.
        if (m_parentStyleSheet && m_parentStyleSheet->loadCompleted() && rootSheet == m_parentStyleSheet)
            m_parentStyleSheet->startLoadingDynamicSheet();
        m_loading = true;
        m_cachedSheet->addClient(m_styleSheetClient);
    } else if (m_parentStyleSheet) {
        m_parentStyleSheet->setLoadErrorOccured();
        m_parentStyleSheet->checkLoaded();
    }
}

} // namespace WebCore
