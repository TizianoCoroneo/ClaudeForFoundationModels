// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Errors surfaced by the Claude provider that don't map onto a
/// ``LanguageModelError`` case. App developers can pattern-match on these to
/// drive product flows (key entry).
@available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
public enum ClaudeError: LocalizedError, Sendable {
  /// No usable credential. Provide an API key via ``AuthMode/apiKey(_:)``,
  /// or, when using ``AuthMode/proxied(headers:)``, check that the proxy
  /// supplies authentication.
  case missingCredential
  /// App Attest can't run on this hardware (simulators, devices without a
  /// Secure Enclave). Use ``AuthMode/apiKey(_:)`` for development, or
  /// ``AuthMode/proxied(headers:)``.
  case attestationUnsupported
  /// The device supports App Attest but no credential could be obtained.
  /// Causes include the server rejecting the attestation or assertion, an
  /// unusable response, an unreachable credential store, and a client ID
  /// already in use against a different base URL.
  case attestationFailed
  /// The API, or a proxy in front of it, refused the request with an error
  /// that has no ``LanguageModelError`` equivalent: a permission error, a
  /// server error, a request it rejected, or an error type this package
  /// doesn't know, such as a proxy's own. Match on `statusCode` or `type` to
  /// tell them apart.
  ///
  /// - Parameters:
  ///   - statusCode: The HTTP status of the response. `nil` for an error the
  ///     stream reported after a successful response.
  ///   - type: The error's `type` as the response wrote it
  ///     (`"permission_error"`, `"api_error"`, …). For a body without one,
  ///     the type the status implies.
  ///   - message: The error's message, with its request id when it had one.
  case apiError(statusCode: Int?, type: String, message: String)

  public var errorDescription: String? {
    switch self {
    case .missingCredential:
      "No Claude credential. Provide an API key."
    case .attestationUnsupported:
      "App Attest is not supported on this device or simulator."
    case .attestationFailed:
      "App attestation failed to produce a credential."
    case .apiError(_, let type, let message):
      "\(type): \(message)"
    }
  }
}
