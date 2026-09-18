import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let card = UIView()
    private let iconView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    private var pendingError: Error?
    private var hasAnimatedIn = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        stageInputItems()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedIn else { return }
        hasAnimatedIn = true
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.card.alpha = 1
            self.card.transform = .identity
        }
    }

    private func configureView() {
        view.backgroundColor = .systemGroupedBackground

        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        iconView.isHidden = true

        spinner.startAnimating()

        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.text = String(localized: "Adding to Keepshire")

        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = String(localized: "Preparing your files…")

        var buttonStyle = UIButton.Configuration.filled()
        buttonStyle.title = String(localized: "Done")
        buttonStyle.cornerStyle = .large
        buttonStyle.buttonSize = .large
        dismissButton.configuration = buttonStyle
        dismissButton.titleLabel?.adjustsFontForContentSizeCategory = true
        dismissButton.isHidden = true
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let art = UIView()
        art.translatesAutoresizingMaskIntoConstraints = false
        for subview in [iconView, spinner] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            art.addSubview(subview)
            NSLayoutConstraint.activate([
                subview.centerXAnchor.constraint(equalTo: art.centerXAnchor),
                subview.centerYAnchor.constraint(equalTo: art.centerYAnchor),
            ])
        }
        art.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let stack = UIStackView(arrangedSubviews: [art, titleLabel, messageLabel, dismissButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: art)
        stack.setCustomSpacing(24, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        // A fixed card width keeps the wrapping labels from collapsing to their
        // narrowest fitting width, which would break the message one word per line.
        let cardWidth = card.widthAnchor.constraint(equalToConstant: 320)
        cardWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardWidth,
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            card.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
        ])
    }

    private func show(symbol: String, tint: UIColor, title: String, message: String) {
        spinner.stopAnimating()
        spinner.isHidden = true
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = tint
        iconView.isHidden = false
        titleLabel.text = title
        messageLabel.text = message
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    private func stageInputItems() {
        guard let groupRoot = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.haresh.keepshire"
        ) else {
            finish(error: NSError(
                domain: "KeepshireShare",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(
                    localized: "Keepshire cannot reach its shared storage. This build is missing the App Groups capability."
                )]
            ))
            return
        }

        let session = groupRoot
            .appendingPathComponent("Inbox", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: session,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        } catch {
            finish(error: error)
            return
        }

        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []
        guard !providers.isEmpty else {
            finish(error: NSError(
                domain: "KeepshireShare",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "No supported files were shared.")]
            ))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?
        var copiedCount = 0

        for provider in providers {
            guard let typeIdentifier = preferredTypeIdentifier(for: provider) else { continue }
            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                defer { group.leave() }
                do {
                    if let error { throw error }
                    guard let url else {
                        throw CocoaError(.fileNoSuchFile)
                    }
                    let suggestedName = provider.suggestedName ?? url.lastPathComponent
                    let safeName = (suggestedName as NSString).lastPathComponent
                    let destination = self.uniqueURL(
                        in: session,
                        fileName: safeName.isEmpty ? UUID().uuidString : safeName
                    )
                    try FileManager.default.copyItem(at: url, to: destination)
                    try FileManager.default.setAttributes(
                        [.protectionKey: FileProtectionType.complete],
                        ofItemAtPath: destination.path
                    )
                    lock.lock()
                    copiedCount += 1
                    lock.unlock()
                } catch {
                    lock.lock()
                    firstError = firstError ?? error
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            if copiedCount == 0 {
                try? FileManager.default.removeItem(at: session)
                self.finish(error: firstError ?? CocoaError(.fileReadUnknown))
            } else {
                let title = copiedCount == 1
                    ? String(
                        localized: "1 file ready",
                        comment: "Title shown after the extension stages a single shared file"
                    )
                    : String(
                        localized: "\(copiedCount) files ready",
                        comment: "Title shown after the extension stages several shared files"
                    )
                self.show(
                    symbol: "checkmark.circle.fill",
                    tint: .systemGreen,
                    title: title,
                    message: String(localized: "Open and unlock Keepshire to import them into your vault.")
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        }
    }

    private func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
        provider.registeredTypeIdentifiers.first {
            guard let type = UTType($0) else { return false }
            return type.conforms(to: .image)
                || type.conforms(to: .movie)
                || type.conforms(to: .data)
                || type.conforms(to: .content)
        }
    }

    private func uniqueURL(in directory: URL, fileName: String) -> URL {
        let proposed = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: proposed.path) else { return proposed }
        let base = proposed.deletingPathExtension().lastPathComponent
        let ext = proposed.pathExtension
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        return directory.appendingPathComponent("\(base)-\(UUID().uuidString)\(suffix)")
    }

    /// Shows the failure and waits for a tap. Cancelling straight away makes the share
    /// sheet vanish with no explanation, which is indistinguishable from a crash.
    private func finish(error: Error) {
        pendingError = error
        show(
            symbol: "exclamationmark.triangle.fill",
            tint: .systemOrange,
            title: String(localized: "Couldn’t add these files"),
            message: error.localizedDescription
        )
        dismissButton.isHidden = false
    }

    @objc private func dismissTapped() {
        extensionContext?.cancelRequest(
            withError: pendingError ?? CocoaError(.userCancelled)
        )
    }
}
