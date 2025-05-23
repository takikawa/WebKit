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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import "config.h"
#import "PlatformCAAnimationCocoa.h"

#import "FloatConversion.h"
#import "PlatformCAFilters.h"
#import "TimingFunction.h"
#import <QuartzCore/QuartzCore.h>
#import <pal/spi/cocoa/QuartzCoreSPI.h>
#import <wtf/cocoa/VectorCocoa.h>
#import <wtf/text/WTFString.h>

namespace WebCore {

constexpr NSString * const WKExplicitBeginTimeFlag = @"WKPlatformCAAnimationExplicitBeginTimeFlag";

bool hasExplicitBeginTime(CAAnimation *animation)
{
    return [[animation valueForKey:WKExplicitBeginTimeFlag] boolValue];
}

void setHasExplicitBeginTime(CAAnimation *animation, bool value)
{
    [animation setValue:[NSNumber numberWithBool:value] forKey:WKExplicitBeginTimeFlag];
}
    
NSString* toCAFillModeType(PlatformCAAnimation::FillModeType type)
{
    switch (type) {
    case PlatformCAAnimation::FillModeType::NoFillMode:
    case PlatformCAAnimation::FillModeType::Forwards: return kCAFillModeForwards;
    case PlatformCAAnimation::FillModeType::Backwards: return kCAFillModeBackwards;
    case PlatformCAAnimation::FillModeType::Both: return kCAFillModeBoth;
    }
    return @"";
}

static PlatformCAAnimation::FillModeType fromCAFillModeType(NSString* string)
{
    if ([string isEqualToString:kCAFillModeBackwards])
        return PlatformCAAnimation::FillModeType::Backwards;

    if ([string isEqualToString:kCAFillModeBoth])
        return PlatformCAAnimation::FillModeType::Both;

    return PlatformCAAnimation::FillModeType::Forwards;
}

NSString* toCAValueFunctionType(PlatformCAAnimation::ValueFunctionType type)
{
    switch (type) {
    case PlatformCAAnimation::ValueFunctionType::NoValueFunction: return @"";
    case PlatformCAAnimation::ValueFunctionType::RotateX: return kCAValueFunctionRotateX;
    case PlatformCAAnimation::ValueFunctionType::RotateY: return kCAValueFunctionRotateY;
    case PlatformCAAnimation::ValueFunctionType::RotateZ: return kCAValueFunctionRotateZ;
    case PlatformCAAnimation::ValueFunctionType::ScaleX: return kCAValueFunctionScaleX;
    case PlatformCAAnimation::ValueFunctionType::ScaleY: return kCAValueFunctionScaleY;
    case PlatformCAAnimation::ValueFunctionType::ScaleZ: return kCAValueFunctionScaleZ;
    case PlatformCAAnimation::ValueFunctionType::Scale: return kCAValueFunctionScale;
    case PlatformCAAnimation::ValueFunctionType::TranslateX: return kCAValueFunctionTranslateX;
    case PlatformCAAnimation::ValueFunctionType::TranslateY: return kCAValueFunctionTranslateY;
    case PlatformCAAnimation::ValueFunctionType::TranslateZ: return kCAValueFunctionTranslateZ;
    case PlatformCAAnimation::ValueFunctionType::Translate: return kCAValueFunctionTranslate;
    }
    return @"";
}

static PlatformCAAnimation::ValueFunctionType fromCAValueFunctionType(NSString* string)
{
    if ([string isEqualToString:kCAValueFunctionRotateX])
        return PlatformCAAnimation::ValueFunctionType::RotateX;

    if ([string isEqualToString:kCAValueFunctionRotateY])
        return PlatformCAAnimation::ValueFunctionType::RotateY;

    if ([string isEqualToString:kCAValueFunctionRotateZ])
        return PlatformCAAnimation::ValueFunctionType::RotateZ;

    if ([string isEqualToString:kCAValueFunctionScaleX])
        return PlatformCAAnimation::ValueFunctionType::ScaleX;

    if ([string isEqualToString:kCAValueFunctionScaleY])
        return PlatformCAAnimation::ValueFunctionType::ScaleY;

    if ([string isEqualToString:kCAValueFunctionScaleZ])
        return PlatformCAAnimation::ValueFunctionType::ScaleZ;

    if ([string isEqualToString:kCAValueFunctionScale])
        return PlatformCAAnimation::ValueFunctionType::Scale;

    if ([string isEqualToString:kCAValueFunctionTranslateX])
        return PlatformCAAnimation::ValueFunctionType::TranslateX;

    if ([string isEqualToString:kCAValueFunctionTranslateY])
        return PlatformCAAnimation::ValueFunctionType::TranslateY;

    if ([string isEqualToString:kCAValueFunctionTranslateZ])
        return PlatformCAAnimation::ValueFunctionType::TranslateZ;

    if ([string isEqualToString:kCAValueFunctionTranslate])
        return PlatformCAAnimation::ValueFunctionType::Translate;

    return PlatformCAAnimation::ValueFunctionType::NoValueFunction;
}

CAMediaTimingFunction* toCAMediaTimingFunction(const TimingFunction& timingFunction, bool reverse)
{
    if (auto* cubic = dynamicDowncast<CubicBezierTimingFunction>(timingFunction)) {
        RefPtr<CubicBezierTimingFunction> reversed;
        std::reference_wrapper<const CubicBezierTimingFunction> function = *cubic;

        if (reverse) {
            reversed = function.get().createReversed();
            function = *reversed;
        }

        float x1 = static_cast<float>(function.get().x1());
        float y1 = static_cast<float>(function.get().y1());
        float x2 = static_cast<float>(function.get().x2());
        float y2 = static_cast<float>(function.get().y2());
        return [CAMediaTimingFunction functionWithControlPoints: x1 : y1 : x2 : y2];
    }
    
    ASSERT(timingFunction.type() == TimingFunction::Type::LinearFunction);
    ASSERT(LinearTimingFunction::identity() == timingFunction);
    return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
}

Ref<PlatformCAAnimation> PlatformCAAnimationCocoa::create(AnimationType type, const String& keyPath)
{
    return adoptRef(*new PlatformCAAnimationCocoa(type, keyPath));
}

Ref<PlatformCAAnimation> PlatformCAAnimationCocoa::create(PlatformAnimationRef animation)
{
    return adoptRef(*new PlatformCAAnimationCocoa(animation));
}

PlatformCAAnimationCocoa::PlatformCAAnimationCocoa(AnimationType type, const String& keyPath)
    : PlatformCAAnimation(type)
{
    switch (type) {
    case AnimationType::Basic:
        m_animation = [CABasicAnimation animationWithKeyPath:keyPath.createNSString().get()];
        break;
    case AnimationType::Group:
        m_animation = [CAAnimationGroup animation];
        break;
    case AnimationType::Keyframe:
        m_animation = [CAKeyframeAnimation animationWithKeyPath:keyPath.createNSString().get()];
        break;
    case AnimationType::Spring:
        m_animation = [CASpringAnimation animationWithKeyPath:keyPath.createNSString().get()];
        break;
    }
}

PlatformCAAnimationCocoa::PlatformCAAnimationCocoa(PlatformAnimationRef animation)
{
    auto caAnimation = static_cast<CAAnimation *>(animation);
    if ([caAnimation isKindOfClass:[CABasicAnimation class]]) {
        if ([caAnimation isKindOfClass:[CASpringAnimation class]])
            setType(AnimationType::Spring);
        else
            setType(AnimationType::Basic);
    } else if ([caAnimation isKindOfClass:[CAKeyframeAnimation class]])
        setType(AnimationType::Keyframe);
    else if ([caAnimation isKindOfClass:[CAAnimationGroup class]])
        setType(AnimationType::Group);
    else {
        ASSERT_NOT_REACHED();
        return;
    }
    
    m_animation = caAnimation;
}

PlatformCAAnimationCocoa::~PlatformCAAnimationCocoa()
{
}

Ref<PlatformCAAnimation> PlatformCAAnimationCocoa::copy() const
{
    auto animation = create(animationType(), keyPath());
    
    animation->setBeginTime(beginTime());
    animation->setDuration(duration());
    animation->setSpeed(speed());
    animation->setTimeOffset(timeOffset());
    animation->setRepeatCount(repeatCount());
    animation->setAutoreverses(autoreverses());
    animation->setFillMode(fillMode());
    animation->setRemovedOnCompletion(isRemovedOnCompletion());
    animation->setAdditive(isAdditive());
    animation->copyTimingFunctionFrom(*this);
    animation->setValueFunction(valueFunction());

    setHasExplicitBeginTime(downcast<PlatformCAAnimationCocoa>(animation.get()).platformAnimation(), hasExplicitBeginTime(platformAnimation()));
    
    // Copy the specific Basic or Keyframe values.
    if (animationType() == AnimationType::Keyframe) {
        animation->copyValuesFrom(*this);
        animation->copyKeyTimesFrom(*this);
        animation->copyTimingFunctionsFrom(*this);
    } else {
        animation->copyFromValueFrom(*this);
        animation->copyToValueFrom(*this);
    }
    
    return animation;
}

PlatformAnimationRef PlatformCAAnimationCocoa::platformAnimation() const
{
    return m_animation.get();
}

String PlatformCAAnimationCocoa::keyPath() const
{
    if (animationType() == AnimationType::Group)
        return emptyString();

    ASSERT([static_cast<CAAnimation *>(m_animation.get()) isKindOfClass:[CAPropertyAnimation class]]);
    return [static_cast<CAPropertyAnimation *>(m_animation.get()) keyPath];
}

CFTimeInterval PlatformCAAnimationCocoa::beginTime() const
{
    return [m_animation beginTime];
}

void PlatformCAAnimationCocoa::setBeginTime(CFTimeInterval value)
{
    [m_animation setBeginTime:value];
    
    // Also set a flag to tell us if we've passed in a 0 value. 
    // The flag is needed because later beginTime will get changed
    // to the time at which it fired and we need to know whether
    // or not it was 0 to begin with.
    if (value)
        setHasExplicitBeginTime(m_animation.get(), true);
}

CFTimeInterval PlatformCAAnimationCocoa::duration() const
{
    return [m_animation duration];
}

void PlatformCAAnimationCocoa::setDuration(CFTimeInterval value)
{
    [m_animation setDuration:value];
}

float PlatformCAAnimationCocoa::speed() const
{
    return [m_animation speed];
}

void PlatformCAAnimationCocoa::setSpeed(float value)
{
    [m_animation setSpeed:value];
}

CFTimeInterval PlatformCAAnimationCocoa::timeOffset() const
{
    return [m_animation timeOffset];
}

void PlatformCAAnimationCocoa::setTimeOffset(CFTimeInterval value)
{
    [m_animation setTimeOffset:value];
}

float PlatformCAAnimationCocoa::repeatCount() const
{
    return [m_animation repeatCount];
}

void PlatformCAAnimationCocoa::setRepeatCount(float value)
{
    [m_animation setRepeatCount:value];
}

bool PlatformCAAnimationCocoa::autoreverses() const
{
    return [m_animation autoreverses];
}

void PlatformCAAnimationCocoa::setAutoreverses(bool value)
{
    [m_animation setAutoreverses:value];
}

PlatformCAAnimation::FillModeType PlatformCAAnimationCocoa::fillMode() const
{
    return fromCAFillModeType([m_animation fillMode]);
}

void PlatformCAAnimationCocoa::setFillMode(FillModeType value)
{
    [m_animation setFillMode:toCAFillModeType(value)];
}

void PlatformCAAnimationCocoa::setTimingFunction(const TimingFunction* timingFunction, bool reverse)
{
    ASSERT(timingFunction);
    switch (animationType()) {
    case AnimationType::Basic:
    case AnimationType::Keyframe:
        [m_animation setTimingFunction:toCAMediaTimingFunction(*timingFunction, reverse)];
        break;
    case AnimationType::Spring:
        if (timingFunction->isSpringTimingFunction()) {
            // FIXME: Handle reverse.
            auto& function = *static_cast<const SpringTimingFunction*>(timingFunction);
            CASpringAnimation *springAnimation = (CASpringAnimation *)m_animation.get();
            springAnimation.mass = function.mass();
            springAnimation.stiffness = function.stiffness();
            springAnimation.damping = function.damping();
            springAnimation.initialVelocity = function.initialVelocity();
        }
        break;
    case AnimationType::Group:
        break;
    }
}

void PlatformCAAnimationCocoa::copyTimingFunctionFrom(const PlatformCAAnimation& value)
{
    [m_animation setTimingFunction:[downcast<PlatformCAAnimationCocoa>(value).m_animation.get() timingFunction]];
}

bool PlatformCAAnimationCocoa::isRemovedOnCompletion() const
{
    return [m_animation isRemovedOnCompletion];
}

void PlatformCAAnimationCocoa::setRemovedOnCompletion(bool value)
{
    [m_animation setRemovedOnCompletion:value];
}

bool PlatformCAAnimationCocoa::isAdditive() const
{
    if (animationType() == AnimationType::Group)
        return false;

    ASSERT([static_cast<CAAnimation *>(m_animation.get()) isKindOfClass:[CAPropertyAnimation class]]);
    return [static_cast<CAPropertyAnimation *>(m_animation.get()) isAdditive];
}

void PlatformCAAnimationCocoa::setAdditive(bool value)
{
    if (animationType() == AnimationType::Group)
        return;

    ASSERT([static_cast<CAAnimation *>(m_animation.get()) isKindOfClass:[CAPropertyAnimation class]]);
    return [static_cast<CAPropertyAnimation *>(m_animation.get()) setAdditive:value];
}

PlatformCAAnimation::ValueFunctionType PlatformCAAnimationCocoa::valueFunction() const
{
    if (animationType() == AnimationType::Group)
        return ValueFunctionType::NoValueFunction;

    ASSERT([static_cast<CAAnimation *>(m_animation.get()) isKindOfClass:[CAPropertyAnimation class]]);
    return fromCAValueFunctionType([[static_cast<CAPropertyAnimation *>(m_animation.get()) valueFunction] name]);
}

void PlatformCAAnimationCocoa::setValueFunction(ValueFunctionType value)
{
    if (animationType() == AnimationType::Group)
        return;

    ASSERT([static_cast<CAAnimation *>(m_animation.get()) isKindOfClass:[CAPropertyAnimation class]]);
    return [static_cast<CAPropertyAnimation *>(m_animation.get()) setValueFunction:[CAValueFunction functionWithName:toCAValueFunctionType(value)]];
}

void PlatformCAAnimationCocoa::setFromValue(float value)
{
    if (!isBasicAnimation())
        return;
    [static_cast<CABasicAnimation *>(m_animation.get()) setFromValue:@(value)];
}

void PlatformCAAnimationCocoa::setFromValue(const TransformationMatrix& value)
{
    if (!isBasicAnimation())
        return;
    [static_cast<CABasicAnimation *>(m_animation.get()) setFromValue:[NSValue valueWithCATransform3D:value]];
}

void PlatformCAAnimationCocoa::setFromValue(const FloatPoint3D& value)
{
    if (!isBasicAnimation())
        return;
    [static_cast<CABasicAnimation *>(m_animation.get()) setFromValue:@[ @(value.x()), @(value.y()), @(value.z()) ]];
}

void PlatformCAAnimationCocoa::setFromValue(const Color& value)
{
    if (!isBasicAnimation())
        return;
    auto [r, g, b, a] = value.toColorTypeLossy<SRGBA<uint8_t>>().resolved();
    [static_cast<CABasicAnimation *>(m_animation.get()) setFromValue:@[@(r), @(g), @(b), @(a)]];
}

void PlatformCAAnimationCocoa::setFromValue(const FilterOperation& operation)
{
    auto value = PlatformCAFilters::filterValueForOperation(operation);
    [static_cast<CABasicAnimation *>(m_animation.get()) setFromValue:value.get()];
}

void PlatformCAAnimationCocoa::copyFromValueFrom(const PlatformCAAnimation& value)
{
    if (!isBasicAnimation() || !value.isBasicAnimation())
        return;
    auto otherAnimation = static_cast<CABasicAnimation *>(downcast<PlatformCAAnimationCocoa>(value).m_animation.get());
    [static_cast<CABasicAnimation *>(m_animation.get()) setFromValue:[otherAnimation fromValue]];
}

void PlatformCAAnimationCocoa::setToValue(float value)
{
    if (!isBasicAnimation())
        return;
    [static_cast<CABasicAnimation *>(m_animation.get()) setToValue:@(value)];
}

void PlatformCAAnimationCocoa::setToValue(const TransformationMatrix& value)
{
    if (!isBasicAnimation())
        return;
    [static_cast<CABasicAnimation *>(m_animation.get()) setToValue:[NSValue valueWithCATransform3D:value]];
}

void PlatformCAAnimationCocoa::setToValue(const FloatPoint3D& value)
{
    if (!isBasicAnimation())
        return;
    [static_cast<CABasicAnimation *>(m_animation.get()) setToValue:@[ @(value.x()), @(value.y()), @(value.z()) ]];
}

void PlatformCAAnimationCocoa::setToValue(const Color& value)
{
    if (!isBasicAnimation())
        return;
    auto [r, g, b, a] = value.toColorTypeLossy<SRGBA<uint8_t>>().resolved();
    [static_cast<CABasicAnimation *>(m_animation.get()) setToValue:@[@(r), @(g), @(b), @(a)]];
}

void PlatformCAAnimationCocoa::setToValue(const FilterOperation& operation)
{
    auto value = PlatformCAFilters::filterValueForOperation(operation);
    [static_cast<CABasicAnimation *>(m_animation.get()) setToValue:value.get()];
}

void PlatformCAAnimationCocoa::copyToValueFrom(const PlatformCAAnimation& value)
{
    if (!isBasicAnimation() || !value.isBasicAnimation())
        return;

    auto otherAnimation = static_cast<CABasicAnimation *>(downcast<PlatformCAAnimationCocoa>(value).m_animation.get());
    [static_cast<CABasicAnimation *>(m_animation.get()) setToValue:[otherAnimation toValue]];
}


// Keyframe-animation properties.
void PlatformCAAnimationCocoa::setValues(const Vector<float>& value)
{
    if (animationType() != AnimationType::Keyframe)
        return;

    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setValues:createNSArray(value, [] (float number) {
        return @(number);
    }).get()];
}

