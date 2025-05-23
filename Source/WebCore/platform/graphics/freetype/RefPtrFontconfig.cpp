/*
 *  Copyright (C) 2010 Igalia S.L.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "config.h"
#include "RefPtrFontconfig.h"

#if USE(FREETYPE)

#include <fontconfig/fontconfig.h>

namespace WTF {

FcPattern* DefaultRefDerefTraits<FcPattern>::refIfNotNull(FcPattern* ptr)
{
    if (ptr) [[likely]]
        FcPatternReference(ptr);
    return ptr;
}

void DefaultRefDerefTraits<FcPattern>::derefIfNotNull(FcPattern* ptr)
{
    if (ptr) [[likely]]
        FcPatternDestroy(ptr);
}

FcConfig* DefaultRefDerefTraits<FcConfig>::refIfNotNull(FcConfig* ptr)
{
    if (ptr) [[likely]]
        FcConfigReference(ptr);
    return ptr;
}

void DefaultRefDerefTraits<FcConfig>::derefIfNotNull(FcConfig* ptr)
{
    if (ptr) [[likely]]
        FcConfigDestroy(ptr);
}

} // namespace WTF

#endif // USE(FREETYPE)
