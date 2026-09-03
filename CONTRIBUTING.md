# Contributing to TextPolisher

Thanks for helping improve TextPolisher.

## Development setup

The macOS app requires macOS 26 or later and Swift 6.2 or later.

```bash
git clone https://github.com/DanLeonti/textpolisher.git
cd textpolisher
Scripts/build_app.sh
open dist/TextPolisher.app
```

Grant Accessibility access when prompted. If an ad-hoc rebuild stops receiving
Accessibility access, remove the old entry in System Settings, then add the
rebuilt app again.

The Windows implementation and its setup instructions are in
[`windows/`](windows/). The iOS implementation is documented in
[`ios/README.md`](ios/README.md).

## Pull requests

1. Open an issue before starting a large or behavior-changing contribution.
2. Keep each pull request focused on one concern.
3. Build the affected platform locally and describe how you tested the change.
4. Do not add telemetry, remote text processing, accounts, payments, or
   dependencies that weaken the app's privacy-first design.
5. Never commit credentials, `.env` files, signing certificates, customer data,
   or generated build output.

By contributing, you agree that your contribution is licensed under the
repository's [MIT License](LICENSE).
