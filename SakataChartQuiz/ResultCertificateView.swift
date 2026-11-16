import SwiftUI
import UIKit

struct ResultShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}

struct ResultShareSheet: UIViewControllerRepresentable {
    let item: ResultShareImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [item.text, item.image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

/// A fixed canvas keeps the exported image independent of screen size and appearance.
struct ResultCertificateView: View {
    let correctCount: Int
    let questionCount: Int
    let bestStreak: Int
    let mode: String
    let chartSource: String
    let date: Date

    private let gold = Color(red: 0.91, green: 0.77, blue: 0.45)
    private let navy = Color(red: 0.045, green: 0.075, blue: 0.16)

    private var accuracy: Double {
        questionCount > 0 ? Double(correctCount) / Double(questionCount) : 0
    }

    private var grade: String {
        if questionCount > 0 && correctCount == questionCount { return String(localized: "皆伝") }
        if accuracy >= 0.8 { return String(localized: "成績優秀") }
        if accuracy >= 0.6 { return String(localized: "着実前進") }
        return String(localized: "日々精進")
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("酒田道場")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .tracking(6)
                .padding(.top, 30)
            Text("ローソク足 練習免状")
                .font(.system(size: 29, weight: .bold, design: .serif))
                .padding(.top, 24)
            Text(verbatim: "CERTIFICATE OF ACHIEVEMENT")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .tracking(2)
                .padding(.top, 8)

            ZStack {
                Text(grade)
                    .font(.system(size: 53, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                Text(accuracy >= 0.8 ? "優\n秀" : "修\n練")
                    .font(.system(size: 21, weight: .heavy, design: .serif))
                    .lineSpacing(0)
                    .foregroundStyle(Color(red: 0.79, green: 0.22, blue: 0.16))
                    .padding(7)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.79, green: 0.22, blue: 0.16), lineWidth: 3))
                    .rotationEffect(.degrees(12))
                    .offset(x: 136, y: -40)
            }
            .frame(height: 130)

            ornament
            HStack(spacing: 18) {
                metric(
                    title: String(localized: "正解率"),
                    value: accuracy.formatted(.percent.precision(.fractionLength(0))),
                    detail: String(localized: "\(questionCount)問中 \(correctCount)問正解")
                )
                metric(
                    title: String(localized: "最大連続正解"),
                    value: "\(bestStreak)",
                    detail: String(localized: "連続正解数")
                )
            }
            .padding(.top, 24)

            Text("修練の記録")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .padding(.top, 30)
            VStack(spacing: 12) {
                Text(verbatim: "\(chartSource) · \(mode)")
                Text("ローソク足の形を学び、相場を読む力を磨く")
                    .font(.system(size: 12, design: .serif))
            }
            .font(.system(size: 16, weight: .medium, design: .serif))
            .padding(.top, 14)
            ornament.padding(.top, 24)
            Text(date, format: .dateTime.year().month().day())
                .font(.system(size: 12, design: .serif))
                .padding(.top, 20)
            Text("酒田五法 ローソク足学習アプリ")
                .font(.system(size: 11, design: .serif))
                .padding(.top, 7)
        }
        .padding(.horizontal, 38)
        .frame(width: 440, height: 700, alignment: .top)
        .foregroundStyle(gold)
        .background {
            ZStack {
                LinearGradient(colors: [navy, Color(red: 0.09, green: 0.16, blue: 0.28), navy], startPoint: .topLeading, endPoint: .bottomTrailing)
                CertificateDecoration().stroke(gold.opacity(0.06), lineWidth: 0.7)
            }
        }
        .overlay {
            ZStack {
                Rectangle().inset(by: 12).stroke(gold, lineWidth: 1.5)
                Rectangle().inset(by: 19).stroke(gold.opacity(0.7), lineWidth: 0.6)
                CertificateCorners().stroke(gold, lineWidth: 1.4)
            }
        }
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .medium)
    }

    private var ornament: some View {
        HStack(spacing: 10) {
            Rectangle().frame(height: 0.7)
            Image(systemName: "diamond.fill").font(.system(size: 7))
            Image(systemName: "seal").font(.system(size: 18))
            Image(systemName: "diamond.fill").font(.system(size: 7))
            Rectangle().frame(height: 0.7)
        }
    }

    private func metric(title: String, value: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Text(title).font(.system(size: 16, weight: .bold, design: .serif))
            Text(verbatim: value)
                .font(.system(size: 49, weight: .medium, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(detail)
                .font(.system(size: 11, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 127)
        .overlay(Rectangle().stroke(gold.opacity(0.8), lineWidth: 0.8))
    }

}

private struct CertificateCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for flipX in [false, true] {
            for flipY in [false, true] {
                let points = [CGPoint(x: 26, y: 64), CGPoint(x: 26, y: 26), CGPoint(x: 64, y: 26), CGPoint(x: 64, y: 34), CGPoint(x: 34, y: 34), CGPoint(x: 34, y: 64), CGPoint(x: 26, y: 64)]
                    .map { CGPoint(x: flipX ? rect.width - $0.x : $0.x, y: flipY ? rect.height - $0.y : $0.y) }
                path.move(to: points[0])
                path.addLines(points)
            }
        }
        return path
    }
}

private struct CertificateDecoration: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for row in 0..<12 {
            for column in 0..<9 {
                let center = CGPoint(x: CGFloat(column) * 64 + (row.isMultiple(of: 2) ? 0 : 32), y: CGFloat(row) * 64)
                for radius in stride(from: 12.0, through: 44.0, by: 8) {
                    path.move(to: CGPoint(x: center.x - radius, y: center.y))
                    path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                }
            }
        }
        return path
    }
}

#Preview {
    ResultCertificateView(correctCount: 18, questionCount: 20, bestStreak: 12, mode: "パターン名4択", chartSource: "基本形", date: .now)
}
