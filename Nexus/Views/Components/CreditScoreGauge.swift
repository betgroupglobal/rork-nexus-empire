import SwiftUI

struct CreditScoreGauge: View {
    let score: Int
    let size: CGFloat
    var lineWidth: CGFloat = 5
    @State private var animatedProgress: CGFloat = 0

    private var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2), value: animatedProgress)

            Text("\(score)")
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(scoreColor)
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = CGFloat(score) / 100.0
        }
    }
}
