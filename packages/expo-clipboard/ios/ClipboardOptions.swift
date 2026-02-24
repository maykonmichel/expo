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
  var localOnly: Bool? { get }
}

internal struct SetStringOptions: Record, SetClipboardOptionsProtocol {
  @Field
  var inputFormat: StringFormat = .plainText

  @Field
  var localOnly: Bool?
}

internal struct SetUrlOptions: Record, SetClipboardOptionsProtocol {
  @Field
  var localOnly: Bool?
}

internal struct SetImageOptions: Record, SetClipboardOptionsProtocol {
  @Field
  var localOnly: Bool?
}

internal enum StringFormat: String, Enumerable {
  case plainText
  case html
}
