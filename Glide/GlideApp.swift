//  Glide — a motion + Liquid Glass playground for iPhone
//  Needs iOS 26 or newer (built with Xcode 26).

import SwiftUI

// MARK: - App

@main
struct GlideApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Cards", systemImage: "square.stack.fill") {
                CardsView()
            }
            Tab("Glass", systemImage: "drop.fill") {
                PlaygroundView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3") {
                SettingsView()
            }
        }
        // The glass tab bar shrinks away while you scroll down, then comes back.
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

// MARK: - Shared settings

/// How see-through the glass inside this app is.
enum GlassLook: String, CaseIterable, Identifiable {
    case clear
    case regular

    var id: String { rawValue }
    var title: String { self == .clear ? "Clear" : "Regular" }
    var glass: Glass { self == .clear ? .clear : .regular }
}

extension View {
    /// Liquid Glass in whatever look was picked in Settings.
    func liquidGlass<S: Shape>(_ look: GlassLook, in shape: S, interactive: Bool = false) -> some View {
        glassEffect(interactive ? look.glass.interactive() : look.glass, in: shape)
    }
}

extension Animation {
    /// The app's main spring. `bounce` comes from the Settings slider.
    static func glide(_ bounce: Double) -> Animation {
        .bouncy(duration: 0.55, extraBounce: bounce)
    }
}

/// Buttons squish down a little when pressed and spring back.
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - Moving background

/// A slowly flowing colour mesh, so the glass always has something to bend.
struct LiveBackground: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
            MeshGradient(width: 3, height: 3, points: Self.points(t), colors: Self.colors)
        }
        .ignoresSafeArea()
    }

    static let colors: [Color] = [
        .indigo, .purple, .pink,
        .blue, .teal, .orange,
        .mint, .cyan, .yellow
    ]

    typealias P = SIMD2<Float>

    static func points(_ t: Float) -> [P] {
        let left: Float = 0.5 + 0.12 * sin(t * 0.7)
        let right: Float = 0.5 + 0.12 * cos(t * 0.5)
        let cx: Float = 0.5 + 0.18 * cos(t * 0.6)
        let cy: Float = 0.5 + 0.18 * sin(t * 0.8)
        return [
            P(0, 0), P(0.5, 0), P(1, 0),
            P(0, left), P(cx, cy), P(1, right),
            P(0, 1), P(0.5, 1), P(1, 1)
        ]
    }
}

// MARK: - Card data

struct MotionCard: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
    let detail: String

    static let all: [MotionCard] = [
        MotionCard(id: 1, title: "Spring", subtitle: "Bouncy open", symbol: "wind",
                   colors: [.pink, .orange],
                   detail: "This card zoomed out of the grid. Swipe down or tap the X and it shrinks back into its exact spot."),
        MotionCard(id: 2, title: "Glass", subtitle: "Clear layers", symbol: "drop.fill",
                   colors: [.indigo, .cyan],
                   detail: "Every panel here is real Liquid Glass. Switch between Clear and Regular in Settings to see the difference."),
        MotionCard(id: 3, title: "Morph", subtitle: "Shapes melt", symbol: "circle.hexagongrid.fill",
                   colors: [.mint, .teal],
                   detail: "Tap the + button on the Cards screen. The glass buttons melt out of each other like drops of water."),
        MotionCard(id: 4, title: "Sparkle", subtitle: "Tiny details", symbol: "sparkles",
                   colors: [.purple, .pink],
                   detail: "Small touches add up: a haptic tap when things open, icons that bounce, text that slides in."),
        MotionCard(id: 5, title: "Wave", subtitle: "Scroll effects", symbol: "wave.3.right",
                   colors: [.blue, .mint],
                   detail: "Scroll the grid and watch cards shrink and blur as they leave the screen, then grow back in."),
        MotionCard(id: 6, title: "Bolt", subtitle: "Snappy taps", symbol: "bolt.fill",
                   colors: [.orange, .yellow],
                   detail: "Press and hold any card. It squishes under your finger and springs back when you let go."),
        MotionCard(id: 7, title: "Orbit", subtitle: "Smooth loops", symbol: "atom",
                   colors: [.teal, .indigo],
                   detail: "The background never stops moving. It is a colour mesh that flows slowly at 120 frames per second."),
        MotionCard(id: 8, title: "Night", subtitle: "Calm mode", symbol: "moon.stars.fill",
                   colors: [.indigo, .purple],
                   detail: "Want less bounce? Drag the Bounce slider in Settings toward Calm and every spring in the app softens.")
    ]
}

// MARK: - Cards screen

struct CardsView: View {
    @Namespace private var zoom
    @State private var opened: MotionCard?
    @AppStorage("glassLook") private var look: GlassLook = .clear

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(MotionCard.all) { card in
                        Button {
                            opened = card
                        } label: {
                            CardTile(card: card, look: look)
                        }
                        .buttonStyle(SquishButtonStyle())
                        .matchedTransitionSource(id: card.id, in: zoom)
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.88)
                                .opacity(phase.isIdentity ? 1 : 0.4)
                                .blur(radius: phase.isIdentity ? 0 : 6)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 100) // room for the floating buttons
            }
            .background(LiveBackground())
            .navigationTitle("Glide")
            .overlay(alignment: .bottomTrailing) {
                QuickActions(look: look)
                    .padding(20)
            }
        }
        .fullScreenCover(item: $opened) { card in
            CardDetailView(card: card)
                .navigationTransition(.zoom(sourceID: card.id, in: zoom))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened)
    }
}

