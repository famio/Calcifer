//
//  AppReducer.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import ComposableArchitecture
import RealityKit
import SwiftUI

struct AppReducer: Reducer {

    struct State: Equatable {
        var format: Format = .usdz
        var detail: Detail = .medium
        var sampleOrdering: SampleOrdering = .unordered
        var featureSensitivity: FeatureSensitivity = .normal
        var inputFolderUrl: URL?
        var inputFolderSelecting = false
        var outputFileUrl: URL?
        var isProcessing = false
        var isDisableCancelButton = false
        var progressRatio: Double = 0
        var imageCount: Int = 0
        var thumbnail: CGImage?

        @PresentationState var alert: AlertState<Action.Alert>?
    }

    enum Action: Equatable {
        case formatPickerSelected(Format)
        case detailPickerSelected(Detail)
        case sampleOrderingPickerSelected(SampleOrdering)
        case featureSensitivityPickerSelected(FeatureSensitivity)
        case openFolderMenuTapped
        case inputFolderSelected(TaskResult<AppFileManager.OpenFolderSelectResponse>)
        case goButtonTapped
        case outputDstSelected(TaskResult<AppFileManager.OutputFileSelectResponse>)
        case photogrammetryStartResponse(TaskResult<Photogrammetry.StartSessionResponse>)
        case photogrammetryProcessResponse(TaskResult<Photogrammetry.ProcessResponse>)
        case cancelButtonTapped

        case showErrorAlert(message: String)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
        }
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {

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
            return .run { send in
                await send(
                    .inputFolderSelected(
                        TaskResult {
                            try await AppFileManager.openFolderSelect()
                        }
                    )
                )
            }

        case .inputFolderSelected(.success(let response)):
            state.inputFolderSelecting = false
            state.inputFolderUrl = response.directlyUrl
            state.imageCount = response.imageCount
            state.thumbnail = response.thumbnailImage
            return .none

        case .inputFolderSelected(.failure(let error)):
            state.inputFolderSelecting = false
            guard let openFolderSelectError = error as? AppFileManager.OpenFolderSelectError else { return .none }
            switch openFolderSelectError {
            case .noImage, .other:
                return .send(
                    .showErrorAlert(message: error.localizedDescription)
                )

            case .cancel:
                break
            }
            return .none

        case .goButtonTapped:
            guard let inputFolderUrl = state.inputFolderUrl else { return .none }
            switch state.format {
            case .usdz:
                let fileName = inputFolderUrl.lastPathComponent + "_" + state.detail.title.lowercased() + ".usdz"
                return .run { send in
                    await send(
                        .outputDstSelected(
                            TaskResult {
                                try await AppFileManager.outputFileSelect(directoryUrl: inputFolderUrl, initialFileName: fileName)
                            }
                        )
                    )
                }

            case .usdaAndObj:
                return .run { send in
                    await send(
                        .outputDstSelected(
                            TaskResult {
                                try await AppFileManager.outputFolderSelect(directoryUrl: inputFolderUrl)
                            }
                        )
                    )
                }
            }

        case .outputDstSelected(.success(let response)):
            guard let inputFolderUrl = state.inputFolderUrl else { return .none }
            state.progressRatio = 0
            state.isProcessing = true
            state.isDisableCancelButton = true

            let detail = state.detail
            let sampleOrdering = state.sampleOrdering
            let featureSensitivity = state.featureSensitivity
            return .run { send in
                await send(.photogrammetryStartResponse(
                    TaskResult {
                        try Photogrammetry.startSession(inputFolderUrl: inputFolderUrl,
                                                        outputDstUrl: response.selectedUrl,
                                                        detail: detail,
                                                        sampleOrdering: sampleOrdering,
                                                        featureSensitivity: featureSensitivity)
                    }
                ))
            }

        case .outputDstSelected(.failure(let error)):
            guard let openFolderSelectError = error as? AppFileManager.OutputFileSelectError else { return .none }
            switch openFolderSelectError {
            case .other:
                return .send(
                    .showErrorAlert(message: error.localizedDescription)
                )

            case .cancel:
                return .none
            }

        case .photogrammetryStartResponse(.success(let response)):
            state.isDisableCancelButton = false
            return .run { send in
                for await result in try Photogrammetry.process(session: response.session,
                                                               outputDstUrl: response.outputDstUrl,
                                                               tmpFileUrl: response.tmpFileUrl) {
                    await send(.photogrammetryProcessResponse(result))
                }
            }.cancellable(id: PhotogrammetryClientId())

        case .photogrammetryStartResponse(.failure(let error)):
            state.isProcessing = false
            state.isDisableCancelButton = false
            return .send(
                .showErrorAlert(message: error.localizedDescription)
            )

        case .cancelButtonTapped:
            state.isProcessing = false
            return .cancel(id: PhotogrammetryClientId())

        case .photogrammetryProcessResponse(.success(let response)):
            switch response {
            case .progress(let rate):
                state.progressRatio = rate
            case .processingComplete(let fileUrl):
                state.isProcessing = false
                NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
            }
            return .none

        case .photogrammetryProcessResponse(.failure(let error)):
            state.isProcessing = false
            return .send(
                .showErrorAlert(message: error.localizedDescription)
            )

        case .showErrorAlert(let message):
            state.alert = .init(
                title: { TextState("Error") },
                actions: {
                    ButtonState() { TextState("Ok") }
                },
                message: { TextState(message) }
            )
            return .none

        case .alert:
            return .none
        }
    }
}
