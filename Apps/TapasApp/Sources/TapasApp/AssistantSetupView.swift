import SwiftUI
import TapasCore

@MainActor @Observable
final class AssistantSetupModel {
    var host: AssistantHost = .codex
    var status = "Not installed"
    var message: String?
}

struct AssistantSetupView: View {
    @Bindable var model: AssistantSetupModel
    var onAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(AssistantHost.allCases) { host in
                    Button {
                        model.host = host
                        onAction("refresh")
                    } label: {
                        Text(host.label)
                            .font(.system(size: 11, weight: model.host == host ? .semibold : .regular))
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .foregroundStyle(Grafico.ink)
                            .background(model.host == host ? Grafico.saffron : Grafico.paper,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Grafico.ink.opacity(model.host == host ? 1 : 0.3), lineWidth: 1)
                                    .allowsHitTesting(false)
                            }
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(model.host == host ? .isSelected : [])
                }
            }.accessibilityElement(children: .contain).accessibilityLabel("Assistant")
            HStack(spacing: 12) {
                Button(model.status == "Update available" ? "Update skill" : "Install skill") { onAction("install") }
                    .disabled(model.status == "Installed")
                    .buttonStyle(GraficoButtonStyle(secondary: true, compact: true))
                Text(model.status).font(.system(size: 11)).textSelection(.enabled)
            }
            Text("Your assistant may send transcript text to its provider. Installing the skill does not grant file access.")
                .font(.system(size: 11)).foregroundStyle(Grafico.muted)
            if let message = model.message {
                ViewThatFits(in: .vertical) {
                    Text(message).fixedSize(horizontal: false, vertical: true)
                    ScrollView { Text(message).frame(maxWidth: .infinity, alignment: .leading) }
                }.font(.system(size: 11)).frame(maxHeight: 55).textSelection(.enabled)
            }
        }.tint(Grafico.olive).font(.system(size: 12))
            .onAppear { onAction("refresh") }
    }
}
