import SwiftUI
import PDFKit
import UIKit

// MARK: - Crop Models

private struct NormalizedRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct CropSettings: Codable, Equatable {
    var visibleRect: NormalizedRect

    static let full = CropSettings(visibleRect: .full)
}

private struct DocumentCropSettings: Codable, Equatable {
    var documentId: String
    var pageSettings: [Int: CropSettings]
    var defaultSettings: CropSettings

    func settings(for pageIndex: Int) -> CropSettings {
        pageSettings[pageIndex] ?? defaultSettings
    }
}

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
    @AppStorage("halfPageModeEnabled") private var halfPageMode = false
    @AppStorage("documentCropSettings") private var cropSettingsData: Data = Data()
    @State private var pdfView: PDFView?
    @State private var pdfDocument: PDFDocument?
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var halfPagePosition = 0
    @State private var performanceMode = false
    @State private var isCropEditing = false
    @State private var editingCropRect: CGRect = CropSettings.full.visibleRect.cgRect
    @State private var isPortrait = true

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack {
                    if halfPageMode {
                        HalfPageView(
                            document: pdfDocument,
                            position: halfPagePosition,
                            totalPages: totalPages
                        )
                        .background(Color(UIColor.systemGray6))
                    } else {
                        SheetMusicContainer(
                            url: url,
                            pdfView: $pdfView,
                            pdfDocument: $pdfDocument,
                            currentPage: $currentPage,
                            totalPages: $totalPages
                        )
                        .background(Color(UIColor.systemGray6))
                    }

                    if !isCropEditing {
                        TapZoneOverlay(
                            onPrevious: goToPreviousPage,
                            onNext: goToNextPage,
                            canGoPrevious: canGoPrevious,
                            canGoNext: canGoNext,
                            backwardZoneRatio: backwardTapZoneRatio,
                            forwardZoneRatio: forwardTapZoneRatio
                        )
                    }

                    if isCropEditing {
                        CropEditorOverlay(
                            rect: $editingCropRect,
                            onApplyToPage: applyCropToCurrentPage,
                            onApplyToAll: applyCropToAllPages,
                            onReset: resetCropForCurrentPage,
                            onCancel: cancelCropEditing
                        )
                    }

                    if performanceMode {
                        PerformanceModeOverlay(
                            backwardZoneRatio: backwardTapZoneRatio,
                            forwardZoneRatio: forwardTapZoneRatio
                        )
                        PerformanceModeIndicator()
                    }
                }

                if !performanceMode {
                    controlBar(isPortrait: isPortrait)
                }
            }
            .onAppear {
                isPortrait = geometry.size.height >= geometry.size.width
            }
            .onChange(of: geometry.size) { newSize in
                let newIsPortrait = newSize.height >= newSize.width
                if newIsPortrait != isPortrait {
                    isPortrait = newIsPortrait
                }
            }
        }
        .onTapGesture(count: 3) {
            if performanceMode {
                exitPerformanceMode()
            }
        }
        .onChange(of: isPortrait) { newValue in
            if !newValue && halfPageMode {
                disableHalfPageMode()
            }
        }
        .onChange(of: performanceMode) { newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .onChange(of: pdfDocument) { _ in
            applyStoredCropSettings()
        }
        .onChange(of: totalPages) { _ in
            halfPagePosition = min(halfPagePosition, maxHalfPagePosition)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Control Bar

    private func controlBar(isPortrait: Bool) -> some View {
        HStack(spacing: 16) {
            pageNavigationControls
            Divider().frame(height: 20)
            modeControls(isPortrait: isPortrait)

            if !halfPageMode {
                Divider().frame(height: 20)
                zoomControls
            }
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
            .disabled(!canGoPrevious)

            Text(pageIndicatorText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .frame(minWidth: 60)

            Button {
                goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
            }
            .disabled(!canGoNext)
        }
    }

    private func modeControls(isPortrait: Bool) -> some View {
        HStack(spacing: 12) {
            if isPortrait {
                Button {
                    toggleHalfPageMode()
                } label: {
                    Image(systemName: halfPageMode ? "rectangle.split.1x2.fill" : "rectangle.split.1x2")
                        .font(.system(size: 18))
                }
            }

            Button {
                beginCropEditing()
            } label: {
                Image(systemName: "crop")
                    .font(.system(size: 18))
            }
            .disabled(performanceMode)

            Button {
                enterPerformanceMode()
            } label: {
                Image(systemName: "lock")
                    .font(.system(size: 18))
            }
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
        if halfPageMode {
            halfPagePosition = max(0, halfPagePosition - 1)
            syncCurrentPageFromHalfPosition()
            return
        }

        guard let pdfView = pdfView, pdfView.canGoToPreviousPage else { return }
        pdfView.goToPreviousPage(nil)
    }

    private func goToNextPage() {
        if halfPageMode {
            halfPagePosition = min(maxHalfPagePosition, halfPagePosition + 1)
            syncCurrentPageFromHalfPosition()
            return
        }

        guard let pdfView = pdfView, pdfView.canGoToNextPage else { return }
        pdfView.goToNextPage(nil)
    }

    // MARK: - Zoom Actions

    private func zoomIn() {
        guard let pdfView = pdfView else { return }
        let newScale = min(pdfView.scaleFactor * 1.25, pdfView.maxScaleFactor)
        pdfView.scaleFactor = newScale
    }

    private func zoomOut() {
        guard let pdfView = pdfView else { return }
        let newScale = max(pdfView.scaleFactor / 1.25, pdfView.minScaleFactor)
        pdfView.scaleFactor = newScale
    }

    private func fitToWidth() {
        guard let pdfView = pdfView else { return }
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
    }

    // MARK: - Mode State

    private var canGoPrevious: Bool {
        halfPageMode ? halfPagePosition > 0 : currentPage > 1
    }

    private var canGoNext: Bool {
        halfPageMode ? halfPagePosition < maxHalfPagePosition : currentPage < totalPages
    }

    private var maxHalfPagePosition: Int {
        max(0, 2 * totalPages - 2)
    }

    private var pageIndicatorText: String {
        guard totalPages > 0 else { return "0 / 0" }

        if halfPageMode {
            let bottomPage = (halfPagePosition / 2) + 1
            let topPage = (halfPagePosition / 2) + (halfPagePosition % 2 == 0 ? 0 : 1) + 1
            if bottomPage == topPage || halfPagePosition == 0 || halfPagePosition == maxHalfPagePosition {
                return "\(bottomPage) / \(totalPages)"
            }
            return "\(bottomPage)-\(topPage) / \(totalPages)"
        }

        return "\(currentPage) / \(totalPages)"
    }

    private var backwardTapZoneRatio: CGFloat {
        performanceMode ? 0.33 : 0.2
    }

    private var forwardTapZoneRatio: CGFloat {
        performanceMode ? 0.67 : 0.2
    }

    private func toggleHalfPageMode() {
        if halfPageMode {
            disableHalfPageMode()
        } else {
            enableHalfPageMode()
        }
    }

    private func enableHalfPageMode() {
        halfPageMode = true
        halfPagePosition = max(0, (currentPage - 1) * 2)
    }

    private func disableHalfPageMode() {
        halfPageMode = false
        syncCurrentPageFromHalfPosition()
        if let page = pdfDocument?.page(at: currentPage - 1) {
            pdfView?.go(to: page)
        }
    }

    private func syncCurrentPageFromHalfPosition() {
        currentPage = min(totalPages, max(1, (halfPagePosition / 2) + 1))
    }

    // MARK: - Performance Mode

    private func enterPerformanceMode() {
        performanceMode = true
    }

    private func exitPerformanceMode() {
        performanceMode = false
    }

    // MARK: - Crop Editing

    private var documentId: String {
        url.absoluteString
    }

    private var currentDocumentCropSettings: DocumentCropSettings {
        loadCropSettings()[documentId] ?? DocumentCropSettings(
            documentId: documentId,
            pageSettings: [:],
            defaultSettings: .full
        )
    }

    private func beginCropEditing() {
        if performanceMode {
            return
        }

        if halfPageMode {
            disableHalfPageMode()
        }

        editingCropRect = currentDocumentCropSettings.settings(for: currentPage - 1).visibleRect.cgRect
        isCropEditing = true
    }

    private func cancelCropEditing() {
        editingCropRect = currentDocumentCropSettings.settings(for: currentPage - 1).visibleRect.cgRect
        isCropEditing = false
    }

    private func applyCropToCurrentPage() {
        let cropSettings = CropSettings(visibleRect: NormalizedRect(editingCropRect))
        var documentSettings = currentDocumentCropSettings
        documentSettings.pageSettings[currentPage - 1] = cropSettings
        saveCropSettings(documentSettings)
        applyCropSettingsToDocument(documentSettings, pageIndex: currentPage - 1)
        isCropEditing = false
    }

    private func applyCropToAllPages() {
        let cropSettings = CropSettings(visibleRect: NormalizedRect(editingCropRect))
        var documentSettings = currentDocumentCropSettings
        documentSettings.defaultSettings = cropSettings
        documentSettings.pageSettings.removeAll()
        saveCropSettings(documentSettings)
        applyCropSettingsToDocument(documentSettings, pageIndex: nil)
        isCropEditing = false
    }

    private func resetCropForCurrentPage() {
        var documentSettings = currentDocumentCropSettings
        documentSettings.pageSettings.removeValue(forKey: currentPage - 1)
        saveCropSettings(documentSettings)
        applyCropSettingsToDocument(documentSettings, pageIndex: currentPage - 1)
        editingCropRect = documentSettings.settings(for: currentPage - 1).visibleRect.cgRect
    }

    private func applyStoredCropSettings() {
        applyCropSettingsToDocument(currentDocumentCropSettings, pageIndex: nil)
    }

    private func loadCropSettings() -> [String: DocumentCropSettings] {
        guard !cropSettingsData.isEmpty else { return [:] }
        do {
            return try JSONDecoder().decode([String: DocumentCropSettings].self, from: cropSettingsData)
        } catch {
            return [:]
        }
    }

    private func saveCropSettings(_ settings: DocumentCropSettings) {
        var allSettings = loadCropSettings()
        allSettings[documentId] = settings
        do {
            cropSettingsData = try JSONEncoder().encode(allSettings)
        } catch {
            cropSettingsData = Data()
        }
    }

    private func applyCropSettingsToDocument(_ settings: DocumentCropSettings, pageIndex: Int?) {
        guard let document = pdfDocument else { return }
        if let pageIndex {
            guard let page = document.page(at: pageIndex) else { return }
            applyCrop(settings.settings(for: pageIndex), to: page)
            return
        }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            applyCrop(settings.settings(for: index), to: page)
        }
    }

    private func applyCrop(_ settings: CropSettings, to page: PDFPage) {
        let mediaBox = page.bounds(for: .mediaBox)
        let rect = settings.visibleRect.cgRect
        let cropRect = CGRect(
            x: mediaBox.minX + rect.origin.x * mediaBox.width,
            y: mediaBox.minY + (1 - rect.origin.y - rect.height) * mediaBox.height,
            width: rect.width * mediaBox.width,
            height: rect.height * mediaBox.height
        )
        page.setBounds(cropRect, for: .cropBox)
    }
}

// MARK: - Tap Zone Overlay

private struct TapZoneOverlay: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    let canGoPrevious: Bool
    let canGoNext: Bool
    let backwardZoneRatio: CGFloat
    let forwardZoneRatio: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let backwardWidth = geometry.size.width * backwardZoneRatio
            let forwardWidth = geometry.size.width * forwardZoneRatio
            HStack(spacing: 0) {
                TapZone(icon: "chevron.left", enabled: canGoPrevious, action: onPrevious)
                    .frame(width: backwardWidth)
                Spacer()
                TapZone(icon: "chevron.right", enabled: canGoNext, action: onNext)
                    .frame(width: forwardWidth)
            }
        }
    }
}

