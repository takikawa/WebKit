/*
 * Copyright (c) 2021, Igalia S.L. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#pragma once

#include "CachedResourceHandle.h"
#include "CachedScript.h"
#include "CachedScriptFetcher.h"
#include <JavaScriptCore/SourceCode.h>
#include <JavaScriptCore/SourceProvider.h>
#include <wtf/RefPtr.h>
#include <wtf/URL.h>

namespace WebCore {

class WebAssemblyScriptSourceCode {
public:
    WebAssemblyScriptSourceCode(CachedScript* cachedScript, Ref<CachedScriptFetcher>&& scriptFetcher)
        : m_provider(JSC::WebAssemblySourceProvider::create(cachedScript->resourceBuffer()->copyData(), JSC::SourceOrigin { cachedScript->response().url(), WTFMove(scriptFetcher) }, cachedScript->response().url().string()))
        , m_code(m_provider.copyRef())
        , m_cachedScript(cachedScript)
    {
    }

    WebAssemblyScriptSourceCode(const SharedBuffer& source, URL&& url, Ref<JSC::ScriptFetcher>&& scriptFetcher)
        // FIXME: copyData() or extractData()?
        : m_provider(JSC::WebAssemblySourceProvider::create(source.copyData(), JSC::SourceOrigin { url, WTFMove(scriptFetcher) }, url.string()))
        , m_code(m_provider.copyRef())
    {
    }

    const JSC::SourceCode& jsSourceCode() const { return m_code; }

private:
    Ref<JSC::SourceProvider> m_provider;
    JSC::SourceCode m_code;
    CachedResourceHandle<CachedScript> m_cachedScript;
};

} // namespace WebCore