struct CardTile: View {
    let card: MotionCard
    let look: GlassLook

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: card.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            Image(systemName: card.symbol)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -20)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.headline)
                Text(card.subtitle)
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(look, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(8)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: (card.colors.first ?? .black).opacity(0.35), radius: 14, y: 8)
    }
}

/// The floating + button. Tap it and glass buttons melt out of it.
struct QuickActions: View {
    let look: GlassLook
    @AppStorage("bounce") private var bounce: Double = 0.25
    @State private var expanded = false
    @Namespace private var glassSpace

    private let actions = ["heart.fill", "star.fill", "paperplane.fill"]

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 14) {
                if expanded {
                    ForEach(actions, id: \.self) { icon in
                        Button {
                            withAnimation(.glide(bounce)) { expanded = false }
                        } label: {
                            Image(systemName: icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .liquidGlass(look, in: Circle(), interactive: true)
                                .glassEffectID(icon, in: glassSpace)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    withAnimation(.glide(bounce)) { expanded.toggle() }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(expanded ? 45 : 0))
                        .frame(width: 62, height: 62)
                        .liquidGlass(look, in: Circle(), interactive: true)
                        .glassEffectID("toggle", in: glassSpace)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: expanded)
    }
}

// MARK: - Card detail (opens with a zoom, closes back into the card)

struct CardDetailView: View {
    let card: MotionCard
    @Environment(\.dismiss) private var dismiss
    @AppStorage("glassLook") private var look: GlassLook = .clear
    @AppStorage("bounce") private var bounce: Double = 0.25
    @State private var pulse = 0
    @State private var appeared = false

    private let chips = ["Spring", "Glass", "Haptics"]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: card.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: card.symbol)
                        .font(.system(size: 120, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: pulse)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .padding(.top, 70)

                    Text(card.title)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(card.detail)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .liquidGlass(look, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)

                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(chips, id: \.self) { chip in
                                Text(chip)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .liquidGlass(look, in: Capsule())
                            }
                        }
                    }
                    .offset(y: appeared ? 0 : 60)
                    .opacity(appeared ? 1 : 0)

                    Button {
                        pulse += 1
                    } label: {
                        Label("Play motion", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 14)
                            .liquidGlass(look, in: Capsule(), interactive: true)
                    }
                    .buttonStyle(SquishButtonStyle())
                    .padding(.top, 8)
                }
                .padding(20)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .liquidGlass(look, in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
        .onAppear {
            withAnimation(.glide(bounce).delay(0.15)) { appeared = true }
            pulse += 1
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pulse)
    }
}

// MARK: - Glass playground

/// Drag a big drop of glass around and watch it bend the words behind it.
struct PlaygroundView: View {
    @AppStorage("glassLook") private var look: GlassLook = .clear
    @AppStorage("bounce") private var bounce: Double = 0.25
    @State private var drag: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        ZStack {
            LiveBackground()

            // Busy content behind the glass so you can see it refract.
            VStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { row in
                    Text("LIQUID GLASS")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize()
                        .offset(x: row.isMultiple(of: 2) ? -28 : 28)
                }
            }
            .rotationEffect(.degrees(-12))

            Color.clear
                .frame(width: 160, height: 160)
                .contentShape(Circle())
                .liquidGlass(look, in: Circle(), interactive: true)
                .scaleEffect(isDragging ? 1.15 : 1)
                .offset(drag)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            drag = value.translation
                            if !isDragging {
                                withAnimation(.snappy) { isDragging = true }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.glide(bounce)) {
                                drag = .zero
                                isDragging = false
                            }
                        }
                )

            VStack {
                Spacer()
                Text("Drag the glass. Let go and it springs back.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .liquidGlass(look, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isDragging)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("glassLook") private var look: GlassLook = .clear
    @AppStorage("bounce") private var bounce: Double = 0.25
    @State private var ballOnRight = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Glass", selection: $look) {
                        ForEach(GlassLook.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Glass look")
                } footer: {
                    Text("Clear is the most see-through. This only changes glass inside Glide. For your Home Screen and Control Center, use iPhone Settings → Appearance → Liquid Glass.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Slider(value: $bounce, in: 0...0.6)
                        HStack {
                            Text("Calm")
                            Spacer()
                            Text("Bouncy")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Circle()
                        .fill(.tint)
                        .frame(width: 36, height: 36)
                        .frame(maxWidth: .infinity, alignment: ballOnRight ? .trailing : .leading)
                        .padding(.vertical, 6)

                    Button("Test the bounce") {
                        withAnimation(.glide(bounce)) { ballOnRight.toggle() }
                    }
                } header: {
                    Text("Bounce")
                } footer: {
                    Text("Changes every spring in the app: opening cards, the + menu and the glass playground.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
