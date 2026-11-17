import AppKit

nonisolated enum Mood: Sendable {
  case idle, hungry, busy, happy, sad
}

nonisolated enum Mascot {
  static let violet = CGColor(srgbRed: 0.49, green: 0.36, blue: 0.96, alpha: 1)

  static func draw(_ mood: Mood, in rect: CGRect, context: CGContext, body: CGColor, features: CGColor?) {
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    func oval(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
      let origin = point(x - width / 2, y - height / 2)
      context.fillEllipse(in: CGRect(x: origin.x, y: origin.y, width: width * rect.width, height: height * rect.height))
    }
    func curve(from start: CGPoint, to end: CGPoint, bend: CGPoint) {
      context.move(to: start)
      context.addQuadCurve(to: end, control: bend)
      context.strokePath()
    }

    context.move(to: point(0.50, 0.96))
    context.addCurve(to: point(0.96, 0.50), control1: point(0.80, 0.98), control2: point(0.98, 0.78))
    context.addCurve(to: point(0.52, 0.05), control1: point(0.94, 0.20), control2: point(0.78, 0.04))
    context.addCurve(to: point(0.04, 0.46), control1: point(0.22, 0.06), control2: point(0.03, 0.20))
    context.addCurve(to: point(0.50, 0.96), control1: point(0.05, 0.76), control2: point(0.22, 0.94))
    context.closePath()
    context.setFillColor(body)
    context.fillPath()

    context.saveGState()
    defer { context.restoreGState() }
    if let features {
      context.setFillColor(features)
      context.setStrokeColor(features)
    } else {
      context.setBlendMode(.clear)
    }
    context.setLineWidth(0.06 * rect.width)
    context.setLineCap(.round)

    for x in [0.34, 0.66] as [CGFloat] {
      switch mood {
      case .idle, .sad: oval(x, 0.58, 0.11, 0.15)
      case .hungry: oval(x, 0.60, 0.14, 0.19)
      case .busy: curve(from: point(x - 0.07, 0.58), to: point(x + 0.07, 0.58), bend: point(x, 0.58))
      case .happy: curve(from: point(x - 0.07, 0.56), to: point(x + 0.07, 0.56), bend: point(x, 0.67))
      }
    }
    switch mood {
    case .idle: curve(from: point(0.42, 0.37), to: point(0.58, 0.37), bend: point(0.50, 0.29))
    case .happy: curve(from: point(0.36, 0.39), to: point(0.64, 0.39), bend: point(0.50, 0.22))
    case .sad: curve(from: point(0.41, 0.30), to: point(0.59, 0.30), bend: point(0.50, 0.38))
    case .hungry: oval(0.50, 0.31, 0.22, 0.22)
    case .busy: oval(0.50, 0.33, 0.09, 0.09)
    }
  }

  static func image(_ mood: Mood, side: CGFloat, body: CGColor = violet, features: CGColor? = nil) -> NSImage {
    NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      draw(mood, in: rect, context: context, body: body, features: features)
      return true
    }
  }

  static func menuBarImage(_ mood: Mood) -> NSImage {
    let image = image(mood, side: 18, body: CGColor(gray: 0, alpha: 1))
    image.isTemplate = true
    image.accessibilityDescription = "Morph"
    return image
  }
}
