/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * (C) 2002-2003 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2002, 2005, 2006, 2008, 2012 Apple Inc. All rights reserved.
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
#include "CSSFontFaceRule.h"

#include "CSSFontFaceDescriptors.h"
#include "CSSSerializationContext.h"
#include "MutableStyleProperties.h"
#include "StyleProperties.h"
#include "StyleRule.h"
#include <wtf/text/MakeString.h>
#include <wtf/text/StringBuilder.h>

namespace WebCore {

CSSFontFaceRule::CSSFontFaceRule(StyleRuleFontFace& fontFaceRule, CSSStyleSheet* parent)
    : CSSRule(parent)
    , m_fontFaceRule(fontFaceRule)
{
}

CSSFontFaceRule::~CSSFontFaceRule()
{
    if (m_propertiesCSSOMWrapper)
        m_propertiesCSSOMWrapper->clearParentRule();
}

CSSFontFaceDescriptors& CSSFontFaceRule::style()
{
    if (!m_propertiesCSSOMWrapper)
        m_propertiesCSSOMWrapper = CSSFontFaceDescriptors::create(m_fontFaceRule->mutableProperties(), *this);
    return *m_propertiesCSSOMWrapper;
}

String CSSFontFaceRule::cssText() const
{
    return cssTextInternal(m_fontFaceRule->properties().asText(CSS::defaultSerializationContext()));
}

String CSSFontFaceRule::cssText(const CSS::SerializationContext& context) const
{
    return cssTextInternal(m_fontFaceRule->properties().asText(context));
}

String CSSFontFaceRule::cssTextInternal(const String& declarations) const
{
    if (declarations.isEmpty())
        return "@font-face { }"_s;

    return makeString("@font-face { "_s, declarations, " }"_s);
}

void CSSFontFaceRule::reattach(StyleRuleBase& rule)
{
    m_fontFaceRule = downcast<StyleRuleFontFace>(rule);
    if (m_propertiesCSSOMWrapper)
        m_propertiesCSSOMWrapper->reattach(m_fontFaceRule->mutableProperties());
}

} // namespace WebCore