private struct TapZone: View {
    let icon: String
    let enabled: Bool
    let action: () -> Void

    @State private var showFeedback = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                guard enabled else { return }
                showFeedback = true
                action()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showFeedback = false
                }
            }
            .overlay {
                if showFeedback {
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.primary.opacity(0.3))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showFeedback)
    }
}

// MARK: - Half Page View

private enum PageHalf {
    case top
    case bottom
}

private struct HalfPageView: View {
    let document: PDFDocument?
    let position: Int
    let totalPages: Int

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                if let bottomImage = renderBottomHalf(for: position, size: geo.size) {
                    Image(uiImage: bottomImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: isFullPagePosition ? .infinity : geo.size.height / 2)
                }

                if !isFullPagePosition, let topImage = renderTopHalf(for: position, size: geo.size) {
                    Divider()
                    Image(uiImage: topImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: geo.size.height / 2)
                }
            }
        }
        .background(Color(UIColor.systemGray6))
    }

    private var isFullPagePosition: Bool {
        position == 0 || position == max(0, 2 * totalPages - 2)
    }

    private func renderBottomHalf(for position: Int, size: CGSize) -> UIImage? {
        let pageIndex = position / 2
        guard let page = document?.page(at: pageIndex) else { return nil }
        if isFullPagePosition {
            return renderPage(page, size: size)
        }
        return renderPage(page, half: .bottom, size: size)
    }

    private func renderTopHalf(for position: Int, size: CGSize) -> UIImage? {
        let pageIndex = (position / 2) + 1
        guard let page = document?.page(at: pageIndex) else { return nil }
        return renderPage(page, half: .top, size: size)
    }

    private func renderPage(_ page: PDFPage, size: CGSize) -> UIImage? {
        let renderSize = CGSize(width: size.width * 2, height: size.height * 2)
        return page.thumbnail(of: renderSize, for: .cropBox)
    }

    private func renderPage(_ page: PDFPage, half: PageHalf, size: CGSize) -> UIImage? {
        let renderSize = CGSize(width: size.width * 2, height: size.height * 4)
        let fullImage = page.thumbnail(of: renderSize, for: .cropBox)
        guard let cgImage = fullImage.cgImage else { return nil }

        let cropRect: CGRect
        switch half {
        case .top:
            cropRect = CGRect(x: 0, y: 0, width: fullImage.size.width, height: fullImage.size.height / 2)
        case .bottom:
            cropRect = CGRect(
                x: 0,
                y: fullImage.size.height / 2,
                width: fullImage.size.width,
                height: fullImage.size.height / 2
            )
        }

        guard let halfImage = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: halfImage, scale: fullImage.scale, orientation: fullImage.imageOrientation)
    }
}

