//
//  AppReducer.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import ComposableArchitecture
import SwiftUI

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
    
    struct PhotogrammetryClientId: Hashable {}
    
    switch action {
    case .formatPickerSelected(let format):
        state.format = format
        return .none
        
    case .detailPickerSelected(let detail):
        state.detail = detail
        return .none
        
    case .sampleOrderingPickerSelected(let sampleOrdering):
        state.sampleOrdering = sampleOrdering
        return .none
        
    case .featureSensitivityPickerSelected(let featureSensitivity):
        state.featureSensitivity = featureSensitivity
        return .none
        
    case .openFolderMenuTapped:
        state.inputFolderSelecting = true
        return environment.fileManagerEffect.openFolderSelect()
            .catchToEffect()
            .map(AppAction.inputFolderSelected)
        
    case .inputFolderSelected(.success(let response)):
        state.inputFolderSelecting = false
        state.inputFolderUrl = response.directlyUrl
        state.imageCount = response.imageCount
        state.thumbnail = response.thumbnailImage
        return .none
        
    case .inputFolderSelected(.failure(let error)):
        state.inputFolderSelecting = false
        switch error {
        case .noImage, .other:
            state.alert = .init(title: .init("Error"),
                                message: .init(error.localizedDescription),
                                dismissButton: .default(TextState("Confirm")))
        case .cancel:
            break
        }
        return .none
        
    case .goButtonTapped:
        guard let inputFolderUrl = state.inputFolderUrl else { return .none }
        switch state.format {
        case .usdz:
            let fileName = inputFolderUrl.lastPathComponent + "_" + state.detail.rawValue + ".usdz"
            return environment.fileManagerEffect.outputFileSelect(inputFolderUrl, fileName)
                .receive(on: DispatchQueue.main)
                .catchToEffect()
                .map(AppAction.outputDstSelected)
        case .usdaAndObj:
            return environment.fileManagerEffect.outputFolderSelect(inputFolderUrl)
                .receive(on: DispatchQueue.main)
                .catchToEffect()
                .map(AppAction.outputDstSelected)
        }
        
    case .outputDstSelected(.success(let response)):
        guard let inputFolderUrl = state.inputFolderUrl else { return .none }
        state.progressRatio = 0
        state.isProcessing = true
        return environment.photogrammetryEffect.create(inputFolderUrl,
                                                       response.selectedUrl,
                                                       state.detail.requestCase,
                                                       state.sampleOrdering.configurationCase,
                                                       state.featureSensitivity.configurationCase)
            .receive(on: DispatchQueue.main)
            .catchToEffect()
            .map(AppAction.photogrammetryCreateResponse)
            .cancellable(id: PhotogrammetryClientId())
        
    case .outputDstSelected(.failure(let error)):
        return .none
        
    case .cancelButtonTapped:
        state.isProcessing = false
        return .cancel(id: PhotogrammetryClientId())
        
    case .photogrammetryCreateResponse(.success(.startProcessing)):
        state.isProcessing = true
        return .none
        
    case .photogrammetryCreateResponse(.success(.progress(let rate))):
        state.progressRatio = rate
        return .none
        
    case .photogrammetryCreateResponse(.success(.processingComplete(let fileUrl))):
        state.isProcessing = false
        NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
        return .none
        
    case .photogrammetryCreateResponse(.failure(let error)):
        state.isProcessing = false
        state.alert = .init(title: .init("Error"),
                            message: .init(error.localizedDescription),
                            dismissButton: .default(TextState("Confirm")))
        return .none
        
    case .showErrorAlert(let title, let message):
        // Alert の状態を初期化している
        // title, message, primaryButton など Alert の詳細については Reducer 内で定義している
        state.alert = .init(title: .init(title),
                            message: .init(message),
                            dismissButton: .default(TextState("Confirm")))
        return .none
    case .alertCancelTapped:
        // Cancel ボタンを押した時は特にすることはないので、`none` Effect を返却するのみ
        return .none
    case .alertDismissed:
        // Alert が dismiss する時にこの Action は発火する
        // dismiss するということは Alert は表示されないようになって欲しいということ
        // state.alert を nil にすれば Alert が表示されないようになる
        state.alert = nil
        return .none
    }
}
