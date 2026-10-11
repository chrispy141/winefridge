//
//  CameraCaptureView.swift
//  WineStorage
//

import SwiftUI
import UIKit

/// Wraps `UIImagePickerController` to capture a photo with the device camera,
/// since SwiftUI has no native camera-capture view.
///
/// Uses fully custom controls (`showsCameraControls = false`) rather than
/// Apple's built-in camera chrome: the built-in post-capture "Retake / Use
/// Photo" review screen has no public API to detect or customize, which
/// made it impossible to hide the bottle-shaped framing guide once a photo
/// was taken (it would stay on screen, misaligned with the frozen photo,
/// since the review screen letterboxes the full captured frame differently
/// than the live feed is cropped). Owning the whole flow here means the
/// guide can correctly disappear the moment a photo's captured. The photo
/// is then run through `BottleCutoutService`'s on-device background
/// removal before being handed back.
struct CameraCaptureView: UIViewControllerRepresentable {
    /// Called with the captured photo and whether on-device background
    /// removal succeeded for it. `image` is `nil` if capture was cancelled,
    /// in which case `backgroundRemoved` is meaningless. When removal
    /// didn't succeed (Vision couldn't isolate a subject), `image` is the
    /// original, unmodified photo.
    var onCapture: (_ image: UIImage?, _ backgroundRemoved: Bool) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.showsCameraControls = false
        picker.cameraFlashMode = .off
        picker.delegate = context.coordinator
        let overlay = CameraOverlayView(frame: picker.view.bounds)
        overlay.delegate = context.coordinator
        overlay.setFlipCameraAvailable(UIImagePickerController.isCameraDeviceAvailable(.front))
        overlay.setFlashAvailable(UIImagePickerController.isFlashAvailable(for: picker.cameraDevice))
        picker.cameraOverlayView = overlay
        context.coordinator.picker = picker
        context.coordinator.overlay = overlay
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CameraOverlayViewDelegate {
        let onCapture: (_ image: UIImage?, _ backgroundRemoved: Bool) -> Void
        fileprivate weak var picker: UIImagePickerController?
        fileprivate weak var overlay: CameraOverlayView?

        init(onCapture: @escaping (_ image: UIImage?, _ backgroundRemoved: Bool) -> Void) {
            self.onCapture = onCapture
        }

        // MARK: - CameraOverlayViewDelegate

        func cameraOverlayViewDidTapShutter(_ overlayView: CameraOverlayView) {
            picker?.takePicture()
        }

        func cameraOverlayViewDidTapCancel(_ overlayView: CameraOverlayView) {
            onCapture(nil, false)
        }

        func cameraOverlayViewDidTapRetake(_ overlayView: CameraOverlayView) {
            overlayView.showFraming()
        }

        func cameraOverlayViewDidTapFlipCamera(_ overlayView: CameraOverlayView) {
            guard let picker else { return }
            let nextDevice: UIImagePickerController.CameraDevice = picker.cameraDevice == .rear ? .front : .rear
            guard UIImagePickerController.isCameraDeviceAvailable(nextDevice) else { return }
            picker.cameraDevice = nextDevice
            overlayView.setFlashAvailable(UIImagePickerController.isFlashAvailable(for: nextDevice))
        }

        func cameraOverlayViewDidTapFlash(_ overlayView: CameraOverlayView) {
            guard let picker else { return }
            picker.cameraFlashMode = picker.cameraFlashMode == .off ? .on : .off
            overlayView.setFlashOn(picker.cameraFlashMode == .on)
        }

        func cameraOverlayView(_ overlayView: CameraOverlayView, didConfirmUsing image: UIImage) {
            overlayView.showProcessing()
            Task {
                if let data = try? await BottleCutoutService.generateCutout(from: image), let cutoutImage = UIImage(data: data) {
                    self.onCapture(cutoutImage, true)
                } else {
                    self.onCapture(image, false)
                }
            }
        }

        // MARK: - UIImagePickerControllerDelegate

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCapture(nil, false)
                return
            }
            overlay?.showReview(of: image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil, false)
        }
    }
}

/// What `CameraOverlayView` reports back to its owner — button taps and
/// the final "use this photo" confirmation.
protocol CameraOverlayViewDelegate: AnyObject {
    func cameraOverlayViewDidTapShutter(_ overlayView: CameraOverlayView)
    func cameraOverlayViewDidTapCancel(_ overlayView: CameraOverlayView)
    func cameraOverlayViewDidTapRetake(_ overlayView: CameraOverlayView)
    func cameraOverlayViewDidTapFlipCamera(_ overlayView: CameraOverlayView)
    func cameraOverlayViewDidTapFlash(_ overlayView: CameraOverlayView)
    func cameraOverlayView(_ overlayView: CameraOverlayView, didConfirmUsing image: UIImage)
}

