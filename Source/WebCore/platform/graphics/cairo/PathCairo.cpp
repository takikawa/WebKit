/*
    Copyright (C) 2007 Krzysztof Kowalczyk <kkowalczyk@gmail.com>
    Copyright (C) 2004, 2005, 2006 Nikolas Zimmermann <wildfox@kde.org>
    Copyright (C) 2004, 2005, 2006 Rob Buis <buis@kde.org>
    Copyright (C) 2005-2023 Apple Inc. All Rights reserved.
    Copyright (C) 2007 Alp Toker <alp@atoker.com>
    Copyright (C) 2008 Dirk Schulze <krit@webkit.org>
    Copyright (C) 2011, 2020 Igalia S.L.

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    aint with this library; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

#include "config.h"
#include "PathCairo.h"

#if USE(CAIRO)

#include "CairoUniquePtr.h"
#include "CairoUtilities.h"
#include "FloatRect.h"
#include "GraphicsContextCairo.h"
#include "PathStream.h"
#include <mutex>
#include <numbers>
#include <wtf/NeverDestroyed.h>

namespace WebCore {

Ref<PathCairo> PathCairo::create(std::span<const PathSegment> segments)
{
    Ref pathCairo = adoptRef(*new PathCairo);
    for (auto& segment : segments)
        pathCairo->addSegment(segment);
    return pathCairo;
}

Ref<PathCairo> PathCairo::create(RefPtr<cairo_t>&& platformPath, RefPtr<PathStream>&& elementsStream)
{
    return adoptRef(*new PathCairo(WTFMove(platformPath), WTFMove(elementsStream)));
}

PlatformPathPtr PathCairo::emptyPlatformPath()
{
    static LazyNeverDestroyed<cairo_t*> emptyPath;
    static std::once_flag onceFlag;
    std::call_once(onceFlag, [] {
        emptyPath.construct(cairo_create(cairo_image_surface_create(CAIRO_FORMAT_A8, 1, 1)));
    });
    return emptyPath.get();
}

PathCairo::PathCairo()
    : m_platformPath(adoptRef(cairo_create(adoptRef(cairo_image_surface_create(CAIRO_FORMAT_A8, 1, 1)).get())))
    , m_elementsStream(PathStream::create())
{
}

PathCairo::PathCairo(RefPtr<cairo_t>&& platformPath, RefPtr<PathStream>&& elementsStream)
    : m_platformPath(WTFMove(platformPath))
    , m_elementsStream(WTFMove(elementsStream))
{
    ASSERT(m_platformPath);
}

bool PathCairo::definitelyEqual(const PathImpl& otherImpl) const
{
    RefPtr otherAsPathCairo = dynamicDowncast<PathCairo>(otherImpl);
    if (!otherAsPathCairo) {
        // We could convert other to a platform path to compare, but that would be expensive.
        return false;
    }

    if (otherAsPathCairo.get() == this)
        return true;

    if (m_elementsStream && otherAsPathCairo->m_elementsStream)
        return m_elementsStream->definitelyEqual(*otherAsPathCairo->m_elementsStream);

    // There doesn't seem to be an API to compare cairo_path_t.
    return false;
}

Ref<PathImpl> PathCairo::copy() const
{
    auto platformPathCopy = adoptRef(cairo_create(adoptRef(cairo_image_surface_create(CAIRO_FORMAT_A8, 1, 1)).get()));

    cairo_matrix_t ctm;
    cairo_get_matrix(platformPath(), &ctm);
    cairo_set_matrix(platformPathCopy.get(), &ctm);

    CairoUniquePtr<cairo_path_t> pathCopy(cairo_copy_path(platformPath()));
    cairo_append_path(platformPathCopy.get(), pathCopy.get());

    auto elementsStream = m_elementsStream ? RefPtr<PathImpl> { m_elementsStream->copy() } : nullptr;

    return PathCairo::create(WTFMove(platformPathCopy), downcast<PathStream>(WTFMove(elementsStream)));
}

PlatformPathPtr PathCairo::platformPath() const
{
    return m_platformPath.get();
}

void PathCairo::add(PathMoveTo moveTo)
{
    cairo_move_to(platformPath(), moveTo.point.x(), moveTo.point.y());
    if (m_elementsStream)
        m_elementsStream->add(moveTo);
}

void PathCairo::add(PathLineTo lineTo)
{
    cairo_line_to(platformPath(), lineTo.point.x(), lineTo.point.y());
    if (m_elementsStream)
        m_elementsStream->add(lineTo);
}

void PathCairo::add(PathQuadCurveTo quadTo)
{
    double x, y;
    double x1 = quadTo.controlPoint.x();
    double y1 = quadTo.controlPoint.y();
    double x2 = quadTo.endPoint.x();
    double y2 = quadTo.endPoint.y();
    cairo_t* cr = platformPath();
    cairo_get_current_point(cr, &x, &y);
    cairo_curve_to(cr,
        x  + 2.0 / 3.0 * (x1 - x),  y  + 2.0 / 3.0 * (y1 - y),
        x2 + 2.0 / 3.0 * (x1 - x2), y2 + 2.0 / 3.0 * (y1 - y2),
        x2, y2);
    if (m_elementsStream)
        m_elementsStream->add(quadTo);
}

void PathCairo::add(PathBezierCurveTo bezierTo)
{
    cairo_curve_to(platformPath(), bezierTo.controlPoint1.x(), bezierTo.controlPoint1.y(), bezierTo.controlPoint2.x(), bezierTo.controlPoint2.y(), bezierTo.endPoint.x(), bezierTo.endPoint.y());
    if (m_elementsStream)
        m_elementsStream->add(bezierTo);
}

static inline float areaOfTriangleFormedByPoints(const FloatPoint& p1, const FloatPoint& p2, const FloatPoint& p3)
{
    return p1.x() * (p2.y() - p3.y()) + p2.x() * (p3.y() - p1.y()) + p3.x() * (p1.y() - p2.y());
}

void PathCairo::add(PathArcTo arcTo)
{
    double x0, y0;
    cairo_get_current_point(platformPath(), &x0, &y0);
    FloatPoint p0(x0, y0);

    const FloatPoint p1 = arcTo.controlPoint1;
    const FloatPoint p2 = arcTo.controlPoint2;
    const float radius = arcTo.radius;
    // Draw only a straight line to p1 if any of the points are equal or the radius is zero
    // or the points are collinear (triangle that the points form has area of zero value).
    if ((p1.x() == p0.x() && p1.y() == p0.y()) || (p1.x() == p2.x() && p1.y() == p2.y()) || !radius
        || !areaOfTriangleFormedByPoints(p0, p1, p2)) {
        cairo_line_to(platformPath(), p1.x(), p1.y());
        if (m_elementsStream)
            m_elementsStream->add(PathLineTo { p1 });
        return;
    }

    FloatPoint p1p0((p0.x() - p1.x()),(p0.y() - p1.y()));
    FloatPoint p1p2((p2.x() - p1.x()),(p2.y() - p1.y()));
    float p1p0_length = std::hypot(p1p0.x(), p1p0.y());
    float p1p2_length = std::hypot(p1p2.x(), p1p2.y());
    double cos_phi = (p1p0.x() * p1p2.x() + p1p0.y() * p1p2.y()) / (p1p0_length * p1p2_length);
    // all points on a line logic
    if (cos_phi == -1) {
        cairo_line_to(platformPath(), p1.x(), p1.y());
        if (m_elementsStream)
            m_elementsStream->add(PathLineTo { p1 });
        return;
    }
    if (cos_phi == 1) {
        // add infinite far away point
        unsigned int max_length = 65535;
        double factor_max = max_length / p1p0_length;
        FloatPoint ep((p0.x() + factor_max * p1p0.x()), (p0.y() + factor_max * p1p0.y()));
        cairo_line_to(platformPath(), ep.x(), ep.y());
        if (m_elementsStream)
            m_elementsStream->add(PathLineTo { ep });
        return;
    }

    float tangent = radius / tan(acos(cos_phi) / 2);
    float factor_p1p0 = tangent / p1p0_length;
    FloatPoint t_p1p0((p1.x() + factor_p1p0 * p1p0.x()), (p1.y() + factor_p1p0 * p1p0.y()));

    FloatPoint orth_p1p0(p1p0.y(), -p1p0.x());
    float orth_p1p0_length = std::hypot(orth_p1p0.x(), orth_p1p0.y());
    float factor_ra = radius / orth_p1p0_length;

    // angle between orth_p1p0 and p1p2 to get the right vector orthographic to p1p0
    double cos_alpha = (orth_p1p0.x() * p1p2.x() + orth_p1p0.y() * p1p2.y()) / (orth_p1p0_length * p1p2_length);
    if (cos_alpha < 0.f)
        orth_p1p0 = FloatPoint(-orth_p1p0.x(), -orth_p1p0.y());

    FloatPoint p((t_p1p0.x() + factor_ra * orth_p1p0.x()), (t_p1p0.y() + factor_ra * orth_p1p0.y()));

    // calculate angles for addArc
    orth_p1p0 = FloatPoint(-orth_p1p0.x(), -orth_p1p0.y());
    float sa = acos(orth_p1p0.x() / orth_p1p0_length);
    if (orth_p1p0.y() < 0.f)
        sa = 2 * std::numbers::pi - sa;

    // clockwise logic
    auto direction = RotationDirection::Clockwise;

    float factor_p1p2 = tangent / p1p2_length;
    FloatPoint t_p1p2((p1.x() + factor_p1p2 * p1p2.x()), (p1.y() + factor_p1p2 * p1p2.y()));
    FloatPoint orth_p1p2((t_p1p2.x() - p.x()), (t_p1p2.y() - p.y()));
    float orth_p1p2_length = sqrtf(orth_p1p2.x() * orth_p1p2.x() + orth_p1p2.y() * orth_p1p2.y());
    float ea = acos(orth_p1p2.x() / orth_p1p2_length);
    if (orth_p1p2.y() < 0)
        ea = 2 * std::numbers::pi - ea;
    if ((sa > ea) && ((sa - ea) < std::numbers::pi))
        direction = RotationDirection::Counterclockwise;
    if ((sa < ea) && ((ea - sa) > std::numbers::pi))
        direction = RotationDirection::Counterclockwise;

    cairo_line_to(platformPath(), t_p1p0.x(), t_p1p0.y());

    add(PathArc { p, radius, sa, ea, direction });

    m_elementsStream = nullptr;
}

void PathCairo::add(PathArc arc)
{
    cairo_t* cr = platformPath();
    const FloatPoint p = arc.center;
    const float r = arc.radius;
    const float startAngle = arc.startAngle;
    const float endAngle = arc.endAngle;
    const RotationDirection direction = arc.direction;
    float sweep = endAngle - startAngle;
    constexpr float twoPI = 2 * std::numbers::pi_v<float>;
    if ((sweep <= -twoPI || sweep >= twoPI)
        && ((direction == RotationDirection::Counterclockwise && (endAngle < startAngle)) || (direction == RotationDirection::Clockwise && (startAngle < endAngle)))) {
        if (direction == RotationDirection::Clockwise)
            cairo_arc(cr, p.x(), p.y(), r, startAngle, startAngle + twoPI);
        else
            cairo_arc_negative(cr, p.x(), p.y(), r, startAngle, startAngle - twoPI);
        cairo_new_sub_path(cr);
        cairo_arc(cr, p.x(), p.y(), r, endAngle, endAngle);
    } else {
        if (direction == RotationDirection::Clockwise)
            cairo_arc(cr, p.x(), p.y(), r, startAngle, endAngle);
        else
            cairo_arc_negative(cr, p.x(), p.y(), r, startAngle, endAngle);
    }

    m_elementsStream = nullptr;
}

void PathCairo::add(PathClosedArc closedArc)
{
    add(closedArc.arc);
    add(PathCloseSubpath());
}

void PathCairo::add(PathEllipse ellipse)
{
    cairo_t* cr = platformPath();
    cairo_save(cr);
    cairo_translate(cr, ellipse.center.x(), ellipse.center.y());
    cairo_rotate(cr, ellipse.rotation);
    cairo_scale(cr, ellipse.radiusX, ellipse.radiusY);

    if (ellipse.direction == RotationDirection::Clockwise)
        cairo_arc(cr, 0, 0, 1, ellipse.startAngle, ellipse.endAngle);
    else
        cairo_arc_negative(cr, 0, 0, 1, ellipse.startAngle, ellipse.endAngle);

    cairo_restore(cr);

    m_elementsStream = nullptr;
}

void PathCairo::add(PathEllipseInRect ellipseInRect)
{
    cairo_t* cr = platformPath();
    cairo_save(cr);
    float yRadius = .5 * ellipseInRect.rect.height();
    float xRadius = .5 * ellipseInRect.rect.width();
    cairo_translate(cr, ellipseInRect.rect.x() + xRadius, ellipseInRect.rect.y() + yRadius);
    cairo_scale(cr, xRadius, yRadius);
    cairo_arc(cr, 0., 0., 1., 0., 2 * std::numbers::pi);
    cairo_restore(cr);

    m_elementsStream = nullptr;
}

void PathCairo::add(PathRect rect)
{
    cairo_rectangle(platformPath(), rect.rect.x(), rect.rect.y(), rect.rect.width(), rect.rect.height());
    if (m_elementsStream)
        m_elementsStream->addLinesForRect(rect.rect);
}

void PathCairo::add(PathRoundedRect roundedRect)
{
    for (auto& segment : PathImpl::beziersForRoundedRect(roundedRect.roundedRect))
        addSegment(segment);
}

void PathCairo::add(PathContinuousRoundedRect continuousRoundedRect)
{
    // Continuous rounded rects are unavailable. Paint a normal rounded rect instead.
    add(PathRoundedRect { FloatRoundedRect { continuousRoundedRect.rect, FloatRoundedRect::Radii { continuousRoundedRect.cornerWidth, continuousRoundedRect.cornerHeight } }, PathRoundedRect::Strategy::PreferNative });
}

void PathCairo::add(PathCloseSubpath)
{
    cairo_close_path(platformPath());
    if (m_elementsStream)
        m_elementsStream->add(PathCloseSubpath { });
}

void PathCairo::addPath(const PathCairo& path, const AffineTransform& transform)
{
    cairo_matrix_t matrix = toCairoMatrix(transform);
    if (cairo_matrix_invert(&matrix) != CAIRO_STATUS_SUCCESS)
        return;

    cairo_t* cr = path.platformPath();
    cairo_save(cr);
    cairo_transform(cr, &matrix);
    CairoUniquePtr<cairo_path_t> pathCopy(cairo_copy_path(cr));
    cairo_restore(cr);
    cairo_append_path(platformPath(), pathCopy.get());

    m_elementsStream = nullptr;
}

bool PathCairo::applyElements(const PathElementApplier& applier) const
{
    if (m_elementsStream && m_elementsStream->applyElements(applier))
        return true;

    CairoUniquePtr<cairo_path_t> pathCopy(cairo_copy_path(platformPath()));
    cairo_path_data_t* data;
    PathElement pathElement;

    for (int i = 0; i < pathCopy->num_data; i += pathCopy->data[i].header.length) {
        data = &pathCopy->data[i];
        switch (data->header.type) {
        case CAIRO_PATH_MOVE_TO:
            pathElement.type = PathElement::Type::MoveToPoint;
            pathElement.points[0] = FloatPoint(data[1].point.x, data[1].point.y);
            applier(pathElement);
            break;

        case CAIRO_PATH_LINE_TO:
            pathElement.type = PathElement::Type::AddLineToPoint;
            pathElement.points[0] = FloatPoint(data[1].point.x, data[1].point.y);
            applier(pathElement);
            break;

        case CAIRO_PATH_CURVE_TO:
            pathElement.type = PathElement::Type::AddCurveToPoint;
            pathElement.points[0] = FloatPoint(data[1].point.x, data[1].point.y);
            pathElement.points[1] = FloatPoint(data[2].point.x, data[2].point.y);
            pathElement.points[2] = FloatPoint(data[3].point.x, data[3].point.y);
            applier(pathElement);
            break;

        case CAIRO_PATH_CLOSE_PATH:
            pathElement.type = PathElement::Type::CloseSubpath;
            applier(pathElement);
            break;
        }
    }

    return true;
}

FloatPoint PathCairo::currentPoint() const
{
    // FIXME: Is this the correct way?
    double x;
    double y;
    cairo_get_current_point(platformPath(), &x, &y);
    return FloatPoint(x, y);
}

bool PathCairo::transform(const AffineTransform& transform)
{
    if (m_elementsStream && !m_elementsStream->transform(transform))
        m_elementsStream = nullptr;

    cairo_matrix_t matrix = toCairoMatrix(transform);
    cairo_matrix_invert(&matrix);
    cairo_transform(platformPath(), &matrix);

    return true;
}

bool PathCairo::contains(const FloatPoint &point, WindRule rule) const
{
    if (!std::isfinite(point.x()) || !std::isfinite(point.y()))
        return false;

    cairo_fill_rule_t cur = cairo_get_fill_rule(platformPath());
    cairo_set_fill_rule(platformPath(), rule == WindRule::EvenOdd ? CAIRO_FILL_RULE_EVEN_ODD : CAIRO_FILL_RULE_WINDING);
    bool contains = cairo_in_fill(platformPath(), point.x(), point.y());
    cairo_set_fill_rule(platformPath(), cur);
    return contains;
}

bool PathCairo::strokeContains(const FloatPoint& point, NOESCAPE const Function<void(GraphicsContext&)>& strokeStyleApplier) const
{
    ASSERT(strokeStyleApplier);

    {
        GraphicsContextCairo graphicsContext(platformPath());
        strokeStyleApplier(graphicsContext);
    }

    return cairo_in_stroke(platformPath(), point.x(), point.y());
}

FloatRect PathCairo::fastBoundingRect() const
{
    if (m_elementsStream)
        return m_elementsStream->fastBoundingRect();

    return boundingRect();
}

FloatRect PathCairo::boundingRect() const
{
    if (m_elementsStream)
        return m_elementsStream->boundingRect();

    double x0, x1, y0, y1;
    cairo_path_extents(platformPath(), &x0, &y0, &x1, &y1);
    return FloatRect(x0, y0, x1 - x0, y1 - y0);
}

FloatRect PathCairo::strokeBoundingRect(NOESCAPE const Function<void(GraphicsContext&)>& strokeStyleApplier) const
{
    cairo_t* cr = platformPath();

    if (strokeStyleApplier) {
        GraphicsContextCairo gc(cr);
        strokeStyleApplier(gc);
    }

    double x0, x1, y0, y1;
    cairo_stroke_extents(cr, &x0, &y0, &x1, &y1);
    return FloatRect(x0, y0, x1 - x0, y1 - y0);
}

} // namespace WebCore

#endif // USE(CAIRO)
