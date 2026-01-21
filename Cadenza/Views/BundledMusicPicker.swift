import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.loopflow.cadenza", category: "ui")

struct BundledMusicPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    let authService: AuthService

    @State private var searchText = ""
    @State private var showingDocumentPicker = false
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundStyle(.tint)
                            Text("Import from Files")
                                .font(.headline)
                            Spacer()
                            if isUploading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isUploading)
                } header: {
                    Text("Your PDFs")
                } footer: {
                    if let error = uploadError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section("Included Sheet Music") {
                    ForEach(filteredFiles, id: \.path) { file in
                        Button {
                            importBundledFile(file)
                        } label: {
                            HStack {
                                Text(formatTitle(from: file.name))
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search sheet music")
            .navigationTitle("Add Sheet Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUploading)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(onPick: importUserPDF)
            }
        }
    }

    // MARK: - File Discovery

    private var bundledFiles: [(path: String, name: String)] {
        var files: [(path: String, name: String)] = []

        guard let resourcePath = Bundle.main.resourcePath else {
            return files
        }

        guard let enumerator = FileManager.default.enumerator(atPath: resourcePath) else {
            return files
        }

        while let element = enumerator.nextObject() as? String {
            if element.hasSuffix(".pdf") {
                let filename = (element as NSString).lastPathComponent
                files.append((path: element, name: filename))
            }
        }

        return files.sorted { $0.name < $1.name }
    }

    private var filteredFiles: [(path: String, name: String)] {
        bundledFiles.filter { file in
            searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Title Formatting

    private func formatTitle(from filename: String) -> String {
        var title = filename
            .replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        title = title.split(separator: " ")
            .map { word in
                let str = String(word)
                // Keep common music abbreviations as-is
                if ["op", "no", "bwv", "k", "d", "hob", "rv"].contains(str.lowercased()) {
                    return str.lowercased()
                }
                return str.prefix(1).uppercased() + str.dropFirst().lowercased()
            }
            .joined(separator: " ")

        title = title
            .replacingOccurrences(of: " In ", with: " in ")
            .replacingOccurrences(of: " Of ", with: " of ")
            .replacingOccurrences(of: " The ", with: " the ")
            .replacingOccurrences(of: " And ", with: " and ")
            .replacingOccurrences(of: " For ", with: " for ")
            .replacingOccurrences(of: " A ", with: " a ")

        if !title.isEmpty {
            title = title.prefix(1).uppercased() + title.dropFirst()
        }

        return title
    }

    // MARK: - Import Actions

    private func importBundledFile(_ file: (path: String, name: String)) {
        guard let resourcePath = Bundle.main.resourcePath,
              let userId = authService.currentUser?.id else {
            return
        }

        let sourceURL = URL(fileURLWithPath: resourcePath).appendingPathComponent(file.path)

        do {
            // Read PDF data from bundle
            let pdfData = try Data(contentsOf: sourceURL)

            // Copy to documents directory for local access
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsURL.appendingPathComponent(file.name)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            let title = formatTitle(from: file.name)

            // Upload to server with PDF file data
            if let tokenData = KeychainHelper.load(key: "jwt_token"),
               let token = String(data: tokenData, encoding: .utf8) {
                let repository = PieceRepository(modelContext: modelContext)
                Task { @MainActor in
                    do {
                        logger.info("Creating piece '\(title)' on server...")
                        // Server generates UUID and creates piece
                        let pieceDTO = try await repository.createPieceWithUpload(
                            title: title,
                            pdfData: pdfData,
                            pdfFilename: file.name,
                            ownerId: userId,
                            token: token
                        )

                        logger.debug("Server returned piece \(pieceDTO.id), saving to SwiftData...")
                        // Create local piece with server's UUID
                        let piece = pieceDTO.toPiece()
                        modelContext.insert(piece)
                        try modelContext.save()
                        logger.info("Successfully saved piece '\(title)' to SwiftData")
                        dismiss()
                    } catch {
                        logger.error("Failed to create piece: \(error)")
                        dismiss()
                    }
                }
            } else {
                dismiss()
            }

        } catch {
            logger.error("Failed to import bundled PDF: \(error)")
        }
    }

    private func importUserPDF(url: URL) {
        guard let userId = authService.currentUser?.id else {
            uploadError = "Not signed in"
            return
        }

        isUploading = true
        uploadError = nil

        Task { @MainActor in
            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    uploadError = "Cannot access file"
                    isUploading = false
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                // Read PDF data
                let pdfData = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                let title = formatTitle(from: filename)

                // Copy to documents directory for local access
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsURL.appendingPathComponent(filename)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try pdfData.write(to: destinationURL)

                // Upload to server
                guard let tokenData = KeychainHelper.load(key: "jwt_token"),
                      let token = String(data: tokenData, encoding: .utf8) else {
                    uploadError = "Not authenticated"
                    isUploading = false
                    return
                }

                let repository = PieceRepository(modelContext: modelContext)
                logger.info("Uploading user PDF '\(title)' to server...")

                let pieceDTO = try await repository.createPieceWithUpload(
                    title: title,
                    pdfData: pdfData,
                    pdfFilename: filename,
                    ownerId: userId,
                    token: token
                )

                logger.debug("Server returned piece \(pieceDTO.id), saving to SwiftData...")
                let piece = pieceDTO.toPiece()
                modelContext.insert(piece)
                try modelContext.save()
                logger.info("Successfully saved user PDF '\(title)' to SwiftData")

                isUploading = false
                dismiss()

            } catch {
                logger.error("Failed to import user PDF: \(error)")
                uploadError = "Failed to upload: \(error.localizedDescription)"
                isUploading = false
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
