//
//  AppState.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio) 
//

import ComposableArchitecture
import RealityKit
import SwiftUI

enum Format: String, CaseIterable {
    case usdz
    case usdaAndObj

    var title: String {
        switch self {
        case .usdz:
            return "USDZ"
        case .usdaAndObj:
            return "USDA + OBJ"
        }
    }
}

enum Detail: String, CaseIterable {
    case preview
    case reduced
    case medium
    case full
    case raw

    var title: String {
        switch self {
        case .preview:
            return "Preview"
        case .reduced:
            return "Reduced"
        case .medium:
            return "Medium"
        case .full:
            return "Full"
        case .raw:
            return "Raw"
        }
    }

    var requestCase: PhotogrammetrySession.Request.Detail {
        switch self {
        case .preview:
            return .preview
        case .reduced:
            return .reduced
        case .medium:
            return .medium
        case .full:
            return .full
        case .raw:
            return .raw
        }
    }
}

enum SampleOrdering: String, CaseIterable {
    case unordered
    case sequential

    var title: String {
        switch self {
        case .unordered:
            return "Unordered"
        case .sequential:
            return "Sequential"
        }
    }

    var configurationCase: PhotogrammetrySession.Configuration.SampleOrdering {
        switch self {
        case .unordered:
            return .unordered
        case .sequential:
            return .sequential
        }
    }
}

enum FeatureSensitivity: String, CaseIterable {
    case normal
    case high

    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .high:
            return "High"
        }
    }

    var configurationCase: PhotogrammetrySession.Configuration.FeatureSensitivity {
        switch self {
        case .normal:
            return .normal
        case .high:
            return .high
        }
    }
}
