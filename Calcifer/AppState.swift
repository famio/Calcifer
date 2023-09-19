//
//  AppState.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio) 
//

import ComposableArchitecture
import RealityKit
import SwiftUI

typealias Detail = PhotogrammetrySession.Request.Detail
typealias SampleOrdering = PhotogrammetrySession.Configuration.SampleOrdering
typealias FeatureSensitivity = PhotogrammetrySession.Configuration.FeatureSensitivity

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

extension Detail {

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

        case .custom:
            return "Custom"

        @unknown default:
            return "Unknown"
        }
    }

    static let candidates: [Self] = [.preview, .reduced, .medium, .full, .raw]
}

extension SampleOrdering {

    var title: String {
        switch self {

        case .unordered:
            return "Unordered"

        case .sequential:
            return "Sequential"

        @unknown default:
            return "Unknown"
        }
    }

    static let candidates: [Self] = [.unordered, .sequential]
}

extension FeatureSensitivity {

    var title: String {
        switch self {

        case .normal:
            return "Normal"

        case .high:
            return "High"

        @unknown default:
            return "Unknown"
        }
    }

    static let candidates: [Self] = [.normal, .high]
}
