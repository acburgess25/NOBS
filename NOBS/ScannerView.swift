import SwiftUI
import VisionKit

struct ScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let viewController = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: ScannerView
        var didScan = false

        init(_ parent: ScannerView) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handleItem(item)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            if let item = addedItems.first {
                handleItem(item)
            }
        }
        
        private func handleItem(_ item: RecognizedItem) {
            guard !didScan else { return }
            switch item {
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    didScan = true
                    parent.onScan(payload)
                }
            default:
                break
            }
        }

        func dataScannerDidCancel(_ dataScanner: DataScannerViewController) {
            parent.onCancel()
        }
    }
}
