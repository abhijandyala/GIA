import SwiftUI

enum GIATypedReplyMode: String, Equatable, Sendable {
    case typing
    case speaking

    var opposite: GIATypedReplyMode {
        self == .typing ? .speaking : .typing
    }

    var switchControlTitle: String {
        self == .typing ? "SPEAK" : "CHAT"
    }

    var switchControlAccessibilityLabel: String {
        self == .typing
            ? "Switch to GIA speaking"
            : "Switch to GIA typing"
    }
}

enum GIATypedChatRole: String, Equatable, Sendable {
    case gia
    case user
}

struct GIATypedChatMessage: Identifiable, Equatable, Sendable {
    var id = UUID()
    var role: GIATypedChatRole
    var text: String
}

struct GIAReplyModePicker: View {
    let onSelect: (GIATypedReplyMode) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    var body: some View {
        ZStack {
            Button(action: onCancel) {
                Color.black
                    .opacity(reduceTransparency ? 0.72 : 0.58)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel typed conversation")

            VStack(spacing: 18) {
                VStack(spacing: 7) {
                    Text("REPLY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(GIAColor.intelligenceAccent)

                    Text("How should GIA answer?")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)
                        .multilineTextAlignment(.center)

                    Text("You type either way. Choose whether GIA types back or speaks.")
                        .font(.footnote)
                        .foregroundStyle(GIAColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 12) {
                    modeCard(
                        mode: .typing,
                        title: "Typing",
                        subtitle: "Chat on screen",
                        animation: AnyView(GIATypingPreview(isActive: !reduceMotion))
                    )
                    modeCard(
                        mode: .speaking,
                        title: "Speaking",
                        subtitle: "GIA talks while you type",
                        animation: AnyView(GIASpeakingPreview(isActive: !reduceMotion))
                    )
                }

                Button("Cancel", action: onCancel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GIAColor.secondaryText)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        GIAColor.menuSurface.opacity(
                            reduceTransparency ? 1 : 0.98
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        GIAColor.subtleStroke.opacity(
                            colorSchemeContrast == .increased ? 1 : 0.9
                        ),
                        lineWidth: colorSchemeContrast == .increased ? 1 : 0.8
                    )
            }
            .padding(.horizontal, 22)
            .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 16)
        }
        .accessibilityAction(.escape, onCancel)
    }

    private func modeCard(
        mode: GIATypedReplyMode,
        title: String,
        subtitle: String,
        animation: AnyView
    ) -> some View {
        Button {
            onSelect(mode)
        } label: {
            HStack(spacing: 16) {
                animation
                    .frame(width: 72, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(GIAColor.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GIAColor.secondaryText)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 92)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GIAColor.planSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GIAColor.subtleStroke, lineWidth: 0.8)
            }
            .contentShape(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityIdentifier("map.replyMode.\(mode.rawValue)")
    }
}

struct GIATypedChatOverlay: View {
    let messages: [GIATypedChatMessage]
    let isBusy: Bool
    var title: String = "TYPE"
    var subtitle: String = "GIA types back"
    var suggestions: [String] = []
    var composerPlaceholder: String = "Tell GIA the trip"
    let onSend: (String) -> Void
    let onClose: () -> Void
    var onSwitchMode: (() -> Void)? = nil
    @Binding var draft: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(messages) { message in
                            chatBubble(message)
                                .id(message.id)
                        }
                        if isBusy {
                            typingIndicator
                                .id("typed-busy")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    scrollToEnd(proxy)
                }
                .onChange(of: isBusy) { _, busy in
                    if busy {
                        scrollToEnd(proxy)
                    }
                }
            }

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                onSend(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(GIAColor.primaryText)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 36)
                                    .background {
                                        Capsule(style: .continuous)
                                            .fill(GIAColor.planSurface)
                                    }
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(
                                                GIAColor.subtleStroke,
                                                lineWidth: 0.8
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(isBusy)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
            }

            GIATypedComposerBar(
                draft: $draft,
                isBusy: isBusy,
                placeholder: composerPlaceholder,
                onSend: onSend
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(GIAColor.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("map.typedChat")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(GIAColor.intelligenceAccent)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer(minLength: 8)

            if let onSwitchMode {
                Button("Speak", action: onSwitchMode)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GIAColor.intelligenceAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        GIATypedReplyMode.typing
                            .switchControlAccessibilityLabel
                    )
                    .accessibilityIdentifier(
                        "map.typedChat.switchToSpeaking"
                    )
            }

            Button("Close", action: onClose)
                .font(.caption.weight(.medium))
                .foregroundStyle(GIAColor.primaryText)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier("map.typedChat.close")
        }
        .padding(.horizontal, 18)
        .padding(.top, GIASpacing.topChromeInset + 32)
        .padding(.bottom, 10)
    }

