import UIKit
import UniformTypeIdentifiers

class MockUIPasteboard: UIPasteboard {
  var _items: [String: Any] = [:]
  var _options: [UIPasteboard.OptionsKey: Any] = [:]

  override var items: [[String: Any]] {
    get {
      return [_items]
    }
    set {
      _items = newValue.count > 0 ? newValue[0] : [:]
    }
  }

  override var string: String? {
    get {
      if let legacyString = _items["string"] as? String {
        return legacyString
      }
      if let utf8String = _items[UTType.utf8PlainText.identifier] as? String {
        return utf8String
      }
      if let utf8String = _items[UTType.utf8PlainText.identifier] as? NSString {
        return utf8String as String
      }
      if let utf8Data = _items[UTType.utf8PlainText.identifier] as? Data {
        return String(data: utf8Data, encoding: .utf8)
      }
      return nil
    }
    set {
      _items = ["string": newValue as Any]
    }
  }

  override var url: URL? {
    get {
      if let legacyUrl = _items["url"] as? URL {
        return legacyUrl
      }
      if let url = _items[UTType.url.identifier] as? URL {
        return url
      }
      if let urlString = _items[UTType.url.identifier] as? String {
        return URL(string: urlString)
      }
      if let urlString = _items[UTType.utf8PlainText.identifier] as? String {
        return URL(string: urlString)
      }
      return nil
    }
    set {
      _items = ["url": newValue as Any]
    }
  }

  override var image: UIImage? {
    get {
      if let legacyImage = _items["image"] as? UIImage {
        return legacyImage
      }
      if let pngData = _items[UTType.png.identifier] as? Data {
        return UIImage(data: pngData)
      }
      if let jpegData = _items[UTType.jpeg.identifier] as? Data {
        return UIImage(data: jpegData)
      }
      return nil
    }
    set {
      _items = ["image": newValue as Any]
    }
  }

  override var hasStrings: Bool {
    return string != nil
  }

  override var hasImages: Bool {
    return image != nil
  }

  override var hasURLs: Bool {
    return url != nil
  }

  override func value(forPasteboardType pasteboardType: String) -> Any? {
    return _items[pasteboardType]
  }

  override func data(forPasteboardType pasteboardType: String) -> Data? {
    if let data = _items[pasteboardType] as? Data {
      return data
    }
    if let string = _items[pasteboardType] as? String {
      return string.data(using: .utf8)
    }
    if let string = _items[pasteboardType] as? NSString {
      return (string as String).data(using: .utf8)
    }
    return nil
  }

  override func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any] = [:]) {
    self.items = items
    self._options = options
  }

  override func contains(pasteboardTypes: [String]) -> Bool {
    return _items.contains(where: { key, _ in
      pasteboardTypes.contains(key)
    })
  }
}

extension UIPasteboard {
  struct StaticVars {
    static var mockPastebaord = MockUIPasteboard()
  }

  @objc dynamic class var swizzledGeneralPasteboard: UIPasteboard {
    return StaticVars.mockPastebaord
  }
}

func swizzleGeneralPasteboard() {
  // replace UIPasteboard.general getter with MockUIPasteboard instance
  let originSelector = #selector(getter:UIPasteboard.general)
  let swizzleSelector = #selector(getter:UIPasteboard.swizzledGeneralPasteboard)
  let originMethod = class_getClassMethod(UIPasteboard.self, originSelector)
  let swizzleMethod = class_getClassMethod(UIPasteboard.self, swizzleSelector)
  method_exchangeImplementations(originMethod!, swizzleMethod!)
}
