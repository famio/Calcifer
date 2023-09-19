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

    struct StartSessionResponse: Equatable {
        let session: PhotogrammetrySession
        let outputDstUrl: URL
        let tmpFileUrl: URL?

        static func == (lhs: Photogrammetry.StartSessionResponse, rhs: Photogrammetry.StartSessionResponse) -> Bool {
            lhs.session.id == rhs.session.id && lhs.tmpFileUrl == lhs.tmpFileUrl
        }
    }

    static func startSession(inputFolderUrl: URL,
                             outputDstUrl: URL,
                             detail: PhotogrammetrySession.Request.Detail,
                             sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering,
                             featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity) throws -> StartSessionResponse {
        let tmpFileUrl: URL?
        if outputDstUrl.hasDirectoryPath {
            tmpFileUrl = nil
        }
        else {
            let tmpDir = FileManager.default.temporaryDirectory
            tmpFileUrl = tmpDir.appendingPathComponent(outputDstUrl.lastPathComponent, isDirectory: false)
        }

        let configuration: Configuration = {
            var configuration = Configuration()
            configuration.sampleOrdering = sampleOrdering
            configuration.featureSensitivity = featureSensitivity
            return configuration
        }()

        let session: PhotogrammetrySession
        do {
            session = try PhotogrammetrySession(input: inputFolderUrl,
                                                configuration: configuration)
        }
        catch {
            throw CreateError.failedToCreateSession(reason: error.localizedDescription)
        }

        do {
            let request = Request.modelFile(url: tmpFileUrl ?? outputDstUrl, detail: detail)
            try session.process(requests: [request])
        }
        catch {
            throw CreateError.failedToStartProcess(reason: error.localizedDescription)
        }

        return .init(session: session,
                     outputDstUrl: outputDstUrl,
                     tmpFileUrl: tmpFileUrl)
    }

    static func process(session: PhotogrammetrySession, outputDstUrl: URL, tmpFileUrl: URL?) throws -> AsyncStream<TaskResult<ProcessResponse>> {
        return AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    for try await output in session.outputs {
                        switch output {
                        case .processingComplete:
                            if let _tmpFileUrl = tmpFileUrl {
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
                                guard FileManager.default.createFile(atPath: outputDstUrl.path, contents: content) else {
                                    throw CreateError.other(reason: "File creation failed")
                                }
                            }
                            continuation.yield(.success(.processingComplete(fileUrl: outputDstUrl)))
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
                    print("finish task")
                case .cancelled:
                    print("cancelled")
                    session.cancel()
                @unknown default:
                    print("unknown termination: termination")
                }
            }
        }
    }
}
