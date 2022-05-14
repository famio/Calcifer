//
//  FileManagerEffect.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import ComposableArchitecture
import SwiftUI

struct FileManagerEffect {
    
    struct OpenFolderSelectResponse: Equatable {
        let directlyUrl: URL
        let imageCount: Int
        let thumbnailImage: CGImage
    }
    
    var openFolderSelect: () -> Effect<OpenFolderSelectResponse, OpenFolderSelectError>
    
    enum OpenFolderSelectError: Error, LocalizedError {
        case cancel
        case noImage
        case other
        
        var errorDescription: String? {
            switch self {
            case .cancel: return "Cancel"
            case .noImage: return "No image is available"
            case .other: return "Error"
            }
        }
    }
    
    struct OutputDstSelectResponse: Equatable {
        let selectedUrl: URL
    }
    
    var outputFileSelect: (_ directoryUrl: URL, _ initialFileName: String) -> Effect<OutputDstSelectResponse, OutputDstSelectError>
    
    var outputFolderSelect: (_ directoryUrl: URL) -> Effect<OutputDstSelectResponse, OutputDstSelectError>
    
    enum OutputDstSelectError: Error, LocalizedError {
        case cancel
        case other
    }
}

extension FileManagerEffect {
    static let live = FileManagerEffect(
        openFolderSelect: {
            return Effect<OpenFolderSelectResponse, OpenFolderSelectError>.future { callback in
                let openPanel = NSOpenPanel()
                // ファイル選択を拒否
                openPanel.canChooseFiles = false
                openPanel.canChooseDirectories = true
                // 複数選択を拒否
                openPanel.allowsMultipleSelection = false
                // Desktopを初期値に設定
                let homeURL = FileManager.default.homeDirectoryForCurrentUser
                let desktopURL = homeURL.appendingPathComponent("Desktop/")
                openPanel.directoryURL = desktopURL
                openPanel.message = "Select a folder"
                openPanel.begin { response in
                    switch response {
                    case .OK:
                        guard let url = openPanel.urls.first else {
                            callback(.failure(.other))
                            return
                        }
                        do {
                            let imageFileNames = try getImageFileNames(directoryUrl: url)
                            let image = try getFirstImage(imageFileNames: imageFileNames, directoryUrl: url)
                            callback(.success(.init(directlyUrl: url, imageCount: imageFileNames.count, thumbnailImage: image)))
                        }
                        catch OpenFolderSelectError.noImage {
                            callback(.failure(.noImage))
                        }
                        catch {
                            callback(.failure(.other))
                        }
                    case .cancel:
                        callback(.failure(.cancel))
                    default:
                        callback(.failure(.other))
                    }
                }
            }
        },
        outputFileSelect: { directoryUrl, initialFileName in
            return Effect<OutputDstSelectResponse, OutputDstSelectError>.future { callback in
                let savePanel = NSSavePanel()
                savePanel.directoryURL = directoryUrl
                savePanel.nameFieldStringValue = initialFileName
                savePanel.allowedContentTypes = [.usdz]
                savePanel.allowsOtherFileTypes = false
                savePanel.canCreateDirectories = true
                savePanel.begin { response in
                    switch response {
                    case .OK:
                        guard let url = savePanel.url else {
                            assertionFailure()
                            callback(.failure(OutputDstSelectError.other))
                            return
                        }
                        callback(.success(.init(selectedUrl: url)))
                    case .cancel:
                        callback(.failure(OutputDstSelectError.cancel))
                    default:
                        callback(.failure(OutputDstSelectError.other))
                    }
                }
            }
        },
        outputFolderSelect: { directoryUrl in
            return Effect<OutputDstSelectResponse, OutputDstSelectError>.future { callback in
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = false
                openPanel.canChooseDirectories = true
                openPanel.canCreateDirectories = true
                openPanel.allowsMultipleSelection = false
                openPanel.directoryURL = directoryUrl
                openPanel.message = "Select a destination folder"
                openPanel.begin { response in
                    switch response {
                    case .OK:
                        guard let url = openPanel.urls.first else {
                            callback(.failure(.other))
                            return
                        }
                        callback(.success(.init(selectedUrl: url)))
                    case .cancel:
                        callback(.failure(.cancel))
                    default:
                        callback(.failure(.other))
                    }
                }
            }
            
        }
    )
    
    private static func getImageFileNames(directoryUrl: URL) throws -> [String] {
        let imageExtensions: [String] = ["heic", "jpeg", "jpg", "png"]
        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: directoryUrl.path)
        }
        catch {
            throw OpenFolderSelectError.other
        }
        let sortedContents = contents.sorted()
        let filterdContents = sortedContents.filter({
            guard let fileExtension = $0.components(separatedBy: ".").last else { return false }
            return imageExtensions.contains(fileExtension.lowercased())
        })
        return filterdContents
    }
    
    private static func getFirstImage(imageFileNames: [String], directoryUrl: URL) throws -> CGImage {
        guard !imageFileNames.isEmpty else { throw OpenFolderSelectError.noImage }
        for path in imageFileNames {
            if let nsImage = NSImage(contentsOfFile: directoryUrl.path + "/" + path),
               let resizedNsImage = nsImage.resized(maxLength: 500),
               let cgImage = resizedNsImage.cgImage {
                return cgImage
            }
        }
        throw OpenFolderSelectError.noImage
    }
}
