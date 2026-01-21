import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.loopflow.cadenza", category: "ui")

struct PiecesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Piece.createdAt, order: .reverse) private var pieces: [Piece]
    let authService: AuthService

    @State private var showingBundledPicker = false
    @State private var editingPiece: Piece?
    @State private var editedTitle = ""
    @State private var isSyncing = false
    @State private var errorMessage: String?

    private var repository: PieceRepository {
        PieceRepository(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            List {
                if pieces.isEmpty {
                    emptyState
                        .onAppear {
                            logger.info("PiecesView: SwiftData @Query returned 0 pieces")
                            // Check what's actually in the context
                            let descriptor = FetchDescriptor<Piece>()
                            if let allPieces = try? modelContext.fetch(descriptor) {
                                logger.info("PiecesView: Manual fetch found \(allPieces.count) pieces in SwiftData")
                                for p in allPieces {
                                    logger.debug("  - \(p.id): '\(p.title)' owner=\(p.ownerId)")
                                }
                            }
                        }
                } else {
                    piecesList
                        .onAppear {
                            logger.info("PiecesView: SwiftData has \(pieces.count) pieces")
                            for piece in pieces {
                                logger.debug("  - \(piece.id): '\(piece.title)' (file: \(piece.pdfFilename ?? "nil"))")
                            }
                        }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Sheet Music")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBundledPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if isSyncing {
                        ProgressView()
                    } else if !pieces.isEmpty {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingBundledPicker) {
                BundledMusicPicker(isPresented: $showingBundledPicker, authService: authService)
            }
            .alert("Rename Piece", isPresented: .constant(editingPiece != nil), presenting: editingPiece) { piece in
                TextField("Title", text: $editedTitle)
                Button("Cancel", role: .cancel) {
                    editingPiece = nil
                }
                Button("Save") {
                    renamePiece(piece)
                }
            } message: { _ in
                Text("Enter a new title for this piece")
            }
            .task {
                await syncWithServer()
            }
            .refreshable {
                await syncWithServer()
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Sheet Music", systemImage: "doc.text")
        } description: {
            Text("Import sheet music from the included library")
        } actions: {
            Button("Add Sheet Music") {
                showingBundledPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var piecesList: some View {
        ForEach(pieces) { piece in
            NavigationLink {
                if let url = piece.pdfURL {
                    EnhancedSheetMusicViewer(url: url)
                        .navigationTitle(piece.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            } label: {
                PieceRowView(piece: piece)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deletePiece(piece)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    editingPiece = piece
                    editedTitle = piece.title
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .onDelete(perform: deletePieces)
    }

    // MARK: - Actions

    private func syncWithServer() async {
        guard let token = getToken() else {
            return
        }

        isSyncing = true
        errorMessage = nil

        do {
            try await repository.syncFromServer(token: token)
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    private func renamePiece(_ piece: Piece) {
        let newTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else {
            editingPiece = nil
            return
        }

        piece.title = newTitle
        piece.updatedAt = Date()
        try? modelContext.save()

        // Sync with server in background
        if let token = getToken() {
            Task {
                do {
                    try await repository.updatePiece(piece, token: token)
                } catch {
                    errorMessage = "Failed to sync rename: \(error.localizedDescription)"
                }
            }
        }

        editingPiece = nil
    }

    private func deletePiece(_ piece: Piece) {
        // Delete PDF file
        if let filename = piece.pdfFilename {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Sync deletion with server
        if let token = getToken() {
            Task {
                do {
                    try await repository.deletePiece(piece, token: token)
                } catch {
                    errorMessage = "Failed to sync deletion: \(error.localizedDescription)"
                }
            }
        } else {
            // Delete locally if offline
            modelContext.delete(piece)
        }
    }

    private func deletePieces(offsets: IndexSet) {
        for index in offsets {
            deletePiece(pieces[index])
        }
    }

    private func getToken() -> String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}

// MARK: - Row View

struct PieceRowView: View {
    let piece: Piece

    var body: some View {
        HStack {
            Text(piece.title)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
