//
//  Photogrammetry.swift
//  Calcifer
//
//  Created by chalingco on 2023/08/23.
//

import ComposableArchitecture
import Foundation
import RealityKit

struct Photogrammetry {

    private typealias Configuration = PhotogrammetrySession.Configuration
    private typealias Request = PhotogrammetrySession.Request

    enum CreateResponse: Equatable {
        case startProcessing
        case progress(rate: Double)
        case processingComplete(fileUrl: URL)
        case cancelled
    }

    enum ProcessResponse: Equatable {
        case progress(rate: Double)
        case processingComplete(fileUrl: URL)
    }

    enum CreateError: LocalizedError, Equatable {
        case failedToCreateSession(reason: String)
        case failedToStartProcess(reason: String)
        case other(reason: String)

        var errorDescription: String? {
            switch self {
            case .failedToCreateSession(let reason):
                return reason
            case .failedToStartProcess(let reason):
                return reason
            case .other(let reason):
                return reason
            }
        }
    }

    struct StartSessionParameters {
        let inputFolderUrl: URL
        let outputDstUrl: URL
        let detail: PhotogrammetrySession.Request.Detail
        let sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering
        let featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity
    }

    struct StartSessionResponse: Equatable {
        let session: PhotogrammetrySession
        let outputDstUrl: URL
        let tmpFileUrl: URL?

        static func == (lhs: Photogrammetry.StartSessionResponse, rhs: Photogrammetry.StartSessionResponse) -> Bool {
            lhs.session.id == rhs.session.id && lhs.tmpFileUrl == lhs.tmpFileUrl
        }
    }

    struct BindProcessParameters {
        let session: PhotogrammetrySession
        let outputDstUrl: URL
        let tmpFileUrl: URL?
    }

    static func startSession(params: StartSessionParameters) throws -> StartSessionResponse {
        let tmpFileUrl: URL?
        if params.outputDstUrl.hasDirectoryPath {
            tmpFileUrl = nil
        }
        else {
            let tmpDir = FileManager.default.temporaryDirectory
            tmpFileUrl = tmpDir.appendingPathComponent(params.outputDstUrl.lastPathComponent,
                                                       isDirectory: false)
        }

        let configuration: Configuration = {
            var configuration = Configuration()
            configuration.sampleOrdering = params.sampleOrdering
            configuration.featureSensitivity = params.featureSensitivity
            return configuration
        }()

        let session: PhotogrammetrySession
        do {
            session = try PhotogrammetrySession(input: params.inputFolderUrl,
                                                configuration: configuration)
        }
        catch {
            throw CreateError.failedToCreateSession(reason: error.localizedDescription)
        }

        do {
            let request = Request.modelFile(url: tmpFileUrl ?? params.outputDstUrl, detail: params.detail)
            try session.process(requests: [request])
        }
        catch {
            throw CreateError.failedToStartProcess(reason: error.localizedDescription)
        }

        return .init(session: session,
                     outputDstUrl: params.outputDstUrl,
                     tmpFileUrl: tmpFileUrl)
    }

    static func bindProcess(params: BindProcessParameters) throws -> AsyncStream<TaskResult<ProcessResponse>> {
        return AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    for try await output in params.session.outputs {
                        switch output {
                        case .processingComplete:
                            if let _tmpFileUrl = params.tmpFileUrl {
                                defer {
                                    try? FileManager.default.removeItem(at: _tmpFileUrl)
                                }
                                let content: Data
                                do {
                                    content = try Data(contentsOf: _tmpFileUrl)
                                }
                                catch {
                                    throw CreateError.other(reason: error.localizedDescription)
                                }
                                guard FileManager.default.createFile(atPath: params.outputDstUrl.path,
                                                                     contents: content) else {
                                    throw CreateError.other(reason: "File creation failed")
                                }
                            }
                            continuation.yield(.success(.processingComplete(fileUrl: params.outputDstUrl)))
                            continuation.finish()

                        case .requestError(_, let error):
                            throw CreateError.other(reason: error.localizedDescription)

                        case .requestComplete(_, _):
                            continuation.yield(.success(.progress(rate: 1)))

                        case .requestProgress(_, let fractionComplete):
                            continuation.yield(.success(.progress(rate: fractionComplete)))

                        case .inputComplete:
                            break

                        case .invalidSample(_, _):
                            break

                        case .skippedSample(_):
                            break

                        case .automaticDownsampling:
                            break

                        case .processingCancelled:
                            continuation.finish()
                            break

                        case .requestProgressInfo(_, _):
                            break

                        case .stitchingIncomplete:
                            break

                        @unknown default:
                            break
                        }
                    }
                    return
                }
            }
            continuation.onTermination = { termination in
                switch termination {
                case .finished:
                    logger.trace("process(session:outputDstUrl:tmpFileUrl:) termination.finished")

                case .cancelled:
                    logger.trace("process(session:outputDstUrl:tmpFileUrl:) termination.cancelled")
                    params.session.cancel()

                @unknown default:
                    logger.trace("process(session:outputDstUrl:tmpFileUrl:) termination.unknown")
                }
            }
        }
    }
}
