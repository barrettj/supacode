// Created by Barrett Jacobsen

import Speech
import SwiftUI

struct VoiceInputView: View {
  let onTranscribed: (String) -> Void
  @State private var isRecording = false
  @State private var currentText = ""
  @State private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
  @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  @State private var recognitionTask: SFSpeechRecognitionTask?
  @State private var audioEngine = AVAudioEngine()
  @State private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

  var body: some View {
    VStack(spacing: 8) {
      if !currentText.isEmpty {
        Text(currentText)
          .font(.body.monospaced())
          .foregroundStyle(.secondary)
          .padding(.horizontal)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Button {
        if isRecording {
          stopRecording()
        } else {
          startRecording()
        }
      } label: {
        Image(systemName: isRecording ? "mic.fill" : "mic")
          .font(.title)
          .foregroundStyle(isRecording ? .red : .accentColor)
          .frame(width: 60, height: 60)
          .background(Circle().fill(.ultraThinMaterial))
      }
      .accessibilityLabel(isRecording ? "Stop recording" : "Start voice input")
      .help(isRecording ? "Stop recording" : "Start voice input")

      Text(statusText)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .task {
      SFSpeechRecognizer.requestAuthorization { status in
        Task { @MainActor in
          authorizationStatus = status
        }
      }
    }
  }

  private var statusText: String {
    switch authorizationStatus {
    case .notDetermined: "Requesting permission..."
    case .denied, .restricted: "Speech recognition unavailable"
    case .authorized: isRecording ? "Tap to stop" : "Tap to speak"
    @unknown default: "Tap to speak"
    }
  }

  private func startRecording() {
    guard authorizationStatus == .authorized,
      let speechRecognizer,
      speechRecognizer.isAvailable
    else { return }

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest else { return }
    recognitionRequest.shouldReportPartialResults = true

    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [self] result, error in
      Task { @MainActor in
        if let result {
          currentText = result.bestTranscription.formattedString
          if result.isFinal {
            onTranscribed(currentText)
            currentText = ""
          }
        }
        if error != nil {
          stopRecording()
        }
      }
    }

    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
      recognitionRequest.append(buffer)
    }

    audioEngine.prepare()
    try? audioEngine.start()
    isRecording = true
  }

  private func stopRecording() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionRequest = nil
    recognitionTask = nil

    if !currentText.isEmpty {
      onTranscribed(currentText)
    }
    currentText = ""
    isRecording = false
  }
}