/// The entire custom camera UI, laid over `UIImagePickerController`'s live
/// preview via `cameraOverlayView`. Walks through three states as a person
/// takes a bottle photo:
///
/// - **Framing**: the bottle-shaped guide, a hint label, and shutter /
///   cancel / flip / flash controls, shown over the live feed.
/// - **Reviewing**: once a photo's taken, a static copy of it fills the
///   screen with Retake / Use Photo controls — our own replacement for the
///   native review screen, so unlike that one, the framing guide is simply
///   not part of it.
/// - **Processing**: after "Use Photo", a progress indicator while
///   `BottleCutoutService` removes the background on-device.
final class CameraOverlayView: UIView {
    weak var delegate: CameraOverlayViewDelegate?

    // Framing
    private let bottleImageView = UIImageView(image: UIImage(named: "BottleOutline")?.withRenderingMode(.alwaysTemplate))
    private let hintLabel = InsetLabel()
    private let shutterRing = UIView()
    private let shutterButton = UIButton(type: .custom)
    private let cancelButton = CameraOverlayView.makeIconButton(systemName: "xmark")
    private let flipButton = CameraOverlayView.makeIconButton(systemName: "arrow.triangle.2.circlepath.camera")
    private let flashButton = CameraOverlayView.makeIconButton(systemName: "bolt.slash.fill")

    // Reviewing
    private let reviewImageView = UIImageView()
    private let retakeButton = CameraOverlayView.makeTextButton(title: "Retake")
    private let usePhotoButton = CameraOverlayView.makeTextButton(title: "Use Photo", bold: true)

    // Processing
    private let processingIndicator = UIActivityIndicatorView(style: .large)
    private let processingLabel = InsetLabel()

