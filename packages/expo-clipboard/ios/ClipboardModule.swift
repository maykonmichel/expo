// Copyright 2018-present 650 Industries. All rights reserved.

import ExpoModulesCore
import UIKit

let onClipboardChanged = "onClipboardChanged"

public class ClipboardModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoClipboard")

    // MARK: - Strings

    AsyncFunction("getStringAsync") { (options: GetStringOptions) -> String in
      switch options.preferredFormat {
      case .plainText:
        return UIPasteboard.general.string ?? ""
      case .html:
        return UIPasteboard.general.html ?? ""
      }
    }

    AsyncFunction("setStringAsync") { (content: String?, options: SetStringOptions?) -> Bool in
      guard let content = content else {
        UIPasteboard.general.string = nil
        return true
      }

      let inputFormat = options?.inputFormat ?? .plainText
      let pasteboardOptions = self.createPasteboardOptions(options: options)

      switch inputFormat {
      case .plainText:
        if let pasteboardOptions = pasteboardOptions {
          UIPasteboard.general.setItems([[UTType.plainText.identifier: content]], options: pasteboardOptions)
        } else {
          UIPasteboard.general.string = content
        }
      case .html:
        if let pasteboardOptions = pasteboardOptions {
          UIPasteboard.general.setItems([[UTType.html.identifier: content]], options: pasteboardOptions)
        } else {
          UIPasteboard.general.html = content
        }
      }

      return true
    }

    AsyncFunction("hasStringAsync") { () -> Bool in
      return UIPasteboard.general.hasStrings || UIPasteboard.general.hasHTML
    }

    // MARK: - URLs

    AsyncFunction("getUrlAsync") { () -> String? in
      return UIPasteboard.general.url?.absoluteString
    }

    AsyncFunction("setUrlAsync") { (url: URL, options: SetUrlOptions?) in
      let pasteboardOptions = self.createPasteboardOptions(options: options)

      if let pasteboardOptions = pasteboardOptions {
        UIPasteboard.general.setItems([[UTType.url.identifier: url]], options: pasteboardOptions)
      } else {
        UIPasteboard.general.url = url
      }
    }

    AsyncFunction("hasUrlAsync") { () -> Bool in
      return UIPasteboard.general.hasURLs
    }

    // MARK: - Images

    AsyncFunction("setImageAsync") { (content: String, options: SetImageOptions?) in
      guard let data = Data(base64Encoded: content),
            let image = UIImage(data: data) else {
        throw InvalidImageException(content)
      }

      let pasteboardOptions = self.createPasteboardOptions(options: options)

      if let pasteboardOptions = pasteboardOptions {
        // Use the original data instead of UIImage object for property list compatibility
        // Detect image format and use the appropriate UTI for proper recognition by the pasteboard
        let imageType = self.detectImageType(from: data)
        UIPasteboard.general.setItems([[imageType: data]], options: pasteboardOptions)
      } else {
        UIPasteboard.general.image = image
      }
    }

    AsyncFunction("hasImageAsync") { () -> Bool in
      return UIPasteboard.general.hasImages
    }

    AsyncFunction("getImageAsync") { (options: GetImageOptions) -> [String: Any]? in
      guard let image = UIPasteboard.general.image else {
        return nil
      }
      guard let data = imageToData(image, options: options) else {
        throw PasteFailureException()
      }

      let imgData = "data:\(options.imageFormat.getMimeType());base64,\(data.base64EncodedString())"
      return [
        "data": imgData,
        // TODO (barthap): Use CGSize when returning Records is possible
        "size": [
          "width": image.size.width,
          "height": image.size.height
        ]
      ]
    }

    Property("isPasteButtonAvailable") { () -> Bool in
      if #available(iOS 16.0, *) {
        return true
      }
      return false
    }

    // MARK: - Events

    Events(onClipboardChanged)

    OnStartObserving {
      NotificationCenter.default.removeObserver(self, name: UIPasteboard.changedNotification, object: nil)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.clipboardChangedListener),
        name: UIPasteboard.changedNotification,
        object: nil
      )
    }

    OnStopObserving {
      NotificationCenter.default.removeObserver(self, name: UIPasteboard.changedNotification, object: nil)
    }

    // MARK: - View

    View(ClipboardPasteButton.self) {
      Events("onPastePressed")

      Prop("backgroundColor") { (view, color: UIColor?) in
        if view.baseBackgroundColor != color {
          view.baseBackgroundColor = color
        }
      }

      Prop("foregroundColor") { (view, color: UIColor?) in
        if view.baseForegroundColor != color {
          view.baseForegroundColor = color
        }
      }

      Prop("acceptedContentTypes") { (view, types: [AcceptedTypes]?) in
        view.acceptedContentTypes = types ?? []
      }

      Prop("cornerStyle") { (view, style: CornerStyle?) in
        view.cornerStyle = style ?? .capsule
      }

      Prop("displayMode") { (view, mode: DisplayMode?) in
        view.displayMode = mode ?? .iconAndLabel
      }

      Prop("imageOptions") { (view, options: GetImageOptions?) in
        view.imageOptions = options ?? GetImageOptions()
      }

      OnViewDidUpdateProps { view in
        view.update()
      }
    }
  }

  @objc
  func clipboardChangedListener() {
    sendEvent(onClipboardChanged, [
      "contentTypes": availableContentTypes()
    ])
  }

  private func createPasteboardOptions(options: SetClipboardOptionsProtocol?) -> [UIPasteboard.OptionsKey: Any]? {
    guard let ttl = options?.ttl, ttl > 0 else {
      return nil
    }

    let expirationDate = Date().addingTimeInterval(ttl)
    return [.expirationDate: expirationDate]
  }

  private func detectImageType(from data: Data) -> String {
    // Check for PNG signature (89 50 4E 47 0D 0A 1A 0A)
    if data.count >= 8 {
      let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
      let header = [UInt8](data.prefix(8))
      if header == pngSignature {
        return UTType.png.identifier
      }
    }

    // Check for JPEG signature (FF D8 FF)
    if data.count >= 3 {
      let jpegSignature: [UInt8] = [0xFF, 0xD8, 0xFF]
      let header = [UInt8](data.prefix(3))
      if header == jpegSignature {
        return UTType.jpeg.identifier
      }
    }

    // Fallback to generic image type
    return UTType.image.identifier
  }
}

private func imageToData(_ image: UIImage, options: GetImageOptions) -> Data? {
  switch options.imageFormat {
    case .jpeg: return image.jpegData(compressionQuality: options.jpegQuality)
    case .png: return image.pngData()
  }
}

private func availableContentTypes() -> [String] {
  let predicateDict: [ContentType: Bool] = [
    // if it has HTML, it can be converted to plain text too
    .plainText: UIPasteboard.general.hasStrings || UIPasteboard.general.hasHTML,
    .html: UIPasteboard.general.hasHTML,
    .image: UIPasteboard.general.hasImages,
    .url: UIPasteboard.general.hasURLs
  ]
  let availableTypes = predicateDict.filter { $0.value }.keys.map { $0.rawValue }
  return Array(availableTypes)
}

private enum ContentType: String {
  case plainText = "plain-text"
  case html = "html"
  case image = "image"
  case url = "url"
}
