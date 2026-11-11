import SwiftUI

struct HybrixLogoMark: View {
    var size: CGFloat = 110

    var body: some View {
        ZStack {
            // Outer Hexagonal / Shield Glow
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.14, blue: 0.18),
                            Color(red: 0.06, green: 0.06, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.orange, .red.opacity(0.8), .mint.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(2, size * 0.032)
                        )
                )
                .shadow(color: .orange.opacity(0.35), radius: size * 0.16, y: size * 0.06)

            // Stylized Hybrid "H" + Barbell + Conditioning Pulse
            ZStack {
                // Left & Right Weight Plates / Pillars of the "H"
                HStack(spacing: size * 0.26) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size * 0.13, height: size * 0.52)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size * 0.13, height: size * 0.52)
                }

                // Outer Bumper Plate Caps
                HStack(spacing: size * 0.58) {
                    Capsule(style: .continuous)
                        .fill(Color.orange.opacity(0.85))
                        .frame(width: size * 0.065, height: size * 0.34)

                    Capsule(style: .continuous)
                        .fill(Color.orange.opacity(0.85))
                        .frame(width: size * 0.065, height: size * 0.34)
                }

                // Crossbar with High-Voltage Hybrid Bolt
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(white: 0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.42, height: size * 0.09)

                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.24, height: size * 0.24)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            }
        }
    }
}

struct HybrixSplashView: View {
    @State private var logoScale: CGFloat = 0.82
    @State private var logoOpacity: Double = 0.0
    @State private var taglineOffset: CGFloat = 12

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.07),
                    Color(red: 0.10, green: 0.08, blue: 0.11),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle Ambient Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.22), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 420, height: 420)
                .offset(y: -40)

            VStack(spacing: 22) {
                HybrixLogoMark(size: 118)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("HYBRIX")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .tracking(5)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.82)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("PERIODIZED STRENGTH · HYBRID CONDITIONING")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.orange)
                }
                .opacity(logoOpacity)
                .offset(y: taglineOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                logoScale = 1.0
                logoOpacity = 1.0
                taglineOffset = 0
            }
        }
    }
}
