//
//  AppAction.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import SwiftUI
import RealityKit

enum AppAction: Equatable {
    
    case formatPickerSelected(Format)
    case detailPickerSelected(Detail)
    case sampleOrderingPickerSelected(SampleOrdering)
    case featureSensitivityPickerSelected(FeatureSensitivity)
    case openFolderMenuTapped
    case inputFolderSelected(Result<FileManagerEffect.OpenFolderSelectResponse, FileManagerEffect.OpenFolderSelectError>)
    case goButtonTapped
    case outputDstSelected(Result<FileManagerEffect.OutputDstSelectResponse, FileManagerEffect.OutputDstSelectError>)
    case photogrammetryCreateResponse(Result<PhotogrammetryEffect.CreateResponse, PhotogrammetryEffect.CreateError>)
    case cancelButtonTapped
    
    case showErrorAlert(title: String, message: String)
    case alertCancelTapped
    case alertDismissed
}