void PlatformCAAnimationCocoa::setValues(const Vector<TransformationMatrix>& value)
{
    if (animationType() != AnimationType::Keyframe)
        return;

    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setValues:createNSArray(value, [] (auto& matrix) {
        return [NSValue valueWithCATransform3D:matrix];
    }).get()];
}

void PlatformCAAnimationCocoa::setValues(const Vector<FloatPoint3D>& value)
{
    if (animationType() != AnimationType::Keyframe)
        return;

    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setValues:createNSArray(value, [] (auto& point) {
        return @[@(point.x()), @(point.y()), @(point.z())];
    }).get()];
}

void PlatformCAAnimationCocoa::setValues(const Vector<Color>& value)
{
    if (animationType() != AnimationType::Keyframe)
        return;

    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setValues:createNSArray(value, [] (auto& color) {
        auto [r, g, b, a] = color.template toColorTypeLossy<SRGBA<uint8_t>>().resolved();
        return @[@(r), @(g), @(b), @(a)];
    }).get()];
}

void PlatformCAAnimationCocoa::setValues(const Vector<Ref<FilterOperation>>& values)
{
    if (animationType() != AnimationType::Keyframe)
        return;

    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setValues:createNSArray(values, [&](auto& value) {
        return PlatformCAFilters::filterValueForOperation(value);
    }).get()];
}

