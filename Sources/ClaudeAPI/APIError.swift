// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Error envelope returned by the API (both in HTTP error bodies and as an
/// SSE `error` event).
package struct APIError: Error, Sendable, Hashable, Codable {
  package enum Kind: String, Sendable, Codable {
    case invalidRequest = "invalid_request_error"
    case authentication = "authentication_error"
    case permission = "permission_error"
    case notFound = "not_found_error"
    case requestTooLarge = "request_too_large"
    case rateLimit = "rate_limit_error"
    case api = "api_error"
    case overloaded = "overloaded_error"
    /// Forward-compatibility: an unrecognized error type still surfaces as a
    /// typed `APIError` carrying the API's message, not a `DecodingError`.
    case other

    package init(from decoder: Decoder) throws {
      let raw = try decoder.singleValueContainer().decode(String.self)
      self = Kind(rawValue: raw) ?? .other
    }
  }

  package var kind: Kind
  /// The `type` as the body wrote it: `kind`'s raw value for a known kind,
  /// and the only record of an unrecognized one. `nil` when the error was
  /// classified from the HTTP status alone.
  package var type: String?
  package var message: String
  package var requestID: String?
  /// The HTTP status of the response the error came in. `nil` for an SSE
  /// `error` event, which arrives inside a successful response.
  package var statusCode: Int?

  package init(
    kind: Kind,
    message: String,
    requestID: String? = nil,
    type: String? = nil,
    statusCode: Int? = nil
  ) {
    self.kind = kind
    self.type = type
    self.message = message
    self.requestID = requestID
    self.statusCode = statusCode
  }

  private enum CodingKeys: String, CodingKey { case type, message }

  package init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let type = try c.decode(String.self, forKey: .type)
    kind = Kind(rawValue: type) ?? .other
    self.type = type
    message = try c.decode(String.self, forKey: .message)
    requestID = nil
    statusCode = nil
  }

  package func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(type ?? kind.rawValue, forKey: .type)
    try c.encode(message, forKey: .message)
  }
}

extension APIError: LocalizedError {
  package var errorDescription: String? {
    "\(kind.rawValue): \(message)" + (requestID.map { " (request_id: \($0))" } ?? "")
  }
}

/// Top-level error body: `{ "type": "error", "error": {...}, "request_id": "..." }`
struct APIErrorEnvelope: Decodable {
  var error: APIError
  var requestID: String?
  private enum CodingKeys: String, CodingKey {
    case error
    case requestID = "request_id"
  }
}