    private var typingIndicator: some View {
        HStack {
            GIATypingPreview(isActive: !reduceMotion)
                .frame(width: 52, height: 22)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(GIAColor.planSurface)
                }
            Spacer(minLength: 48)
        }
        .accessibilityLabel("GIA is typing")
    }

    private func chatBubble(_ message: GIATypedChatMessage) -> some View {
        let isGIA = message.role == .gia
        return HStack {
            if !isGIA {
                Spacer(minLength: 42)
            }
            VStack(
                alignment: isGIA ? .leading : .trailing,
                spacing: 5
            ) {
                Text(isGIA ? "GIA" : "YOU")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(
                        isGIA
                            ? GIAColor.intelligenceAccent
                            : GIAColor.secondaryText
                    )
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(GIAColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isGIA
                            ? GIAColor.planSurface
                            : GIAColor.intelligenceAccent.opacity(0.10)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isGIA
                            ? GIAColor.subtleStroke
                            : GIAColor.intelligenceAccent.opacity(0.18),
                        lineWidth: 0.8
                    )
            }
            if isGIA {
                Spacer(minLength: 42)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            (isGIA ? "GIA: " : "You: ") + message.text
        )
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            if isBusy {
                proxy.scrollTo("typed-busy", anchor: .bottom)
            } else if let lastID = messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
            return
        }
        withAnimation(GIAMotion.quick) {
            if isBusy {
                proxy.scrollTo("typed-busy", anchor: .bottom)
            } else if let lastID = messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

enum GIATypedComposerStyle: Equatable {
    case standard
    case spotlight
}

struct GIATypedComposerBar: View {
    @Binding var draft: String
    var isBusy: Bool
    var placeholder: String
    var style: GIATypedComposerStyle = .standard
    var onSend: (String) -> Void

    @FocusState private var isFocused: Bool

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 10) {
            if style == .spotlight {
                Image(systemName: "keyboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GIAColor.intelligenceAccent)
                    .accessibilityHidden(true)
            }

            TextField(
                "",
                text: $draft,
                prompt: Text(placeholder)
                    .foregroundStyle(placeholderColor),
                axis: .vertical
            )
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .foregroundStyle(GIAColor.primaryText)
            .lineLimit(1...4)
            .focused($isFocused)
            .onChange(of: draft) { _, value in
                if value.count > 500 {
                    draft = String(value.prefix(500))
                }
            }
            .onSubmit(sendIfPossible)

            Button(action: sendIfPossible) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GIAColor.canvas)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle().fill(sendFill)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, style == .spotlight ? 12 : 8)
        .frame(minHeight: style == .spotlight ? 58 : 44)
        .background {
            RoundedRectangle(
                cornerRadius: style == .spotlight ? 22 : 24,
                style: .continuous
            )
            .fill(fieldFill)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: style == .spotlight ? 22 : 24,
                style: .continuous
            )
            .stroke(fieldStroke, lineWidth: fieldStrokeWidth)
        }
        .shadow(
            color: fieldGlow,
            radius: style == .spotlight ? 16 : 0
        )
        .accessibilityIdentifier("map.typedComposer")
        .disabled(isBusy)
        .onChange(of: isBusy) { _, busy in
            if busy {
                draft = ""
            } else {
                isFocused = true
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    private var placeholderColor: Color {
        style == .spotlight
            ? Color.white.opacity(0.78)
            : GIAColor.secondaryText
    }

    private var sendFill: Color {
        if canSend {
            return style == .spotlight
                ? GIAColor.intelligenceAccent
                : GIAColor.primaryText
        }
        return style == .spotlight
            ? GIAColor.intelligenceAccent.opacity(0.42)
            : GIAColor.primaryText.opacity(0.28)
    }

    private var fieldFill: Color {
        switch style {
        case .standard:
            GIAColor.menuSurface
        case .spotlight:
            Color.white.opacity(0.12)
        }
    }

    private var fieldStroke: Color {
        switch style {
        case .standard:
            GIAColor.subtleStroke
        case .spotlight:
            GIAColor.intelligenceAccent.opacity(0.92)
        }
    }

    private var fieldStrokeWidth: CGFloat {
        style == .spotlight ? 1.8 : 0.8
    }

    private var fieldGlow: Color {
        style == .spotlight
            ? GIAColor.intelligenceAccent.opacity(0.38)
            : .clear
    }

    private var canSend: Bool {
        !trimmedDraft.isEmpty && !isBusy
    }

    private func sendIfPossible() {
        let text = trimmedDraft
        guard canSend else { return }
        draft = ""
        onSend(text)
    }
}

private struct GIATypingPreview: View {
    var isActive: Bool

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: isActive ? 0.12 : 10,
                paused: !isActive
            )
        ) { context in
            let phase = isActive
                ? context.date.timeIntervalSinceReferenceDate
                : 0
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(GIAColor.intelligenceAccent)
                        .frame(width: 6, height: 6)
                        .offset(
                            y: isActive
                                ? CGFloat(
                                    sin(phase * 5.2 + Double(index) * 0.9)
                                ) * -3.5
                                : 0
                        )
                        .opacity(isActive ? 0.55 + (0.45 * wave(phase, index)) : 0.7)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func wave(_ phase: TimeInterval, _ index: Int) -> Double {
        (sin(phase * 5.2 + Double(index) * 0.9) + 1) / 2
    }
}

private struct GIASpeakingPreview: View {
    var isActive: Bool

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: isActive ? 0.08 : 10,
                paused: !isActive
            )
        ) { context in
            let phase = isActive
                ? context.date.timeIntervalSinceReferenceDate
                : 0
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(GIAColor.intelligenceAccent)
                        .frame(
                            width: 4,
                            height: isActive ? barHeight(phase, index) : 10
                        )
                }
            }
            .frame(height: 28)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(_ phase: TimeInterval, _ index: Int) -> CGFloat {
        let wave = sin(phase * 6.4 + Double(index) * 0.72)
        return 8 + CGFloat((wave + 1) / 2) * 18
    }
}

struct GIAReplyModePicker_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GIAColor.canvas.ignoresSafeArea()
            GIAReplyModePicker(onSelect: { _ in }, onCancel: {})
        }
        .preferredColorScheme(.dark)
    }
}
