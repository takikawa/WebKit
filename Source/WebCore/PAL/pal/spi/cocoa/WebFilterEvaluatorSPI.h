/*
 * Copyright (C) 2015-2024 Apple Inc. All rights reserved.
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

DECLARE_SYSTEM_HEADER

#if USE(APPLE_INTERNAL_SDK)

#if HAVE(WEBCONTENTANALYSIS_FRAMEWORK)
#import <WebContentAnalysis/WebFilterEvaluator.h>
#endif

#else

#import <TargetConditionals.h>

enum {
    kWFEStateAllowed = 0,
    kWFEStateBlocked = 1,
    kWFEStateBuffering = 2,
    kWFEStateEvaluating = 3
};

@interface WebFilterEvaluator : NSObject
@end

@interface WebFilterEvaluator ()
+ (BOOL)isManagedSession;
- (BOOL)wasBlocked;
- (NSData *)addData:(NSData *)receivedData;
- (NSData *)dataComplete;
- (OSStatus)filterState;
- (id)initWithResponse:(NSURLResponse *)response;
#if TARGET_OS_IPHONE
- (void)unblockWithCompletion:(void (^)(BOOL unblocked, NSError *error))completion;
#endif
#if HAVE(WEBFILTEREVALUATOR_AUDIT_TOKEN)
@property (nonatomic, assign) audit_token_t browserAuditToken;
#endif
@end

#endif
