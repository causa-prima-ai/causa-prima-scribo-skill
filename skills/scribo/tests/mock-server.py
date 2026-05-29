#!/usr/bin/env python3
"""Minimal mock of the Scribo public API for the skill smoke test.

Implements just enough of /api/v1/* to drive request -> redeem -> create ->
download end to end, plus the failure shapes the scripts must map to exit
codes. Binds 127.0.0.1 on $PORT (default 8799). No external deps.
"""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

CHALLENGE_ID = "11111111-1111-4111-8111-111111111111"
GOOD_CODE = "234567"
VERIFICATION_TOKEN = "vtok-mock-abcdef"
PDF_BYTES = b"%PDF-1.5\n%mock-invoice\n"


class Handler(BaseHTTPRequestHandler):
    # Counts every POST /api/v1/invoices attempt (regardless of outcome) so the
    # smoke test can prove the verify-then-persist contract: the tokenless path
    # must never hit this endpoint. Class-level — shared across per-request
    # handler instances.
    invoice_post_attempts = 0

    def log_message(self, *_):  # quiet
        pass

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _drain(self):
        n = int(self.headers.get("Content-Length", 0) or 0)
        return self.rfile.read(n) if n else b""

    def do_GET(self):
        p = self.path
        if p == "/__debug/invoice-post-attempts":
            return self._json(200, {"count": Handler.invoice_post_attempts})
        if p == "/api/v1/jurisdictions":
            return self._json(200, [
                {"jurisdiction": "DE", "formats": ["zugferd_comfort"], "default_format": "zugferd_comfort"},
                {"jurisdiction": "US", "formats": ["plain_pdf"], "default_format": "plain_pdf"},
            ])
        if p.startswith("/api/v1/invoices/") and p.endswith("/download"):
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(PDF_BYTES)))
            self.end_headers()
            self.wfile.write(PDF_BYTES)
            return
        return self._json(404, {"error": {"code": "not_found", "message": p}})

    def do_POST(self):
        body = self._drain()
        p = self.path
        if p == "/api/v1/scribo/email-verifications":
            return self._json(202, {
                "challenge_id": CHALLENGE_ID,
                "expires_at": "2099-01-01T00:00:00Z",
                "next_request_allowed_at": "2099-01-01T00:00:30Z",
            })
        if p.startswith("/api/v1/scribo/email-verifications/") and p.endswith("/redeem"):
            try:
                code = json.loads(body or b"{}").get("code")
            except ValueError:
                code = None
            # Only the known challenge + correct code redeems; everything else
            # (wrong code, unknown/expired/revoked challenge) is the uniform
            # verification_invalid, mirroring the real anti-enum behavior.
            if p == "/api/v1/scribo/email-verifications/%s/redeem" % CHALLENGE_ID and code == GOOD_CODE:
                return self._json(200, {"verification_token": VERIFICATION_TOKEN, "expires_at": "2099-01-01T00:30:00Z"})
            return self._json(400, {"error": {"code": "verification_invalid", "message": "Verification challenge invalid, expired, or revoked."}})
        if p == "/api/v1/invoices":
            # Count before the token check so a regression that POSTs without a
            # token (and gets the 401) is still caught by the smoke test.
            Handler.invoice_post_attempts += 1
            token = self.headers.get("X-Email-Verification-Token")
            if not token:
                return self._json(401, {"error": {"code": "email_verification_required", "message": "Email verification required."}})
            return self._json(201, {
                "invoice_id": "inv-mock-1",
                "document_id": "doc-mock-1",
                "format": "zugferd_comfort",
                "download_url": "http://127.0.0.1:%s/api/v1/invoices/inv-mock-1/download" % os.environ.get("PORT", "8799"),
                "download_url_expires_at": "2099-01-01T00:15:00Z",
                "validator_summary": {"valid": True, "validator": "mock", "errors": []},
                "received_verification_token": token,
            })
        return self._json(404, {"error": {"code": "not_found", "message": p}})


def main():
    port = int(os.environ.get("PORT", "8799"))
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
