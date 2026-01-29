import Foundation
import Speech
import AVFoundation
import Combine

/// Service for voice-to-text dictation using Apple's Speech framework
@MainActor
public final class DictationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isListening = false
    @Published public private(set) var transcribedText = ""
    @Published public private(set) var isAuthorized = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var audioLevel: Float = 0.0
    
    // MARK: - Private Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var audioLevelTimer: Timer?
    
    private let supportedLocales: [Locale] = [
        Locale(identifier: "en-US"),
        Locale(identifier: "en-GB"),
        Locale(identifier: "es-ES"),
        Locale(identifier: "es-MX"),
        Locale(identifier: "fr-FR"),
        Locale(identifier: "de-DE"),
        Locale(identifier: "it-IT"),
        Locale(identifier: "pt-BR"),
        Locale(identifier: "ja-JP"),
        Locale(identifier: "ko-KR"),
        Locale(identifier: "zh-CN"),
        Locale(identifier: "zh-TW"),
        Locale(identifier: "nl-NL"),
        Locale(identifier: "ru-RU"),
        Locale(identifier: "ar-SA"),
        Locale(identifier: "he-IL"),
        Locale(identifier: "hi-IN"),
        Locale(identifier: "th-TH"),
        Locale(identifier: "vi-VN"),
        Locale(identifier: "pl-PL"),
        Locale(identifier: "tr-TR"),
    ]
    
    // MARK: - Singleton
    
    public static let shared = DictationService()
    
    private init() {
        setupSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Public Methods
    
    /// Request authorization for speech recognition and microphone access
    public func requestAuthorization() async -> Bool {
        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition not authorized. Please enable in System Settings > Privacy & Security > Speech Recognition."
            isAuthorized = false
            return false
        }
        
        // Request microphone authorization
        let micStatus = await AVCaptureDevice.requestAccess(for: .audio)
        
        guard micStatus else {
            errorMessage = "Microphone access not authorized. Please enable in System Settings > Privacy & Security > Microphone."
            isAuthorized = false
            return false
        }
        
        isAuthorized = true
        errorMessage = nil
        return true
    }
    
    /// Change the speech recognition locale
    public func setLocale(_ locale: Locale) {
        setupSpeechRecognizer(locale: locale)
    }
    
    /// Get list of supported locales for speech recognition
    public func getSupportedLocales() -> [Locale] {
        return supportedLocales.filter { locale in
            SFSpeechRecognizer(locale: locale)?.isAvailable ?? false
        }
    }
    
    /// Start listening and transcribing speech
    public func startListening() async throws {
        guard isAuthorized else {
            let authorized = await requestAuthorization()
            guard authorized else {
                throw DictationError.notAuthorized
            }
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw DictationError.recognizerNotAvailable
        }
        
        // Stop any existing session
        stopListening()
        
        // Reset transcribed text
        transcribedText = ""
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw DictationError.audioEngineError
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw DictationError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // Configure audio session
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level for visual feedback
            let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
            Task { @MainActor in
                self?.audioLevel = level
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.stopListening()
                }
                
                if result?.isFinal == true {
                    self.stopListening()
                }
            }
        }
    }
    
    /// Stop listening and finalize transcription
    public func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        isListening = false
        audioLevel = 0.0
    }
    
    /// Toggle listening state
    public func toggleListening() async throws {
        if isListening {
            stopListening()
        } else {
            try await startListening()
        }
    }
    
    /// Clear the current transcription
    public func clearTranscription() {
        transcribedText = ""
    }
    
    // MARK: - Private Methods
    
    private func setupSpeechRecognizer(locale: Locale) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.defaultTaskHint = .dictation
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        // Convert to a 0-1 scale with some amplification
        return min(average * 10, 1.0)
    }
}

// MARK: - Errors

public enum DictationError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case audioEngineError
    case requestCreationFailed
    
    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition or microphone access not authorized"
        case .recognizerNotAvailable:
            return "Speech recognizer is not available for the selected language"
        case .audioEngineError:
            return "Failed to initialize audio engine"
        case .requestCreationFailed:
            return "Failed to create speech recognition request"
        }
    }
}
