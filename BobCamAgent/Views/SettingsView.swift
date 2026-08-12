import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settingsManager = SettingsManager.shared

    @State private var sensitivity: Double
    @State private var waitTime: Int
    @State private var messages: [String]

    init() {
        let settings = SettingsManager.shared.settings
        _sensitivity = State(initialValue: settings.sensitivity)
        _waitTime = State(initialValue: settings.waitTimeSeconds)
        _messages = State(initialValue: settings.nudgeMessages)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("감지 설정")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("민감도")
                            Spacer()
                            Text(sensitivityText)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $sensitivity, in: 0...1, step: 0.1)
                    }

                    Picker("대기 시간", selection: $waitTime) {
                        ForEach(1...30, id: \.self) { seconds in
                            Text("\(seconds)초").tag(seconds)
                        }
                    }
                }

                Section(header: Text("넛지 메시지")) {
                    ForEach(messages.indices, id: \.self) { index in
                        HStack {
                            TextField("메시지 \(index + 1)", text: $messages[index])

                            if messages.count > 1 {
                                Button(action: { removeMessage(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    if messages.count < 5 {
                        Button(action: addMessage) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text("메시지 추가")
                            }
                        }
                    }
                }

                Section {
                    NavigationLink(destination: StatisticsView()) {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.blue)
                            Text("식사 기록 보기")
                        }
                    }
                }

                Section {
                    Button(action: resetSettings) {
                        Text("기본값으로 초기화")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveSettings()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }

    private var sensitivityText: String {
        switch sensitivity {
        case 0..<0.3:
            return "낮음"
        case 0.3..<0.7:
            return "보통"
        default:
            return "높음"
        }
    }

    private func addMessage() {
        messages.append("새 메시지")
    }

    private func removeMessage(at index: Int) {
        messages.remove(at: index)
    }

    private func saveSettings() {
        settingsManager.settings = AppSettings(
            sensitivity: sensitivity,
            waitTimeSeconds: waitTime,
            nudgeMessages: messages.filter { !$0.isEmpty }
        )
    }

    private func resetSettings() {
        let defaults = AppSettings.defaultSettings
        sensitivity = defaults.sensitivity
        waitTime = defaults.waitTimeSeconds
        messages = defaults.nudgeMessages
    }
}