// MARK: - Crop Editor

private enum CropHandleType: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case top
    case bottom
    case left
    case right
}

private struct CropEditorOverlay: View {
    @Binding var rect: CGRect
    let onApplyToPage: () -> Void
    let onApplyToAll: () -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DimmingMask(rect: rect, size: geo.size)
                CropRectangle(rect: $rect, size: geo.size)
                VStack {
                    Spacer()
                    CropActionBar(
                        onApplyToPage: onApplyToPage,
                        onApplyToAll: onApplyToAll,
                        onReset: onReset,
                        onCancel: onCancel
                    )
                }
            }
        }
        .background(Color.black.opacity(0.001))
    }
}

private struct DimmingMask: View {
    let rect: CGRect
    let size: CGSize

    var body: some View {
        let holeRect = CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.size.width * size.width,
            height: rect.size.height * size.height
        )

        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(holeRect)
        }
        .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
    }
}

private struct CropRectangle: View {
    @Binding var rect: CGRect
    let size: CGSize
    @State private var dragStartRect: CGRect = .zero
    @State private var activeHandle: CropHandleType?

    var body: some View {
        let actualRect = CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.size.width * size.width,
            height: rect.size.height * size.height
        )

        ZStack {
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: actualRect.width, height: actualRect.height)
                .position(x: actualRect.midX, y: actualRect.midY)

