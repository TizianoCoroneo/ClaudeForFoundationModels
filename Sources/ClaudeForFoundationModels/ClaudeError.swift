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
  /// The API, or a gateway in front of it, failed the request with an error
  /// that has no ``LanguageModelError`` case: a credential without access, a
  /// malformed request, a server error, or an error type the framework does
  /// not know, such as a gateway's own (LiteLLM answers a spent budget with
  /// HTTP 422 and type `budget_exceeded`).
  ///
  /// - Parameters:
  ///   - statusCode: The HTTP status of the response. `nil` for an error
  ///     that arrived as an event inside a stream.
  ///   - type: The error's type as it was sent, such as `permission_error`.
  ///   - message: The error's message, with its request id when it has one.
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
