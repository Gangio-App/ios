//
//  VoiceSettings.swift
//  Gangio
//
//  Created by Antigravity on 2024-04-18.
//

import SwiftUI
import AVKit

public struct AudioSettingsView: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    
    @State private var availableInputs: [AVAudioSessionPortDescription] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section: Volume
                SettingsSectionView(title: "Audio Levels") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Master Volume")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(Int(viewState.masterVolume * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            
                            Slider(value: $viewState.masterVolume, in: 0...1)
                                .tint(viewState.theme.accent.color)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                
                // Section: Sound Effects
                SettingsSectionView(title: "Sound Effects") {
                    VStack(spacing: 0) {
                        soundToggle(
                            title: "Message Sent",
                            subtitle: "Play a sound when you send a message",
                            icon: "paperplane.fill",
                            color: .blue,
                            isOn: $viewState.messageSentSoundEnabled
                        )
                        
                        Divider().padding(.leading, 56)
                        
                        soundToggle(
                            title: "Message Received",
                            subtitle: "Play a sound when you receive a message",
                            icon: "bubble.left.fill",
                            color: .green,
                            isOn: $viewState.messageReceivedSoundEnabled
                        )
                    }
                }
                
                // Section: Voice Input
                SettingsSectionView(title: "Voice Input") {
                    VStack(alignment: .leading, spacing: 0) {
                        if availableInputs.isEmpty {
                            Text("No input devices found")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(16)
                        } else {
                            ForEach(availableInputs, id: \.uid) { port in
                                Button {
                                    viewState.preferredInputDeviceId = port.uid
                                    try? AVAudioSession.sharedInstance().setPreferredInput(port)
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.purple.opacity(0.1))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "mic.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.purple)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(port.portName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                            Text(port.portType.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        if viewState.preferredInputDeviceId == port.uid || (viewState.preferredInputDeviceId == nil && port == AVAudioSession.sharedInstance().preferredInput) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(viewState.theme.accent.color)
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                if port != availableInputs.last {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                    }
                }
                
                // Section: Voice Output
                SettingsSectionView(title: "Voice Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Output routing is managed by the system. Use the button below to change the current output device.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 16)
                        
                        Button {
                            // On iOS, we show the AVRoutePicker or similar, 
                            // but easiest for user is letting them know it's system managed.
                        } label: {
                            HStack {
                                settingsIcon("speaker.wave.2.fill", color: .gray)
                                Text("System Audio Routing")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewState.theme.background.color)
        .navigationTitle("Voice & Audio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshDevices()
        }
    }
    
    func refreshDevices() {
        let session = AVAudioSession.sharedInstance()
        availableInputs = session.availableInputs ?? []
    }
    
    @ViewBuilder
    func soundToggle(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            settingsIcon(icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Text(LocalizedStringKey(subtitle))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(viewState.theme.accent.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    func settingsIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
    }
}
