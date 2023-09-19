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

    @Dependency(\.photogrammetryClient) var photogrammetryClient

    func reduce(into state: inout State, action: Action) -> Effect<Action> {

        struct PhotogrammetryClientId: Hashable {}

        switch action {
        case .formatPickerSelected(let format):
            logger.trace("AppReducer.Action.formatPickerSelected, format:\(format.title)")
            state.format = format
            return .none

        case .detailPickerSelected(let detail):
            logger.trace("AppReducer.Action.detailPickerSelected, detail:\(detail.title)")
            state.detail = detail
            return .none

        case .sampleOrderingPickerSelected(let sampleOrdering):
            logger.trace("AppReducer.Action.sampleOrderingPickerSelected, sampleOrdering:\(sampleOrdering.title)")
            state.sampleOrdering = sampleOrdering
            return .none

        case .featureSensitivityPickerSelected(let featureSensitivity):
            logger.trace("AppReducer.Action.featureSensitivityPickerSelected, featureSensitivity:\(featureSensitivity.title)")
            state.featureSensitivity = featureSensitivity
            return .none

        case .openFolderMenuTapped:
            logger.trace("AppReducer.Action.openFolderMenuTapped")
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
            logger.trace("AppReducer.Action.inputFolderSelected.success")
            state.inputFolderSelecting = false
            state.inputFolderUrl = response.directlyUrl
            state.imageCount = response.imageCount
            state.thumbnail = response.thumbnailImage
            return .none

        case .inputFolderSelected(.failure(let error)):
            logger.trace("AppReducer.Action.inputFolderSelected.failure error:\(error.localizedDescription)")
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
            logger.trace("AppReducer.Action.goButtonTapped")
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
            logger.trace("AppReducer.Action.outputDstSelected.success")
            guard let inputFolderUrl = state.inputFolderUrl else { return .none }
            state.progressRatio = 0
            state.isProcessing = true
            state.isDisableCancelButton = true

            let startSessionParams = Photogrammetry.StartSessionParameters(inputFolderUrl: inputFolderUrl,
                                                                           outputDstUrl: response.selectedUrl,
                                                                           detail: state.detail,
                                                                           sampleOrdering: state.sampleOrdering,
                                                                           featureSensitivity: state.featureSensitivity)
            return .run { send in
                await send(.photogrammetryStartResponse(
                    TaskResult {
                        try photogrammetryClient.startSession(startSessionParams)
                    }
                ))
            }

        case .outputDstSelected(.failure(let error)):
            logger.trace("AppReducer.Action.outputDstSelected.failure error:\(error.localizedDescription)")
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
            logger.trace("AppReducer.Action.photogrammetryStartResponse.success")
            state.isDisableCancelButton = false
            let bindProcessParams = Photogrammetry.BindProcessParameters(session: response.session,
                                                                         outputDstUrl: response.outputDstUrl,
                                                                         tmpFileUrl: response.tmpFileUrl)
            return .run { send in
                for await result in try photogrammetryClient.bindProcess(bindProcessParams) {
                    await send(.photogrammetryProcessResponse(result))
                }
            }.cancellable(id: PhotogrammetryClientId())

        case .photogrammetryStartResponse(.failure(let error)):
            logger.trace("AppReducer.Action.photogrammetryStartResponse.failure error:\(error.localizedDescription)")
            state.isProcessing = false
            state.isDisableCancelButton = false
            return .send(
                .showErrorAlert(message: error.localizedDescription)
            )

        case .cancelButtonTapped:
            logger.trace("AppReducer.Action.cancelButtonTapped")
            state.isProcessing = false
            return .cancel(id: PhotogrammetryClientId())

        case .photogrammetryProcessResponse(.success(let response)):
            logger.trace("AppReducer.Action.photogrammetryProcessResponse.success")
            switch response {
            case .progress(let rate):
                state.progressRatio = rate
            case .processingComplete(let fileUrl):
                state.isProcessing = false
                NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
            }
            return .none

        case .photogrammetryProcessResponse(.failure(let error)):
            logger.trace("AppReducer.Action.photogrammetryProcessResponse.failure error:\(error.localizedDescription)")
            state.isProcessing = false
            return .send(
                .showErrorAlert(message: error.localizedDescription)
            )

        case .showErrorAlert(let message):
            logger.trace("AppReducer.Action.showErrorAlert message:\(message)")
            state.alert = .init(
                title: { TextState("Error") },
                actions: {
                    ButtonState() { TextState("Ok") }
                },
                message: { TextState(message) }
            )
            return .none

        case .alert:
            logger.trace("AppReducer.Action.alert")
            return .none
        }
    }
}
