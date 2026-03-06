import SwiftUI

struct HealthRingView: View {
    let score: Int
    let size: CGFloat
    var lineWidth: CGFloat = 6
    var showLabel: Bool = true

    private var progress: Double {
        Double(score) / 100.0
    }

    private var ringColor: Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if showLabel {
                Text("\(score)")
                    .font(.system(size: size * 0.28, weight: .bold, design: .default))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: size, height: size)
    }
}