    private var capturedImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        setUpFramingControls()
        setUpReviewControls()
        setUpProcessingControls()
        showFraming()
    }

    private func setUpFramingControls() {
        bottleImageView.tintColor = .white
        bottleImageView.alpha = 0.5
        bottleImageView.contentMode = .scaleAspectFit
        addSubview(bottleImageView)

        hintLabel.text = "Center the bottle in the outline"
        hintLabel.textColor = .white
        hintLabel.font = .preferredFont(forTextStyle: .footnote)
        hintLabel.textAlignment = .center
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        hintLabel.layer.cornerRadius = 10
        hintLabel.layer.masksToBounds = true
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)

        shutterRing.backgroundColor = .clear
        shutterRing.layer.borderColor = UIColor.white.cgColor
        shutterRing.layer.borderWidth = 4
        shutterRing.layer.cornerRadius = 40
        shutterRing.isUserInteractionEnabled = false
        shutterRing.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shutterRing)

        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 32
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addTarget(self, action: #selector(handleShutterTap), for: .touchUpInside)
        addSubview(shutterButton)

        cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
        flipButton.addTarget(self, action: #selector(handleFlipTap), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(handleFlashTap), for: .touchUpInside)
        addSubview(cancelButton)
        addSubview(flipButton)
        addSubview(flashButton)

        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),

            flashButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            flashButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            shutterRing.widthAnchor.constraint(equalToConstant: 80),
            shutterRing.heightAnchor.constraint(equalToConstant: 80),
            shutterRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            shutterRing.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -36),

            shutterButton.widthAnchor.constraint(equalToConstant: 64),
            shutterButton.heightAnchor.constraint(equalToConstant: 64),
            shutterButton.centerXAnchor.constraint(equalTo: shutterRing.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: shutterRing.centerYAnchor),

            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),

            flipButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            flipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    private func setUpReviewControls() {
        reviewImageView.contentMode = .scaleAspectFit
        reviewImageView.backgroundColor = .black
        reviewImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(reviewImageView)

        retakeButton.addTarget(self, action: #selector(handleRetakeTap), for: .touchUpInside)
        usePhotoButton.addTarget(self, action: #selector(handleUsePhotoTap), for: .touchUpInside)
        addSubview(retakeButton)
        addSubview(usePhotoButton)

        NSLayoutConstraint.activate([
            reviewImageView.topAnchor.constraint(equalTo: topAnchor),
            reviewImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            reviewImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            reviewImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            retakeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            retakeButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -48),

            usePhotoButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            usePhotoButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -48)
        ])
    }

    private func setUpProcessingControls() {
        processingIndicator.color = .white
        processingIndicator.hidesWhenStopped = true
        processingIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(processingIndicator)

        processingLabel.text = "Removing background…"
        processingLabel.textColor = .white
        processingLabel.font = .preferredFont(forTextStyle: .footnote)
        processingLabel.textAlignment = .center
        processingLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        processingLabel.layer.cornerRadius = 10
        processingLabel.layer.masksToBounds = true
        processingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(processingLabel)

        NSLayoutConstraint.activate([
            processingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            processingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            processingLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            processingLabel.topAnchor.constraint(equalTo: processingIndicator.bottomAnchor, constant: 12)
        ])
    }

    // MARK: - State

    func showFraming() {
        capturedImage = nil
        setFramingHidden(false)
        setReviewHidden(true)
        processingIndicator.stopAnimating()
        processingLabel.isHidden = true
    }

    func showReview(of image: UIImage) {
        capturedImage = image
        reviewImageView.image = image
        setFramingHidden(true)
        setReviewHidden(false)
        processingIndicator.stopAnimating()
        processingLabel.isHidden = true
    }

    /// Swaps Retake / Use Photo for a progress indicator once "Use Photo"
    /// is tapped and background removal starts, keeping the captured photo
    /// visible underneath while it runs.
    func showProcessing() {
        retakeButton.isHidden = true
        usePhotoButton.isHidden = true
        processingLabel.isHidden = false
        processingIndicator.startAnimating()
    }

    func setFlipCameraAvailable(_ isAvailable: Bool) {
        flipButton.isHidden = !isAvailable
    }

    func setFlashAvailable(_ isAvailable: Bool) {
        flashButton.isHidden = !isAvailable
    }

    func setFlashOn(_ isOn: Bool) {
        flashButton.setImage(UIImage(systemName: isOn ? "bolt.fill" : "bolt.slash.fill"), for: .normal)
    }

    private func setFramingHidden(_ hidden: Bool) {
        bottleImageView.isHidden = hidden
        hintLabel.isHidden = hidden
        shutterRing.isHidden = hidden
        shutterButton.isHidden = hidden
        cancelButton.isHidden = hidden
        flipButton.isHidden = hidden ? true : flipButton.isHidden
        flashButton.isHidden = hidden ? true : flashButton.isHidden
    }

    private func setReviewHidden(_ hidden: Bool) {
        reviewImageView.isHidden = hidden
        retakeButton.isHidden = hidden
        usePhotoButton.isHidden = hidden
    }

    // MARK: - Actions

    @objc private func handleShutterTap() {
        delegate?.cameraOverlayViewDidTapShutter(self)
    }

    @objc private func handleCancelTap() {
        delegate?.cameraOverlayViewDidTapCancel(self)
    }

    @objc private func handleFlipTap() {
        delegate?.cameraOverlayViewDidTapFlipCamera(self)
    }

    @objc private func handleFlashTap() {
        delegate?.cameraOverlayViewDidTapFlash(self)
    }

    @objc private func handleRetakeTap() {
        delegate?.cameraOverlayViewDidTapRetake(self)
    }

    @objc private func handleUsePhotoTap() {
        guard let capturedImage else { return }
        delegate?.cameraOverlayView(self, didConfirmUsing: capturedImage)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let bottleHeight = bounds.height * 0.845
        let aspectRatio = (bottleImageView.image?.size).map { $0.width / $0.height } ?? 0.5
        let bottleWidth = bottleHeight * aspectRatio
        // Shifted up from dead-center — the live preview has more headroom
        // above center than below, since the bottom of the frame is
        // obstructed by the shutter controls.
        let verticalOffset = bounds.height * 0.03 - bottleHeight * 0.185 - bounds.height * 0.125
        bottleImageView.frame = CGRect(
            x: bounds.midX - bottleWidth / 2,
            y: bounds.midY - bottleHeight / 2 + verticalOffset,
            width: bottleWidth,
            height: bottleHeight
        )
    }

    private static func makeIconButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        return button
    }

    private static func makeTextButton(title: String, bold: Bool = false) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = bold ? .preferredFont(forTextStyle: .headline) : .preferredFont(forTextStyle: .body)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}

/// A `UILabel` with padding around its text, since `UILabel` has none built in.
private final class InsetLabel: UILabel {
    private let insets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
