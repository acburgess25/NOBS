import SwiftUI

extension Color {
    static let nobsAmber = Color(red: 0.85, green: 0.46, blue: 0.04)
    static let nobsSage = Color(red: 0.39, green: 0.64, blue: 0.43)
    static let nobsBlue = Color(red: 0.34, green: 0.50, blue: 0.66)
    static let nobsDeepBlue = Color(red: 0.20, green: 0.47, blue: 0.96)
    static let nobsRose = Color(red: 0.78, green: 0.36, blue: 0.36)
    static let nobsGraphite = Color(nsColor: .secondaryLabelColor)
}

extension NOBSTint {
    var color: Color {
        switch self {
        case .amber: .nobsAmber
        case .sage: .nobsSage
        case .blue: .nobsBlue
        case .rose: .nobsRose
        case .graphite: .nobsGraphite
        }
    }
}

struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .glassSurface(radius: radius)
    }
}

struct NOBSLogoMark: View {
    var size: CGFloat = 44
    @State private var breathe = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(.background)
                .shadow(color: Color.nobsBlue.opacity(0.22), radius: size * 0.24, x: 0, y: size * 0.14)

            ShieldShape()
                .fill(Color(red: 0.07, green: 0.09, blue: 0.13))
                .frame(width: size * 0.62, height: size * 0.72)

            ShieldShape()
                .fill(
                    LinearGradient(
                        colors: [.nobsDeepBlue, .nobsSage, .nobsAmber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.48, height: size * 0.56)
                .scaleEffect(breathe ? 1.02 : 0.98)

            Text("N")
                .font(.system(size: size * 0.30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            TrustCurveShape()
                .stroke(.white.opacity(0.74), style: StrokeStyle(lineWidth: max(1.6, size * 0.035), lineCap: .round))
                .frame(width: size * 0.28, height: size * 0.12)
                .offset(y: size * 0.19)
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
        .accessibilityLabel("NOBS")
    }
}

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.53))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.76),
            control2: CGPoint(x: rect.midX + rect.width * 0.25, y: rect.maxY - rect.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.53),
            control1: CGPoint(x: rect.midX - rect.width * 0.25, y: rect.maxY - rect.height * 0.08),
            control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.76)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.18))
        path.closeSubpath()
        return path
    }
}

private struct TrustCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY),
            control2: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.maxY)
        )
        return path
    }
}

struct NOBSBrandLockup: View {
    var compact = false

    var body: some View {
        HStack(spacing: 11) {
            NOBSLogoMark(size: compact ? 34 : 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("NOBS")
                    .font(.system(size: compact ? 16 : 20, weight: .bold, design: .rounded))
                Text("Private family AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PermissionWave: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let time = context.date.timeIntervalSinceReferenceDate
                var path = Path()
                let midY = size.height / 2
                path.move(to: CGPoint(x: 0, y: midY))

                for x in stride(from: 0, through: size.width, by: 2) {
                    let y = midY + sin((x / 9) + time * 2.4 + phase) * 5
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                canvas.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [.nobsDeepBlue, .nobsSage]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
            }
        }
        .frame(width: 96, height: 26)
        .onAppear { phase = .pi }
    }
}

struct SignalNetworkView: View {
    @State private var active = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, index == 1 ? .nobsSage.opacity(0.8) : .nobsDeepBlue.opacity(0.75), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 176, height: 2)
                    .rotationEffect(.degrees(Double(index) * 54 - 28))
                    .offset(x: active ? CGFloat(index - 1) * 5 : CGFloat(1 - index) * 8)
            }

            NOBSLogoMark(size: 72)
                .zIndex(2)

            node(color: .nobsDeepBlue)
                .offset(x: -78, y: -52)
            node(color: .nobsSage)
                .offset(x: 84, y: 10)
            node(color: .nobsAmber)
                .offset(x: -48, y: 68)
        }
        .frame(width: 210, height: 170)
        .animation(.smooth(duration: 2.8).repeatForever(autoreverses: true), value: active)
        .onAppear { active = true }
    }

    private func node(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.6), radius: active ? 12 : 4)
            .scaleEffect(active ? 1.12 : 0.9)
    }
}

extension View {
    func glassSurface(radius: CGFloat = 22) -> some View {
        modifier(GlassSurfaceModifier(radius: radius))
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .background(.regularMaterial, in: shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.24), lineWidth: 0.8)
                    .blendMode(.plusLighter)
            }
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

struct StatusPulse: View {
    let tint: Color
    @State private var active = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(active ? 0.16 : 0.05))
                .frame(width: 42, height: 42)
                .scaleEffect(active ? 1.12 : 0.92)

            Circle()
                .stroke(tint.opacity(0.42), lineWidth: 1)
                .frame(width: 34, height: 34)

            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)
        }
        .animation(.smooth(duration: 1.8).repeatForever(autoreverses: true), value: active)
        .onAppear { active = true }
    }
}

struct NOBSMetric: View {
    let signal: SystemSignal

    var body: some View {
        GlassPanel(padding: 14, radius: 18) {
            HStack(spacing: 12) {
                Image(systemName: signal.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(signal.tint.color)
                    .frame(width: 34, height: 34)
                    .background(signal.tint.color.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(signal.value)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
