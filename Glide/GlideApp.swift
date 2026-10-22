//  Glide — a motion + Liquid Glass playground for iPhone
//  Needs iOS 26 or newer (built with Xcode 26).

import SwiftUI
import CoreMotion

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
    var prefs = Prefs()
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("Cards", systemImage: "square.stack.fill", value: 0) {
                CardsView(active: tab == 0)
            }
            Tab("Glass", systemImage: "drop.fill", value: 1) {
                PlaygroundView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3", value: 2) {
                SettingsView()
            }
        }
        // The glass tab bar shrinks away while you scroll down, then comes back.
        .tabBarMinimizeBehavior(prefs.scrollFX ? .onScrollDown : .never)
        .onAppear { TiltSensor.shared.setActive(prefs.tiltOn) }
        .onChange(of: prefs.tiltOn) { _, on in TiltSensor.shared.setActive(on) }
    }
}

// MARK: - Settings shared across the app

/// How see-through the glass inside this app is.
enum GlassLook: String, CaseIterable, Identifiable {
    case clear
    case regular

    var id: String { rawValue }
    var title: String { self == .clear ? "Clear" : "Regular" }
    var glass: Glass { self == .clear ? .clear : .regular }
}

/// Every switch on the Settings page, readable from any screen.
struct Prefs: DynamicProperty {
    @AppStorage("smoothMotion") var smooth = true
    @AppStorage("haptics") var haptics = true
    @AppStorage("zoomOpen") var zoomOpen = true
    @AppStorage("squish") var squish = true
    @AppStorage("scrollEffects") var scrollEffects = true
    @AppStorage("liveBackground") var liveBackground = true
    @AppStorage("extraSmooth") var extraSmooth = false
    @AppStorage("flyIn") var flyIn = false
    @AppStorage("tilt") var tilt = false
    @AppStorage("bounce") var bounce: Double = 0.25
    @AppStorage("glassLook") var look: GlassLook = .clear

    // An effect only runs when its own switch AND Smooth motion are on.
    var zoomOn: Bool { smooth && zoomOpen }
    var squishOn: Bool { smooth && squish }
    var scrollFX: Bool { smooth && scrollEffects }
    var backgroundOn: Bool { smooth && liveBackground }
    var flyInOn: Bool { smooth && flyIn }
    var tiltOn: Bool { smooth && tilt }

    /// The app's main spring. nil means "no animation" (Smooth motion off).
    var spring: Animation? {
        guard smooth else { return nil }
        return extraSmooth
            ? .smooth(duration: 0.85, extraBounce: bounce * 0.5)
            : .bouncy(duration: 0.55, extraBounce: bounce)
    }

    /// A quick spring for small things like press feedback.
    var quick: Animation? {
        guard smooth else { return nil }
        return extraSmooth ? .smooth(duration: 0.4) : .snappy
    }
}

extension View {
    /// Liquid Glass in whatever look was picked in Settings.
    func liquidGlass<S: Shape>(_ look: GlassLook, in shape: S, interactive: Bool = false) -> some View {
        glassEffect(interactive ? look.glass.interactive() : look.glass, in: shape)
    }
}

/// Runs a change with no animation at all (used when Smooth motion is off).
func withoutAnimation(_ change: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, change)
}

/// Buttons squish down a little when pressed and spring back.
struct SquishButtonStyle: ButtonStyle {
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = enabled && configuration.isPressed
        return configuration.label
            .scaleEffect(pressed ? 0.94 : 1)
            .brightness(pressed ? -0.05 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: pressed)
    }
}

// MARK: - Tilt sensor

/// Reads how you're tilting the iPhone, for the "Tilt with phone" switch.
@Observable
final class TiltSensor {
    static let shared = TiltSensor()

    /// Left / right lean, roughly -1 ... 1
    var x: Double = 0
    /// Forward / back lean, roughly -1 ... 1
    var y: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?

    func setActive(_ on: Bool) {
        if on {
            guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
            reference = nil // the way you hold the phone now becomes "flat"
            manager.deviceMotionUpdateInterval = 1.0 / 60.0
            manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self, let attitude = data?.attitude else { return }
                if self.reference == nil {
                    self.reference = attitude.copy() as? CMAttitude
                }
                if let reference = self.reference {
                    attitude.multiply(byInverseOf: reference)
                }
                let newX = max(-1, min(1, attitude.roll / 0.6))
                let newY = max(-1, min(1, attitude.pitch / 0.6))
                // Smooth out the jitter.
                self.x += (newX - self.x) * 0.18
                self.y += (newY - self.y) * 0.18
            }
        } else {
            manager.stopDeviceMotionUpdates()
            x = 0
            y = 0
        }
    }
}