            ForEach(CropHandleType.allCases, id: \.self) { handle in
                CropHandle()
                    .position(position(for: handle, in: actualRect))
                    .gesture(dragGesture(for: handle))
            }
        }
    }

    private func position(for handle: CropHandleType, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .left:
            return CGPoint(x: rect.minX, y: rect.midY)
        case .right:
            return CGPoint(x: rect.maxX, y: rect.midY)
        }
    }

    private func dragGesture(for handle: CropHandleType) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeHandle != handle {
                    activeHandle = handle
                    dragStartRect = rect
                }

                let delta = CGSize(
                    width: value.translation.width / size.width,
                    height: value.translation.height / size.height
                )
                rect = adjustedRect(startRect: dragStartRect, handle: handle, delta: delta)
            }
            .onEnded { _ in
                activeHandle = nil
            }
    }

    private func adjustedRect(startRect: CGRect, handle: CropHandleType, delta: CGSize) -> CGRect {
        let minSize: CGFloat = 0.05
        var x = startRect.origin.x
        var y = startRect.origin.y
        var width = startRect.size.width
        var height = startRect.size.height

        switch handle {
        case .topLeft:
            x = startRect.origin.x + delta.width
            y = startRect.origin.y + delta.height
            width = startRect.maxX - x
            height = startRect.maxY - y
        case .topRight:
            y = startRect.origin.y + delta.height
            width = startRect.size.width + delta.width
            height = startRect.maxY - y
        case .bottomLeft:
            x = startRect.origin.x + delta.width
            width = startRect.maxX - x
            height = startRect.size.height + delta.height
        case .bottomRight:
            width = startRect.size.width + delta.width
            height = startRect.size.height + delta.height
        case .top:
            y = startRect.origin.y + delta.height
            height = startRect.maxY - y
        case .bottom:
            height = startRect.size.height + delta.height
        case .left:
            x = startRect.origin.x + delta.width
            width = startRect.maxX - x
        case .right:
            width = startRect.size.width + delta.width
        }

        width = max(minSize, width)
        height = max(minSize, height)

        if x < 0 {
            width += x
            x = 0
        }

        if y < 0 {
            height += y
            y = 0
        }

        if x + width > 1 {
            width = 1 - x
        }

        if y + height > 1 {
            height = 1 - y
        }

        if width < minSize {
            width = minSize
            x = min(x, 1 - minSize)
        }

        if height < minSize {
            height = minSize
            y = min(y, 1 - minSize)
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct CropHandle: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 18, height: 18)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct CropActionBar: View {
    let onApplyToPage: () -> Void
    let onApplyToAll: () -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                onCancel()
            }
            Spacer()
            Button("Reset") {
                onReset()
            }
            Button("Apply to Page") {
                onApplyToPage()
            }
            .buttonStyle(.borderedProminent)
            Button("Apply to All") {
                onApplyToAll()
            }
            .buttonStyle(.bordered)
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Performance Mode Overlay

private struct PerformanceModeOverlay: View {
    let backwardZoneRatio: CGFloat
    let forwardZoneRatio: CGFloat

    var body: some View {
        GeometryReader { geo in
            let backwardWidth = geo.size.width * backwardZoneRatio
            let forwardWidth = geo.size.width * forwardZoneRatio
            let blockedWidth = max(0, geo.size.width - backwardWidth - forwardWidth)

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: backwardWidth)
                    .allowsHitTesting(false)

                Color.clear
                    .frame(width: blockedWidth)
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    .gesture(DragGesture().onChanged { _ in })
                    .gesture(MagnificationGesture().onChanged { _ in })

                Color.clear
                    .frame(width: forwardWidth)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct PerformanceModeIndicator: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.3))
                    .padding(8)
            }
            Spacer()
        }
    }
}

// MARK: - PDF Container

struct SheetMusicContainer: UIViewRepresentable {
    let url: URL
    @Binding var pdfView: PDFView?
    @Binding var pdfDocument: PDFDocument?
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displayBox = .cropBox
        view.usePageViewController(true, withViewOptions: nil)
        view.minScaleFactor = view.scaleFactorForSizeToFit
        view.maxScaleFactor = 4.0

        if let document = PDFDocument(url: url) {
            view.document = document
            DispatchQueue.main.async {
                self.pdfView = view
                self.pdfDocument = document
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

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(
            coordinator,
            name: .PDFViewPageChanged,
            object: uiView
        )
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
