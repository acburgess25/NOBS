import SwiftUI

// MARK: - Shimmer Animation Key

private struct ShimmerPhaseKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var shimmerPhase: CGFloat {
        get { self[ShimmerPhaseKey.self] }
        set { self[ShimmerPhaseKey.self] = newValue }
    }
}

// MARK: - SkeletonShape

/// A single rounded rectangle block with a warm shimmer gradient.
struct SkeletonShape: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var radius: CGFloat = Radius.sm

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(shimmerGradient)
            .frame(width: width, height: height)
            .onAppear { startAnimation() }
    }

    private var shimmerGradient: LinearGradient {
        let base   = Color.nobsSurface
        let bright = Color(red: 0.94, green: 0.92, blue: 0.88) // warm near-white
        return LinearGradient(
            stops: [
                .init(color: base,   location: phase - 0.3),
                .init(color: bright, location: phase),
                .init(color: base,   location: phase + 0.3)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func startAnimation() {
        // Start off-screen left, sweep to off-screen right
        phase = -0.3
        withAnimation(
            .linear(duration: 1.3)
            .repeatForever(autoreverses: false)
        ) {
            phase = 1.3
        }
    }
}

// MARK: - TaskRowSkeleton

/// Mimics a pending task row: 24pt circle + two stacked text lines.
struct TaskRowSkeleton: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Checkbox circle placeholder
            SkeletonShape(width: 24, height: 24, radius: Radius.full)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title line — full width
                SkeletonShape(height: 15, radius: Radius.sm)
                // Subtitle line — narrower
                SkeletonShape(width: 120, height: 12, radius: Radius.sm)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - MemoryRowSkeleton

/// Mimics a memory card: title line + two shorter body lines.
struct MemoryRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            SkeletonShape(height: 15, radius: Radius.sm)
            // Body line 1
            SkeletonShape(height: 13, radius: Radius.sm)
            // Body line 2 — shorter
            SkeletonShape(width: 200, height: 13, radius: Radius.sm)
        }
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - SkeletonList

/// Stacks 5 TaskRowSkeletons — drop into a List or VStack while loading.
struct SkeletonList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                TaskRowSkeleton()
                    .padding(.horizontal, Spacing.md)
                Divider()
                    .padding(.leading, Spacing.md + 24 + Spacing.md)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Task skeleton") {
    ZStack {
        Color.nobsBg.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 0) {
            Text("Pending")
                .sectionOverline()
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            SkeletonList()
        }
    }
}

#Preview("Memory skeleton") {
    ZStack {
        Color.nobsBg.ignoresSafeArea()
        VStack(spacing: Spacing.md) {
            MemoryRowSkeleton()
            MemoryRowSkeleton()
            MemoryRowSkeleton()
        }
        .padding(Spacing.md)
    }
}
#endif