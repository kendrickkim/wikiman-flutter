import Social
import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    private var appGroupId: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String {
            return id
        }
        return "group.\(Bundle.main.bundleIdentifier ?? "")"
    }

    private var isProcessing = false
    private var didClose = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📱 [BidirectionalShareExt] viewDidLoad called")
        
        // Hide the UI to make it seamless
        self.view.isHidden = true
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Process the shared content and navigate to main app
        DispatchQueue.main.async {
            self.handleSharedContent()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("📱 [BidirectionalShareExt] viewDidAppear called")

        // Completing the request tears the extension down, so it waits for the
        // attachments to be copied out. The timeout only guards a stuck load.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self, !self.didClose else { return }
            print("⏱️ [BidirectionalShareExt] Timed out waiting for attachments")
            self.closeShareExtension()
        }
    }
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        print("📱 [BidirectionalShareExt] didSelectPost called")
        handleSharedContent()
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
    
    private func handleSharedContent() {
        guard !isProcessing else {
            print("📱 [BidirectionalShareExt] Already processing, ignoring")
            return
        }
        isProcessing = true

        guard let extensionContext = extensionContext else {
            print("❌ [BidirectionalShareExt] No extension context")
            closeShareExtension()
            return
        }
        
        print("🔍 [BidirectionalShareExt] Starting to process shared content")
        let inputItems = extensionContext.inputItems
        print("📦 [BidirectionalShareExt] Total input items: \(inputItems.count)")
        
        // Log detailed information about what iOS is sending
        for (itemIndex, inputItem) in inputItems.enumerated() {
            guard let item = inputItem as? NSExtensionItem else { 
                print("⚠️ [BidirectionalShareExt] Item \(itemIndex) is not NSExtensionItem")
                continue 
            }
            
            print("📝 [BidirectionalShareExt] Input Item \(itemIndex):")
            print("   - Title: \(item.attributedTitle?.string ?? "nil")")
            print("   - Content: \(item.attributedContentText?.string ?? "nil")")
            print("   - Attachments count: \(item.attachments?.count ?? 0)")
            
            if let attachments = item.attachments {
                for (attachmentIndex, attachment) in attachments.enumerated() {
                    print("📎 [BidirectionalShareExt] Attachment \(attachmentIndex):")
                    print("     Registered types: \(attachment.registeredTypeIdentifiers)")
                }
            }
        }
        
        let attachments = extensionContext.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
        
        print("🔄 [BidirectionalShareExt] Flattened attachments count: \(attachments.count)")
        
        if attachments.isEmpty {
            print("❌ [BidirectionalShareExt] No attachments to process")
            closeShareExtension()
            return
        }
        
        var shareData: [String: Any] = [:]
        var allFilePaths: [String] = []  // 🔥 KEY FIX: Use array to collect ALL files
        var allTextContent: [String] = []
        let group = DispatchGroup()

        // Attachments load on arbitrary threads, so collection is serialised.
        let lock = NSLock()
        let appendPath: (String) -> Void = { path in
            lock.lock()
            allFilePaths.append(path)
            lock.unlock()
        }
        let appendText: (String) -> Void = { text in
            lock.lock()
            allTextContent.append(text)
            lock.unlock()
        }
        
        for (attachmentIndex, attachment) in attachments.enumerated() {
            print("🔄 [BidirectionalShareExt] Processing attachment \(attachmentIndex)")
            group.enter()
            
            // Process files first (prioritize files over text/URLs)
            if attachment.hasItemConformingToTypeIdentifier("public.file-url") {
                print("📁 [BidirectionalShareExt] Processing file URL attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (item, error) in
                    self?.processFileItem(item: item, error: error, index: attachmentIndex, append: appendPath)
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier("public.image") {
                print("🖼️ [BidirectionalShareExt] Processing image attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "public.image", options: nil) { [weak self] (item, error) in
                    self?.processFileItem(item: item, error: error, index: attachmentIndex, append: appendPath)
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier("public.movie") {
                print("🎬 [BidirectionalShareExt] Processing video attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "public.movie", options: nil) { [weak self] (item, error) in
                    self?.processFileItem(item: item, error: error, index: attachmentIndex, append: appendPath)
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier("public.audio") {
                print("🎵 [BidirectionalShareExt] Processing audio attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "public.audio", options: nil) { [weak self] (item, error) in
                    self?.processFileItem(item: item, error: error, index: attachmentIndex, append: appendPath)
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier("com.adobe.pdf") {
                print("📄 [BidirectionalShareExt] Processing PDF attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { [weak self] (item, error) in
                    self?.processFileItem(item: item, error: error, index: attachmentIndex, append: appendPath)
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier("public.data") {
                print("📎 [BidirectionalShareExt] Processing data attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "public.data", options: nil) { [weak self] (item, error) in
                    self?.processFileItem(item: item, error: error, index: attachmentIndex, append: appendPath)
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                print("📝 [BidirectionalShareExt] Processing text attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                    if let error = error {
                        print("❌ [BidirectionalShareExt] Error loading text: \(error)")
                    } else if let text = item as? String {
                        print("✅ [BidirectionalShareExt] Got text: \(text)")
                        appendText(text)
                    }
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier("public.url") {
                print("🔗 [BidirectionalShareExt] Processing URL attachment \(attachmentIndex)")
                attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                    if let error = error {
                        print("❌ [BidirectionalShareExt] Error loading URL: \(error)")
                    } else if let url = item as? URL {
                        print("✅ [BidirectionalShareExt] Got URL: \(url.absoluteString)")
                        appendText(url.absoluteString)
                    }
                    group.leave()
                }
            } else {
                print("❓ [BidirectionalShareExt] Unknown attachment type \(attachmentIndex), trying first registered type")
                let typeIdentifier = attachment.registeredTypeIdentifiers.first ?? "public.data"
                attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (item, error) in
                    // Try to process as file first, then as text
                    if let text = item as? String {
                        print("✅ [BidirectionalShareExt] Got generic text: \(text)")
                        appendText(text)
                    } else {
                        self?.processFileItem(item: item, error: error, index: attachmentIndex, append: appendPath)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            print("🎯 [BidirectionalShareExt] Processing complete!")
            print("   📁 File paths found: \(allFilePaths.count)")
            for (index, path) in allFilePaths.enumerated() {
                print("      \(index + 1). \(path)")
            }
            print("   📝 Text content found: \(allTextContent.count)")
            for (index, text) in allTextContent.enumerated() {
                print("      \(index + 1). \(text.prefix(100))...")
            }
            
            // Prepare share data
            if !allFilePaths.isEmpty {
                shareData["filePaths"] = allFilePaths  // 🔥 KEY FIX: Use the collected array
                shareData["mimeType"] = self?.determineMimeType(from: allFilePaths.first ?? "") ?? "application/octet-stream"
            }
            
            if !allTextContent.isEmpty {
                shareData["text"] = allTextContent.joined(separator: "\n")
                if shareData["mimeType"] == nil {
                    shareData["mimeType"] = "text/plain"
                }
            }
            
            print("📋 [BidirectionalShareExt] Final share data: \(shareData)")
            self?.saveShareData(shareData)
            self?.navigateToMainApp()
        }
    }
    
    private func processFileItem(
        item: Any?,
        error: Error?,
        index: Int,
        append: (String) -> Void
    ) {
        if let error = error {
            print("❌ [BidirectionalShareExt] Error loading file \(index): \(error)")
            return
        }

        // iOS deletes the attachment as soon as the extension finishes, and the
        // main app cannot reach the extension sandbox, so every item is copied
        // into the App Group container before the path is handed over.
        if let url = item as? URL, url.isFileURL {
            print("✅ [BidirectionalShareExt] Got file URL \(index): \(url.path)")
            if let path = copyIntoSharedContainer(from: url) {
                append(path)
            }
        } else if let image = item as? UIImage {
            print("✅ [BidirectionalShareExt] Got UIImage \(index)")
            if let data = image.jpegData(compressionQuality: 0.95),
               let path = writeIntoSharedContainer(data: data, name: "shared-\(uniqueStamp(index)).jpg") {
                append(path)
            }
        } else if let data = item as? Data {
            print("✅ [BidirectionalShareExt] Got Data \(index): \(data.count) bytes")
            if let path = writeIntoSharedContainer(data: data, name: "shared-\(uniqueStamp(index)).dat") {
                append(path)
            }
        } else {
            print("⚠️ [BidirectionalShareExt] File item \(index) is not a file: \(type(of: item))")
        }
    }

    private func uniqueStamp(_ index: Int) -> String {
        "\(Int(Date().timeIntervalSince1970))-\(index)"
    }

    /// Directory both the extension and the main app can read.
    private func sharedFilesDirectory() -> URL? {
        // /tmp keeps the iOS Simulator working when the App Group is unavailable,
        // matching the JSON handoff in saveShareData().
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
            ?? URL(fileURLWithPath: "/tmp")
        let directory = container.appendingPathComponent("shared_files")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            print("❌ [BidirectionalShareExt] Cannot create shared_files: \(error)")
            return nil
        }
    }

    private func copyIntoSharedContainer(from url: URL) -> String? {
        let name = url.lastPathComponent.isEmpty ? "shared-\(uniqueStamp(0))" : url.lastPathComponent
        guard let destination = sharedFilesDirectory()?.appendingPathComponent(name) else {
            return nil
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: url, to: destination)
            print("📦 [BidirectionalShareExt] Copied to \(destination.path)")
            return destination.path
        } catch {
            print("❌ [BidirectionalShareExt] Copy failed: \(error)")
            return nil
        }
    }

    private func writeIntoSharedContainer(data: Data, name: String) -> String? {
        guard let destination = sharedFilesDirectory()?.appendingPathComponent(name) else {
            return nil
        }
        do {
            try data.write(to: destination)
            print("📦 [BidirectionalShareExt] Wrote to \(destination.path)")
            return destination.path
        } catch {
            print("❌ [BidirectionalShareExt] Write failed: \(error)")
            return nil
        }
    }
    
    private func determineMimeType(from path: String) -> String {
        let fileExtension = path.lowercased().split(separator: ".").last?.description ?? ""
        
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "bmp":
            return "image/bmp"
        case "heic", "heif":
            return "image/heic"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "avi":
            return "video/x-msvideo"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "m4a":
            return "audio/mp4"
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "zip":
            return "application/zip"
        case "txt":
            return "text/plain"
        case "html":
            return "text/html"
        case "json":
            return "application/json"
        default:
            return "application/octet-stream"
        }
    }
    
    private func saveShareData(_ data: [String: Any]) {
        let appGroupId = self.appGroupId

        // Save to system temp file for iOS Simulator compatibility (same path as plugin)
        let sharedTmpPath = URL(fileURLWithPath: "/tmp/")
        let shareFilePath = sharedTmpPath.appendingPathComponent("share_intent_data_\(appGroupId).json")
        print("ShareExtension: Using shared system tmp: \(shareFilePath.path)")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            try jsonData.write(to: shareFilePath)
            print("ShareExtension: ✅ Data saved successfully to temp file: \(shareFilePath.path)")
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("ShareExtension: Saved data: \(jsonString)")
            }
        } catch {
            print("ShareExtension: ❌ Error saving to temp file: \(error)")
        }
        
        // Try UserDefaults with App Groups, fall back to standard UserDefaults
        var userDefaults: UserDefaults?
        if let groupDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults = groupDefaults
            print("ShareExtension: Using App Group UserDefaults: \(appGroupId)")
        } else {
            userDefaults = UserDefaults.standard
            print("ShareExtension: Fallback to standard UserDefaults")
        }
        
        if let userDefaults = userDefaults {
            // Clear existing data first to avoid stale data
            userDefaults.removeObject(forKey: "shareData")
            userDefaults.removeObject(forKey: "ShareKey")
            userDefaults.removeObject(forKey: "SharingKeyData") 
            userDefaults.synchronize()
            
            // Save data in multiple formats for compatibility
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    // Primary key used by Flutter plugin
                    userDefaults.set(jsonString, forKey: "shareData")
                    
                    // Additional keys for compatibility
                    userDefaults.set([data], forKey: "ShareKey")
                    userDefaults.set(jsonString, forKey: "SharingKeyData")
                    
                    userDefaults.synchronize()
                    print("ShareExtension: Share data saved successfully with keys: shareData, ShareKey, SharingKeyData")
                    print("ShareExtension: Saved data: \(jsonString)")
                }
            } catch {
                print("ShareExtension: Failed to serialize share data: \(error)")
            }
        }
    }
    
    private func navigateToMainApp() {
        guard let bundleId = Bundle.main.object(forInfoDictionaryKey: "MainAppBundleId") as? String else {
            print("ShareExtension: MainAppBundleId not found in Info.plist")
            closeShareExtension()
            return
        }
        
        let urlScheme = "SharingMedia-\(bundleId)://"
        guard let url = URL(string: urlScheme) else {
            print("ShareExtension: Failed to create URL with scheme: \(urlScheme)")
            closeShareExtension()
            return
        }
        
        // Use the proven working approach from FSIShareViewController
        if #available(iOS 18.0, *) {
            // iOS 18+ approach
            var responder: UIResponder? = self
            while responder != nil {
                if let app = responder as? UIApplication {
                    app.open(url, options: [:], completionHandler: { [weak self] success in
                        print("ShareExtension: App launch \(success ? "successful" : "failed")")
                        DispatchQueue.main.async {
                            self?.closeShareExtension()
                        }
                    })
                    break
                }
                responder = responder?.next
            }
        } else {
            // iOS 13-17 approach using selector
            var responder: UIResponder? = self
            let selectorOpenURL = sel_registerName("openURL:")
            while responder != nil {
                if responder?.responds(to: selectorOpenURL) == true {
                    _ = responder?.perform(selectorOpenURL, with: url)
                    print("ShareExtension: Attempted to open URL via selector")
                    break
                }
                responder = responder?.next
            }
            closeShareExtension()
        }
    }
    
    private func closeShareExtension() {
        guard !didClose else { return }
        didClose = true
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
