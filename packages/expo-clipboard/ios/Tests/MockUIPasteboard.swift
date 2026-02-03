import UIKit

class MockUIPasteboard: UIPasteboard {
  var _items: [String: Any] = [:]
  var lastSetOptions: [UIPasteboard.OptionsKey: Any]?

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
      return _items["public.plain-text"] as? String ?? _items["string"] as? String
    }
    set {
      _items = ["string": newValue as Any]
    }
  }

  override var url: URL? {
    get {
      return _items["public.url"] as? URL ?? _items["url"] as? URL
    }
    set {
      _items = ["url": newValue as Any]
    }
  }

  override var image: UIImage? {
    get {
      // Handle both UIImage objects and Data
      // Check for generic image types
      if let image = _items["public.image"] as? UIImage ?? _items["image"] as? UIImage {
        return image
      }
      // Check for specific image types (PNG, JPEG)
      if let data = _items["public.image"] as? Data ?? _items["image"] as? Data ??
                    _items["public.png"] as? Data ?? _items["public.jpeg"] as? Data {
        return UIImage(data: data)
      }
      return nil
    }
    set {
      _items = ["image": newValue as Any]
    }
  }

  override var hasStrings: Bool {
    return _items["public.plain-text"] != nil || _items["string"] != nil
  }

  override var hasImages: Bool {
    let hasImageItem = _items["public.image"] != nil || _items["image"] != nil ||
                       _items["public.png"] != nil || _items["public.jpeg"] != nil
    if !hasImageItem {
      return false
    }
    // Verify the item is actually valid image data
    return self.image != nil
  }

  override var hasURLs: Bool {
    return _items["public.url"] != nil || _items["url"] != nil
  }

  override func value(forPasteboardType pasteboardType: String) -> Any? {
    return _items[pasteboardType]
  }

  override func data(forPasteboardType pasteboardType: String) -> Data? {
    return _items[pasteboardType] as? Data
  }

  override func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any] = [:]) {
    self.items = items
    lastSetOptions = options.isEmpty ? nil : options
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
