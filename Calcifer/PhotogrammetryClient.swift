//
//  PhotogrammetryClient.swift
//  Calcifer
//
//  (c) 2023 Fumio Saruki (github.com/famio)
//

import ComposableArchitecture

struct PhotogrammetryClient {
    var startSession: @Sendable (_ params: Photogrammetry.StartSessionParameters) throws -> Photogrammetry.StartSessionResponse
    var bindProcess: @Sendable (_ params: Photogrammetry.BindProcessParameters) throws -> AsyncStream<TaskResult<Photogrammetry.ProcessResponse>>
}

extension DependencyValues {
    var photogrammetryClient: PhotogrammetryClient {
        get { self[PhotogrammetryClient.self] }
        set { self[PhotogrammetryClient.self] = newValue }
    }
}

extension PhotogrammetryClient: DependencyKey {
    static var liveValue: Self {
        Value(
            startSession: { params in
                return try Photogrammetry.startSession(params: params)
            },
            bindProcess: { params in
                return try Photogrammetry.bindProcess(params: params)
            })
    }

    static var testValue: Self {
        Value(
            startSession: { params in
                unimplemented("PhotogrammetryClient.fetch unimplemented")
            },
            bindProcess: { params in
                unimplemented("PhotogrammetryClient.fetch unimplemented")
            })
    }
}
