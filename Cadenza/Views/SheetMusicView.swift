import SwiftUI
import PDFKit

// MARK: - Basic PDF View

struct SheetMusicView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true, withViewOptions: nil)

        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0

        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }

        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.pageShadowsEnabled = true

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil, let document = PDFDocument(url: url) {
            uiView.document = document
        }
    }
}

// MARK: - Enhanced PDF Viewer with Controls

struct EnhancedSheetMusicViewer: View {
    let url: URL
    @State private var pdfView: PDFView?
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var zoomScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                SheetMusicContainer(
                    url: url,
                    pdfView: $pdfView,
                    currentPage: $currentPage,
                    totalPages: $totalPages
                )
                .background(Color(UIColor.systemGray6))

                TapZoneOverlay(
                    onPrevious: goToPreviousPage,
                    onNext: goToNextPage,
                    canGoPrevious: currentPage > 1,
                    canGoNext: currentPage < totalPages
                )
            }

            controlBar
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 20) {
            pageNavigationControls
            Divider().frame(height: 20)
            zoomControls
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private var pageNavigationControls: some View {
        HStack(spacing: 12) {
            Button {
                goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18))
            }
            .disabled(currentPage <= 1)

            Text("\(currentPage) / \(totalPages)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .frame(minWidth: 60)

            Button {
                goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
            }
            .disabled(currentPage >= totalPages)
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 12) {
            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 18))
            }

            Button {
                fitToWidth()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16))
            }

            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 18))
            }
        }
    }

    // MARK: - Navigation Actions

    private func goToPreviousPage() {
        guard let pdfView = pdfView, pdfView.canGoToPreviousPage else { return }
        pdfView.goToPreviousPage(nil)
    }

    private func goToNextPage() {
        guard let pdfView = pdfView, pdfView.canGoToNextPage else { return }
        pdfView.goToNextPage(nil)
    }

    // MARK: - Zoom Actions

    private func zoomIn() {
        guard let pdfView = pdfView else { return }
        let newScale = min(pdfView.scaleFactor * 1.25, pdfView.maxScaleFactor)
        pdfView.scaleFactor = newScale
        zoomScale = newScale
    }

    private func zoomOut() {
        guard let pdfView = pdfView else { return }
        let newScale = max(pdfView.scaleFactor / 1.25, pdfView.minScaleFactor)
        pdfView.scaleFactor = newScale
        zoomScale = newScale
    }

    private func fitToWidth() {
        guard let pdfView = pdfView else { return }
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        zoomScale = pdfView.scaleFactor
    }
}

// MARK: - Tap Zone Overlay

private struct TapZoneOverlay: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    let canGoPrevious: Bool
    let canGoNext: Bool

    @State private var showLeftFeedback = false
    @State private var showRightFeedback = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left zone (20%)
                tapZone(
                    width: geometry.size.width * 0.2,
                    showFeedback: showLeftFeedback,
                    direction: .left
                ) {
                    if canGoPrevious {
                        showLeftFeedback = true
                        onPrevious()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showLeftFeedback = false
                        }
                    }
                }

                // Center area (60%) - passthrough
                Color.clear
                    .frame(width: geometry.size.width * 0.6)
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)

                // Right zone (20%)
                tapZone(
                    width: geometry.size.width * 0.2,
                    showFeedback: showRightFeedback,
                    direction: .right
                ) {
                    if canGoNext {
                        showRightFeedback = true
                        onNext()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showRightFeedback = false
                        }
                    }
                }
            }
        }
    }

    private enum Direction { case left, right }

    @ViewBuilder
    private func tapZone(
        width: CGFloat,
        showFeedback: Bool,
        direction: Direction,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: action)

            if showFeedback {
                Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.primary.opacity(0.3))
                    .transition(.opacity)
            }
        }
        .frame(width: width)
        .animation(.easeOut(duration: 0.15), value: showFeedback)
    }
}

// MARK: - PDF Container

struct SheetMusicContainer: UIViewRepresentable {
    let url: URL
    @Binding var pdfView: PDFView?
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical

        if let document = PDFDocument(url: url) {
            view.document = document
            DispatchQueue.main.async {
                self.pdfView = view
                self.totalPages = document.pageCount
                self.currentPage = 1
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view
        )

        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: SheetMusicContainer

        init(_ parent: SheetMusicContainer) {
            self.parent = parent
        }

        @MainActor
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: currentPage)
            self.parent.currentPage = pageIndex + 1
        }
    }
}