// MARK: - Moving background

/// A slowly flowing colour mesh, so the glass always has something to bend.
struct LiveBackground: View {
    var animated = true

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation) { context in
                    let t = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                    MeshGradient(width: 3, height: 3, points: Self.points(t), colors: Self.colors)
                }
            } else {
                MeshGradient(width: 3, height: 3, points: Self.points(0), colors: Self.colors)
            }
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
                   detail: "Want it calmer? Turn on Extra smooth in Settings, or turn Smooth motion off to make everything instant.")
    ]
}

// MARK: - Cards screen

struct CardsView: View {
    let active: Bool
    var prefs = Prefs()
    @Namespace private var zoom
    @State private var opened: MotionCard?
    @State private var shown = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(MotionCard.all.enumerated()), id: \.element.id) { index, card in
                        cardButton(card, index: index)
                    }
                }
                .padding(16)
                .padding(.bottom, 100) // room for the floating buttons
            }
            .background(LiveBackground(animated: prefs.backgroundOn))
            .navigationTitle("Glide")
            .overlay(alignment: .bottomTrailing) {
                QuickActions()
                    .padding(20)
            }
        }
        .fullScreenCover(item: $opened) { card in
            if prefs.zoomOn {
                CardDetailView(card: card)
                    .navigationTransition(.zoom(sourceID: card.id, in: zoom))
            } else {
                CardDetailView(card: card)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened) { _, _ in prefs.haptics }
        .onAppear { shown = true }
        .onChange(of: active) { _, isActive in
            // Replay "Cards fly in" every time you come back to this tab.
            guard isActive, prefs.flyInOn else { return }
            withoutAnimation { shown = false }
            DispatchQueue.main.async { shown = true }
        }
    }

    private func cardButton(_ card: MotionCard, index: Int) -> some View {
        let visible = shown || !prefs.flyInOn
        let scrollFX = prefs.scrollFX
        let flyAnimation: Animation? = prefs.flyInOn ? prefs.spring?.delay(Double(index) * 0.07) : nil

        return Button {
            open(card)
        } label: {
            CardTile(card: card, look: prefs.look, tilt: prefs.tiltOn)
        }
        .buttonStyle(SquishButtonStyle(enabled: prefs.squishOn))
        .matchedTransitionSource(id: card.id, in: zoom)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(scrollFX && !phase.isIdentity ? 0.88 : 1)
                .opacity(scrollFX && !phase.isIdentity ? 0.4 : 1)
                .blur(radius: scrollFX && !phase.isIdentity ? 6 : 0)
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 70)
        .scaleEffect(visible ? 1 : 0.85)
        .animation(flyAnimation, value: shown)
    }

    private func open(_ card: MotionCard) {
        if prefs.smooth {
            opened = card
        } else {
            withoutAnimation { opened = card }
        }
    }
}

struct CardTile: View {
    let card: MotionCard
    let look: GlassLook
    let tilt: Bool

    var body: some View {
        // Only read the sensor when tilt is on, so cards don't redraw otherwise.
        let tx: CGFloat = tilt ? TiltSensor.shared.x : 0
        let ty: CGFloat = tilt ? TiltSensor.shared.y : 0

        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: card.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            Image(systemName: card.symbol)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: tx * 14, y: -20 + ty * 14)

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
        .rotation3DEffect(.degrees(tx * 10), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(-ty * 10), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .shadow(color: (card.colors.first ?? .black).opacity(0.35), radius: 14, x: -tx * 10, y: 8 - ty * 6)
    }
}

/// The floating + button. Tap it and glass buttons melt out of it.
struct QuickActions: View {
    var prefs = Prefs()
    @State private var expanded = false
    @Namespace private var glassSpace

