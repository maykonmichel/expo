// Copyright 2018-present 650 Industries. All rights reserved.

import ExpoModulesCore

internal struct GetImageOptions: Record {
  @Field("format")
  var imageFormat: ImageFormat = .jpeg

  @Field
  var jpegQuality: Double = 1.0
}

internal enum ImageFormat: String, Enumerable {
  case jpeg
  case png

  func getMimeType() -> String {
    switch self {
    case .jpeg:
      return "image/jpeg"
    case .png:
      return "image/png"
    }
  }
}

internal struct GetStringOptions: Record {
  @Field
  var preferredFormat: StringFormat = .plainText
}

internal protocol SetClipboardOptionsProtocol {
  var ttl: Double? { get }
}

internal struct CommonSetClipboardOptions: Record, SetClipboardOptionsProtocol {
  @Field
  var ttl: Double?
}

internal struct SetStringOptions: Record, SetClipboardOptionsProtocol {
  @Field
  var inputFormat: StringFormat = .plainText

  @Field
  var ttl: Double?
}

internal typealias SetUrlOptions = CommonSetClipboardOptions

internal typealias SetImageOptions = CommonSetClipboardOptions

internal enum StringFormat: String, Enumerable {
  case plainText
  case html
}
