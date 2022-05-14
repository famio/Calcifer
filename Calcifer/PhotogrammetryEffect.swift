//
//  PhotogrammetryEffect.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import Combine
import ComposableArchitecture
import RealityKit
import SwiftUI

struct PhotogrammetryEffect {
    var create: (_ inputFolderUrl: URL,
                 _ outputDstUrl: URL,
                 _ detail: PhotogrammetrySession.Request.Detail,
                 _ sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering,
                 _ featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity) -> Effect<CreateResponse, CreateError>
    
    enum CreateResponse: Equatable {
        case startProcessing
        case processingComplete(fileUrl: URL)
        case progress(rate: Double)
    }
    
    enum CreateError: Error, Equatable {
        case failedToCreateSession(reason: String)
        case failedToStartProcess(reason: String)
        case other(reason: String)
    }
}

extension PhotogrammetryEffect.CreateError: LocalizedError {
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

extension PhotogrammetryEffect {
    
    private typealias Configuration = PhotogrammetrySession.Configuration
    private typealias Request = PhotogrammetrySession.Request
    
    static let live = PhotogrammetryEffect(
        create: { inputFolderUrl, outputDstUrl, detail, sampleOrdering, featureSensitivity in
            return Effect.run { subscriber in
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
                    subscriber.send(completion: .failure(.failedToCreateSession(reason: error.localizedDescription)))
                    return AnyCancellable {}
                }
                
                Task {
                    do {
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
                                        subscriber.send(completion: .failure(.other(reason: error.localizedDescription)))
                                        return
                                    }
                                    guard FileManager.default.createFile(atPath: outputDstUrl.path, contents: content) else {
                                        subscriber.send(completion: .failure(.other(reason: "File creation failed")))
                                        return
                                    }
                                }
                                subscriber.send(.processingComplete(fileUrl: outputDstUrl))
                                subscriber.send(completion: .finished)
                                
                            case .requestError(let request, let error):
                                subscriber.send(completion: .failure(.other(reason: error.localizedDescription)))
                            case .requestComplete(let request, let result):
                                break
                            case .requestProgress(let request, let fractionComplete):
                                subscriber.send(.progress(rate: fractionComplete))
                            case .inputComplete:
                                break
                            case .invalidSample(let id, let reason):
                                break
                            case .skippedSample(let id):
                                break
                            case .automaticDownsampling:
                                break
                            case .processingCancelled:
                                break
                            @unknown default:
                                break
                            }
                        }
                    }
                    catch {
                        subscriber.send(completion: .failure(.other(reason: error.localizedDescription)))
                    }
                }
                
                do {
                    let request = Request.modelFile(url: tmpFileUrl ?? outputDstUrl, detail: detail)
                    try session.process(requests: [request])
                }
                catch {
                    subscriber.send(completion: .failure(.failedToStartProcess(reason: error.localizedDescription)))
                    return AnyCancellable {}
                }
                
                return AnyCancellable {
                    session.cancel()
                }
            }
        }
    )
}