void PlatformCAAnimationCocoa::copyValuesFrom(const PlatformCAAnimation& value)
{
    if (animationType() != AnimationType::Keyframe || value.animationType() != AnimationType::Keyframe)
        return;

    auto otherAnimation = static_cast<CAKeyframeAnimation *>(downcast<PlatformCAAnimationCocoa>(value).m_animation.get());
    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setValues:[otherAnimation values]];
}

void PlatformCAAnimationCocoa::setKeyTimes(const Vector<float>& value)
{
    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setKeyTimes:createNSArray(value, [] (float time) {
        return @(time);
    }).get()];
}

void PlatformCAAnimationCocoa::copyKeyTimesFrom(const PlatformCAAnimation& value)
{
    auto other = static_cast<CAKeyframeAnimation *>(downcast<PlatformCAAnimationCocoa>(value).m_animation.get());
    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setKeyTimes:[other keyTimes]];
}

void PlatformCAAnimationCocoa::setTimingFunctions(const Vector<Ref<const TimingFunction>>& timingFunctions, bool reverse)
{
    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setTimingFunctions:createNSArray(timingFunctions, [&] (auto& function) {
        return toCAMediaTimingFunction(function.get(), reverse);
    }).get()];
}

void PlatformCAAnimationCocoa::copyTimingFunctionsFrom(const PlatformCAAnimation& value)
{
    auto other = static_cast<CAKeyframeAnimation *>(downcast<PlatformCAAnimationCocoa>(value).m_animation.get());
    [static_cast<CAKeyframeAnimation *>(m_animation.get()) setTimingFunctions:[other timingFunctions]];
}

