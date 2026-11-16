// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0

import ClaudeAPI
import Foundation
import FoundationModels
import Testing

@testable import ClaudeForFoundationModels

@Suite struct ErrorMapperTests {
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  private func mapped(
    _ kind: APIError.Kind,
    _ message: String = "boom",
    requestID: String? = nil
  )
    -> any Error
  {
    ErrorMapper.map(
      APIError(kind: kind, message: message, requestID: requestID),
      usesAppAttest: false
    )
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  private func apiError(_ error: any Error) -> (statusCode: Int?, type: String, message: String)? {
    guard case ClaudeError.apiError(let statusCode, let type, let message) = error else {
      Issue.record("expected apiError, got \(error)")
      return nil
    }
    return (statusCode, type, message)
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `rate limit becomes rateLimited with no reset date`() {
    guard case LanguageModelError.rateLimited(let payload) = mapped(.rateLimit, "slow down") else {
      Issue.record("expected rateLimited")
      return
    }
    #expect(payload.resetDate == nil)
    #expect(payload.debugDescription.contains("slow down"))
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `overloaded becomes rateLimited with no fabricated reset date`() {
    guard case LanguageModelError.rateLimited(let payload) = mapped(.overloaded) else {
      Issue.record("expected rateLimited")
      return
    }
    // The API doesn't say when capacity returns, so neither do we.
    #expect(payload.resetDate == nil)
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `request too large becomes contextSizeExceeded`() {
    guard case LanguageModelError.contextSizeExceeded = mapped(.requestTooLarge) else {
      Issue.record("expected contextSizeExceeded")
      return
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `invalid request mentioning context becomes contextSizeExceeded`() {
    guard
      case LanguageModelError.contextSizeExceeded = mapped(
        .invalidRequest,
        "Context length exceeded"
      )
    else {
      Issue.record("expected contextSizeExceeded")
      return
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `plain invalid request becomes apiError with its type`() {
    #expect(apiError(mapped(.invalidRequest, "missing field"))?.type == "invalid_request_error")
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `not found becomes apiError with its type`() {
    #expect(apiError(mapped(.notFound))?.type == "not_found_error")
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `authentication becomes missingCredential`() {
    guard case ClaudeError.missingCredential = mapped(.authentication) else {
      Issue.record("expected missingCredential for auth")
      return
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `permission becomes apiError, not missingCredential`() {
    // A valid credential without access is not a missing credential — keep
    // the API's own message so the developer sees what was denied.
    let error = apiError(mapped(.permission, "denied"))
    #expect(error?.type == "permission_error")
    #expect(error?.message == "denied")
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `generic api error becomes apiError with its type`() {
    #expect(apiError(mapped(.api, "internal error"))?.type == "api_error")
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `request id is folded into the debug description`() {
    guard
      case LanguageModelError.rateLimited(let payload) = mapped(
        .rateLimit,
        "slow",
        requestID: "req_9"
      )
    else {
      Issue.record("expected rateLimited")
      return
    }
    #expect(payload.debugDescription.contains("req_9"))
    #expect(payload.debugDescription.contains("slow"))
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `URLError timeout becomes a LanguageModelError timeout`() {
    guard
      case LanguageModelError.timeout = ErrorMapper.map(URLError(.timedOut), usesAppAttest: false)
    else {
      Issue.record("expected timeout")
      return
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `a non-timeout URLError passes through unchanged`() {
    let original = URLError(.notConnectedToInternet)
    #expect(
      (ErrorMapper.map(original, usesAppAttest: false) as? URLError)?.code
        == .notConnectedToInternet
    )
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `an unrecognized API error type keeps its name`() {
    let error = apiError(
      ErrorMapper.map(
        APIError(kind: .other, message: "novel failure", type: "billing_error"),
        usesAppAttest: false
      )
    )
    #expect(error?.type == "billing_error")
    #expect(error?.message == "novel failure")
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `a gateway's spent budget keeps its status and type`() {
    // LiteLLM answers a key over its budget with HTTP 422 and its own type.
    let error = apiError(
      ErrorMapper.map(
        APIError(
          kind: .other,
          message: "Budget has been exceeded!",
          requestID: "req_7",
          statusCode: 422,
          type: "budget_exceeded"
        ),
        usesAppAttest: false
      )
    )
    #expect(error?.statusCode == 422)
    #expect(error?.type == "budget_exceeded")
    #expect(error?.message.contains("req_7") == true)
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `an error event inside a stream has no status`() {
    #expect(apiError(mapped(.api))?.statusCode == nil)
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `image preparation failures map to unsupportedTranscriptContent`() {
    guard
      case LanguageModelError.unsupportedTranscriptContent(let payload) = ErrorMapper.map(
        ClaudeImage.Error.tooLarge(byteCount: 99),
        usesAppAttest: false
      )
    else {
      Issue.record("expected unsupportedTranscriptContent")
      return
    }
    #expect(payload.debugDescription.contains("99"))
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `unrecognized errors pass through unchanged`() {
    struct Marker: Error {}
    #expect(ErrorMapper.map(Marker(), usesAppAttest: false) is Marker)
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `unsupported attestation becomes attestationUnsupported`() {
    guard case ClaudeError.attestationUnsupported = ErrorMapper.map(AppAttestError.unsupported)
    else {
      Issue.record("expected attestationUnsupported")
      return
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @Test func `other attestation failures become attestationFailed`() {
    for error in [AppAttestError.notYetAvailable, .keyInvalidated] {
      guard case ClaudeError.attestationFailed = ErrorMapper.map(error, usesAppAttest: false) else {
        Issue.record("expected attestationFailed for \(error)")
        return
      }
    }
  }
}
