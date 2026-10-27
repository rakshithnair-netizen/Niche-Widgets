import SwiftUI

struct LocalAISettingsSection: View {
    enum TestState: Equatable {
        case idle
        case testing
        case success(model: String, seconds: Double)
        case failure(String)
    }

    @Bindable var settings: LocalAISettings
    let client: OllamaClient
    @State private var testState = TestState.idle
    @State private var testTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            row("Model", subtitle: "Any model installed in Ollama") {
                GlassTextField(LocalAISettings.defaultModel, text: $settings.modelName)
                    .frame(width: DS.Size.settingsFieldWidth)
            }
            GlassDivider()
            row("Keep model loaded", subtitle: "Unload frees memory, longer is faster for follow ups") {
                GlassSegmentedControl(ModelKeepAlive.allCases, selection: $settings.keepAlive) { $0.title }
            }
            GlassDivider()
            row("Connection", subtitle: "Checks Ollama and times a short reply") {
                HStack(spacing: DS.Spacing.md) {
                    result
                    GlassButton(testState == .testing ? "Testing…" : "Test connection", systemImage: "bolt.horizontal", variant: .secondary, action: test)
                        .fixedSize()
                        .disabled(testState == .testing)
                }
            }
        }
        .animation(DS.Motion.smooth.animation(reduceMotion: reduceMotion), value: testState)
        .onDisappear { testTask?.cancel() }
    }

    @ViewBuilder
    private var result: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            LoadingShimmer(lines: 1)
                .frame(width: DS.Size.skeletonTrailing)
                .transition(.opacity)
        case .success(let model, let seconds):
            Label("\(model) · \(seconds.formatted(.number.precision(.fractionLength(2)))) s", systemImage: "checkmark.circle.fill")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.success)
                .transition(.opacity)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.warning)
                .lineLimit(2)
                .transition(.opacity)
        }
    }

    private func test() {
        let model = settings.resolvedModel
        let keepAlive = settings.keepAlive.seconds
        let client = client
        testState = .testing
        testTask?.cancel()
        testTask = Task {
            let state: TestState
            do {
                let duration = try await client.ping(model: model, keepAlive: keepAlive)
                let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
                state = .success(model: model, seconds: seconds)
            } catch {
                state = .failure(Self.describe(OllamaClient.map(error), model: model))
            }
            guard !Task.isCancelled else { return }
            testState = state
        }
    }

    static func describe(_ error: OllamaError, model: String) -> String {
        switch error {
        case .serverNotRunning: "Ollama isn't running. Run ollama serve"
        case .modelMissing: "Not installed. Run ollama pull \(model)"
        case .timeout: "Timed out"
        case .cancelled: "Cancelled"
        case .badResponse(let message): message
        }
    }

    private func row<Accessory: View>(_ title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.bodyEmphasis)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.textSecondary)
            }
            Spacer(minLength: DS.Spacing.md)
            accessory()
        }
    }
}
