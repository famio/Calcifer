//
//  FileManagerEffect.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import ComposableArchitecture
import SwiftUI

struct AppFileManager {

    struct OpenFolderSelectResponse: Equatable {
        let directlyUrl: URL
        let imageCount: Int
        let thumbnailImage: CGImage
    }

    enum OpenFolderSelectError: LocalizedError, Equatable {
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

    @MainActor
    static func openFolderSelect() async throws -> OpenFolderSelectResponse {
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

        let response = await openPanel.begin()

        switch response {
        case .OK:
            guard let url = openPanel.urls.first else {
                throw OpenFolderSelectError.other
            }
            do {
                let imageFileNames = try Self.getImageFileNames(directoryUrl: url)
                let image = try Self.getFirstImage(imageFileNames: imageFileNames, directoryUrl: url)
                return .init(directlyUrl: url,
                             imageCount: imageFileNames.count,
                             thumbnailImage: image)
            }
            catch OpenFolderSelectError.noImage {
                throw OpenFolderSelectError.noImage
            }
            catch {
                throw OpenFolderSelectError.other
            }

        case .cancel:
            throw OpenFolderSelectError.cancel

        default:
            throw OpenFolderSelectError.other
        }
    }

    struct OutputFileSelectResponse: Equatable {
        let selectedUrl: URL
    }

    enum OutputFileSelectError: Error, LocalizedError {
        case cancel
        case other

        var errorDescription: String? {
            switch self {
            case .cancel: return "Cancel"
            case .other: return "Error"
            }
        }
    }

    @MainActor
    static func outputFileSelect(directoryUrl: URL, initialFileName: String) async throws -> OutputFileSelectResponse {
        let savePanel = NSSavePanel()
        savePanel.directoryURL = directoryUrl
        savePanel.nameFieldStringValue = initialFileName
        savePanel.allowedContentTypes = [.usdz]
        savePanel.allowsOtherFileTypes = false
        savePanel.canCreateDirectories = true

        let response = await savePanel.begin()
        switch response {
        case .OK:
            guard let url = savePanel.url else {
                assertionFailure()
                throw OutputFileSelectError.other
            }
            return .init(selectedUrl: url)
        case .cancel:
            throw OutputFileSelectError.cancel
        default:
            throw OutputFileSelectError.other
        }
    }

    struct OutputDstSelectResponse: Equatable {
        let selectedUrl: URL
    }

    @MainActor
    static func outputFolderSelect(directoryUrl: URL) async throws -> OutputFileSelectResponse {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = directoryUrl
        openPanel.message = "Select a destination folder"
        let response = await openPanel.begin()
        switch response {
        case .OK:
            guard let url = openPanel.urls.first else {
                throw OutputFileSelectError.other
            }
            return .init(selectedUrl: url)
        case .cancel:
            throw OutputFileSelectError.cancel
        default:
            throw OutputFileSelectError.other
        }
    }

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
