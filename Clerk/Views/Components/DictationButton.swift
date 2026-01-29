import SwiftUI

/// A microphone button that toggles dictation with visual feedback
struct DictationButton: View {
    @ObservedObject private var dictationService = DictationService.shared
    @State private var showingError = false
    
    var onTranscriptionComplete: ((String) -> Void)?
    
    var body: some View {
        Button(action: {
            Task {
                do {
                    if dictationService.isListening {
                        dictationService.stopListening()
                        if !dictationService.transcribedText.isEmpty {
                            onTranscriptionComplete?(dictationService.transcribedText)
                        }
                    } else {
                        try await dictationService.startListening()
                    }
                } catch {
                    showingError = true
                }
            }
        }) {
            ZStack {
                // Background circle with pulse animation when listening
                Circle()
                    .fill(dictationService.isListening ? Color.red.opacity(0.2) : Color.clear)
                    .frame(width: 44, height: 44)
                    .scaleEffect(dictationService.isListening ? 1.0 + CGFloat(dictationService.audioLevel) * 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: dictationService.audioLevel)
                
                // Microphone icon
                Image(systemName: dictationService.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(dictationService.isListening ? .red : Color("AccentGold"))
            }
        }
        .buttonStyle(.plain)
        .help(dictationService.isListening ? "Stop dictation" : "Start dictation")
        .alert("Dictation Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
            if !dictationService.isAuthorized {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
            }
        } message: {
            Text(dictationService.errorMessage ?? "An unknown error occurred")
        }
    }
}

/// A larger dictation view with transcription display for tool input
struct DictationInputView: View {
    @ObservedObject private var dictationService = DictationService.shared
    @Binding var text: String
    @State private var showingError = false
    
    var placeholder: String = "Tap the microphone to start dictating..."
    
    var body: some View {
        VStack(spacing: 12) {
            // Transcription area
            ZStack(alignment: .topLeading) {
                if text.isEmpty && dictationService.transcribedText.isEmpty && !dictationService.isListening {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                
                TextEditor(text: Binding(
                    get: { dictationService.isListening ? dictationService.transcribedText : text },
                    set: { newValue in
                        if !dictationService.isListening {
                            text = newValue
                        }
                    }
                ))
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .disabled(dictationService.isListening)
            }
            .frame(minHeight: 100)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(dictationService.isListening ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Controls
            HStack {
                // Language selector
                if !dictationService.getSupportedLocales().isEmpty {
                    Menu {
                        ForEach(dictationService.getSupportedLocales(), id: \.identifier) { locale in
                            Button(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier) {
                                dictationService.setLocale(locale)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text(Locale.current.localizedString(forIdentifier: Locale.current.identifier) ?? "English")
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                }
                
                Spacer()
                
                // Audio level indicator
                if dictationService.isListening {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Float(index) / 5.0 < dictationService.audioLevel ? Color.red : Color.gray.opacity(0.3))
                                .frame(width: 3, height: 8 + CGFloat(index) * 2)
                        }
                    }
                    .animation(.easeInOut(duration: 0.1), value: dictationService.audioLevel)
                }
                
                // Clear button
                if !text.isEmpty || !dictationService.transcribedText.isEmpty {
                    Button(action: {
                        text = ""
                        dictationService.clearTranscription()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear text")
                }
                
                // Dictation button
                Button(action: {
                    Task {
                        do {
                            if dictationService.isListening {
                                dictationService.stopListening()
                                // Append transcribed text to existing text
                                if !dictationService.transcribedText.isEmpty {
                                    if text.isEmpty {
                                        text = dictationService.transcribedText
                                    } else {
                                        text += " " + dictationService.transcribedText
                                    }
                                    dictationService.clearTranscription()
                                }
                            } else {
                                try await dictationService.startListening()
                            }
                        } catch {
                            showingError = true
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: dictationService.isListening ? "stop.fill" : "mic.fill")
                        Text(dictationService.isListening ? "Stop" : "Dictate")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(dictationService.isListening ? .white : Color("AccentGold"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(dictationService.isListening ? Color.red : Color("AccentGold").opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Dictation Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
            if !dictationService.isAuthorized {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
            }
        } message: {
            Text(dictationService.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            Task {
                await dictationService.requestAuthorization()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DictationButton()
        
        DictationInputView(text: .constant(""))
            .frame(width: 400)
    }
    .padding()
}