void PlatformCAAnimationCocoa::setAnimations(const Vector<RefPtr<PlatformCAAnimation>>& value)
{
    ASSERT(animationType() == AnimationType::Group);
    ASSERT([static_cast<CAAnimation *>(m_animation.get()) isKindOfClass:[CAAnimationGroup class]]);

    [static_cast<CAAnimationGroup *>(m_animation.get()) setAnimations:createNSArray(value, [&] (auto& animation) -> CAAnimation * {
        if (auto* platformAnimation = dynamicDowncast<PlatformCAAnimationCocoa>(animation.get()))
            return platformAnimation->m_animation.get();
        return nil;
    }).get()];
}

void PlatformCAAnimationCocoa::copyAnimationsFrom(const PlatformCAAnimation& value)
{
    ASSERT(animationType() == AnimationType::Group);
    ASSERT(value.animationType() == AnimationType::Group);
    ASSERT([static_cast<CAAnimation *>(m_animation.get()) isKindOfClass:[CAAnimationGroup class]]);
    ASSERT([static_cast<CAAnimation *>(downcast<PlatformCAAnimationCocoa>(value).m_animation.get()) isKindOfClass:[CAAnimationGroup class]]);

    auto other = static_cast<CAAnimationGroup *>(downcast<PlatformCAAnimationCocoa>(value).m_animation.get());
    [static_cast<CAAnimationGroup *>(m_animation.get()) setAnimations:[other animations]];
}

} // namespace WebCore