    private let actions = ["heart.fill", "star.fill", "paperplane.fill"]

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 14) {
                if expanded {
                    ForEach(actions, id: \.self) { icon in
                        Button {
                            withAnimation(prefs.spring) { expanded = false }
                        } label: {
                            Image(systemName: icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .liquidGlass(prefs.look, in: Circle(), interactive: true)
                                .glassEffectID(icon, in: glassSpace)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    withAnimation(prefs.spring) { expanded.toggle() }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(expanded ? 45 : 0))
                        .frame(width: 62, height: 62)
                        .liquidGlass(prefs.look, in: Circle(), interactive: true)
                        .glassEffectID("toggle", in: glassSpace)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: expanded) { _, _ in prefs.haptics }
    }
}

// MARK: - Card detail (opens with a zoom, closes back into the card)

struct CardDetailView: View {
    let card: MotionCard
    var prefs = Prefs()
    @Environment(\.dismiss) private var dismiss
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
                        .symbolEffectsRemoved(!prefs.smooth)
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
                        .liquidGlass(prefs.look, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                                    .liquidGlass(prefs.look, in: Capsule())
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
                            .liquidGlass(prefs.look, in: Capsule(), interactive: true)
                    }
                    .buttonStyle(SquishButtonStyle(enabled: prefs.squishOn))
                    .padding(.top, 8)
                }
                .padding(20)
            }

            Button {
                if prefs.smooth {
                    dismiss()
                } else {
                    withoutAnimation { dismiss() }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .liquidGlass(prefs.look, in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
        .onAppear {
            if prefs.smooth {
                withAnimation(prefs.spring?.delay(0.15)) { appeared = true }
                pulse += 1
            } else {
                appeared = true
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pulse) { _, _ in prefs.haptics }
    }
}

// MARK: - Glass playground

/// Drag a big drop of glass around and watch it bend the words behind it.
struct PlaygroundView: View {
    var prefs = Prefs()
    @State private var drag: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        // With "Tilt with phone" on, the drop also rolls as you tilt.
        let tx: CGFloat = prefs.tiltOn ? TiltSensor.shared.x : 0
        let ty: CGFloat = prefs.tiltOn ? TiltSensor.shared.y : 0

        ZStack {
            LiveBackground(animated: prefs.backgroundOn)

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
                .liquidGlass(prefs.look, in: Circle(), interactive: true)
                .scaleEffect(isDragging && prefs.squishOn ? 1.15 : 1)
                .offset(x: drag.width + tx * 90, y: drag.height + ty * 90)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            drag = value.translation
                            if !isDragging {
                                withAnimation(prefs.quick) { isDragging = true }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(prefs.spring) {
                                drag = .zero
                                isDragging = false
                            }
                        }
                )

            VStack {
                Spacer()
                Text(prefs.tiltOn ? "Drag the glass, or tilt your phone." : "Drag the glass. Let go and it springs back.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .liquidGlass(prefs.look, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isDragging) { _, _ in prefs.haptics }
    }
}

// MARK: - Settings

struct SettingsView: View {
    var prefs = Prefs()
    @AppStorage("smoothMotion") private var smooth = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("zoomOpen") private var zoomOpen = true
    @AppStorage("squish") private var squish = true
    @AppStorage("scrollEffects") private var scrollEffects = true
    @AppStorage("liveBackground") private var liveBackground = true
    @AppStorage("extraSmooth") private var extraSmooth = false
    @AppStorage("flyIn") private var flyIn = false
    @AppStorage("tilt") private var tilt = false
    @AppStorage("bounce") private var bounce: Double = 0.25
    @AppStorage("glassLook") private var look: GlassLook = .clear
    @State private var ballOnRight = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $smooth) {
                        Label("Smooth motion", systemImage: "wand.and.stars")
                    }
                    Toggle(isOn: $haptics) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Motion")
                } footer: {
                    Text("Turn Smooth motion off and everything happens instantly, with no animation.")
                }

                Section {
                    Toggle(isOn: $zoomOpen) {
                        Label("Zoom open & close", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Toggle(isOn: $squish) {
                        Label("Squish when pressed", systemImage: "hand.tap")
                    }
                    Toggle(isOn: $scrollEffects) {
                        Label("Scroll effects", systemImage: "scroll")
                    }
                    Toggle(isOn: $liveBackground) {
                        Label("Moving background", systemImage: "circle.hexagongrid")
                    }
                } header: {
                    Text("Effects")
                }
                .disabled(!smooth)

                Section {
                    Toggle(isOn: $extraSmooth) {
                        Label("Extra smooth", systemImage: "water.waves")
                    }
                    Toggle(isOn: $flyIn) {
                        Label("Cards fly in", systemImage: "square.grid.2x2")
                    }
                    Toggle(isOn: $tilt) {
                        Label("Tilt with phone", systemImage: "gyroscope")
                    }
                } header: {
                    Text("More")
                } footer: {
                    Text("Extra smooth makes every movement slower and silkier. Cards fly in one by one when you open the Cards tab. Tilt makes the cards and the glass drop lean as you move your iPhone.")
                }
                .disabled(!smooth)

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
                    .disabled(!smooth)

                    Circle()
                        .fill(.tint)
                        .frame(width: 36, height: 36)
                        .frame(maxWidth: .infinity, alignment: ballOnRight ? .trailing : .leading)
                        .padding(.vertical, 6)

                    Button("Test the motion") {
                        withAnimation(prefs.spring) { ballOnRight.toggle() }
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
