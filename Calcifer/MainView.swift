//
//  MainView.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import ComposableArchitecture
import SwiftUI
import AVFoundation
import RealityKit

struct MainView: View {

    let store: StoreOf<AppReducer>

    private let pickerWidth: CGFloat = 400

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(alignment: .center, spacing: 18, content: {

                // Inputフォルダ
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Folder").bold().foregroundColor(.secondary)
                    ZStack {
                        Color(.segmentedNormal)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        if let firstImage = viewStore.thumbnail {
                            Image(firstImage, scale: 1, label: Text("Image"))
                                .resizable()
                                .scaledToFill()
                                .frame(width: pickerWidth, height: pickerWidth / 4 * 3)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            Label("\(viewStore.imageCount)", systemImage: "photo.on.rectangle.angled")
                                .padding(6)
                                .background(VisualEffectView(material: .contentBackground,
                                                             blendingMode: .withinWindow,
                                                             alpha: 0.6))
                                .cornerRadius(8)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .topLeading)
                                .padding(10)
                        }
                        else {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .aspectRatio(contentMode: ContentMode.fit)
                                .frame(width: 40)
                        }
                    }
                    .frame(
                        width: pickerWidth,
                        height: pickerWidth / 4 * 3)
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                    .onTapGesture {
                        viewStore.send(.openFolderMenuTapped)
                    }
                    .disabled(viewStore.isProcessing)
                }

                // Format
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format").bold().foregroundColor(Color.secondary)
                    Picker("Format", selection: viewStore.binding(get: { $0.format }, send: { .formatPickerSelected($0) })) {
                        ForEach(Format.allCases, id: \.self) { detail in
                            Text(detail.title)
                                .tag(detail)
                        }
                    }
                    .disabled(viewStore.isProcessing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Orderling").bold().foregroundColor(Color.secondary)
                    Picker("Sample Orderling", selection: viewStore.binding(get: { $0.sampleOrdering }, send: { .sampleOrderingPickerSelected($0) })) {
                        ForEach(SampleOrdering.candidates, id: \.self) { detail in
                            Text(detail.title)
                                .tag(detail)
                        }
                    }
                    .disabled(viewStore.isProcessing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Feature Sensitivity").bold().foregroundColor(Color.secondary)
                    Picker("Feature Sensitivity", selection: viewStore.binding(get: { $0.featureSensitivity }, send: { .featureSensitivityPickerSelected($0) })) { 
                        ForEach(FeatureSensitivity.candidates, id: \.self) { detail in
                            Text(detail.title).tag(detail)
                        }
                    }
                    .disabled(viewStore.isProcessing)
                }

                // Detail
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detail").bold().foregroundColor(Color.secondary)
                    Picker("Detail", selection: viewStore.binding(get: { $0.detail }, send: { .detailPickerSelected($0) })) {
                        ForEach(Detail.candidates, id: \.self) { detail in
                            Text(detail.title)
                                .tag(detail)
                        }
                    }
                    .disabled(viewStore.isProcessing)
                }

                if viewStore.isProcessing {
                    VStack {
                        // キャンセルボタン
                        Button(action: {
                            viewStore.send(.cancelButtonTapped) }) {
                                Text("Cancel")
                                    .font(.system(size: 18, weight: .bold))
                                    .frame(width: 100,
                                           height: 40)
                            }
                            .buttonStyle(CancelButtonStyle())
                            .disabled(viewStore.isDisableCancelButton)
                        // プログレスバー
                        HStack(alignment: .center, spacing: 8) {
                            Text("\(Int(viewStore.progressRatio * 100)) %")
                                .frame(alignment: .trailing)
                                .monospacedDigit()
                            ProgressView(value: viewStore.progressRatio)
                        }
                    }
                }
                else {
                    // 作成ボタン
                    Button(action: {
                        viewStore.send(.goButtonTapped) }) {
                            Text(viewStore.inputFolderUrl == nil ? "Ready..." : "Go!")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 100,
                                       height: 40)
                        }
                        .buttonStyle(GoButtonStyle())
                        .disabled(viewStore.inputFolderUrl == nil)
                }
            })
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: pickerWidth)
                .padding()
                .disabled(viewStore.inputFolderSelecting)
        }
        .alert(store: store.scope(state: \.$alert, action: { .alert($0) }))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let alpha: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        visualEffectView.alphaValue = alpha
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct GoButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? .primary : .secondary)
            .background(isEnabled ? Color(.goButtonEnabled) : Color.clear)
            .cornerRadius(.infinity)
            .overlay(
                RoundedRectangle(cornerRadius: .infinity)
                    .stroke(
                        isEnabled ? Color.primary : Color.secondary,
                        lineWidth: 1.0))
            .padding()
    }
}

struct CancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .background(Color.clear)
            .cornerRadius(.infinity)
            .overlay(
                RoundedRectangle(cornerRadius: .infinity)
                    .stroke(
                        Color.secondary,
                        lineWidth: 1.0))
            .padding()
    }
}

#Preview {
    MainView(store: Store(initialState: AppReducer.State()) {
        AppReducer()
    })
}
