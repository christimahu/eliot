# Changelog

All notable changes to this project will be documented in this file.

## v0.2.0 - 2025-06-08

### Changed
* Major refactor of core application logic for improved stability.
* Overhauled the testing framework for clarity and robustness.

### Added
* Comprehensive test suite with coverage increased to over 90%.
* Detailed tests for logger formatting, including metadata and edge cases.

### Fixed
* Corrected logger implementation to reliably use the custom telemetry handler in all environments.
* Resolved multiple test failures and race conditions present in the initial version.

## v0.1.0 - 2025-06-06

### Added

* Initial release of Eliot.
* Fault-tolerant OTP application structure.
* `Eliot.Logger` for structured, centralized logging with telemetry integration.
* `Eliot.ErrorHandler` with retry and circuit-breaker logic for resilient operations.
* Comprehensive test suite with unit and integration tests.
* Full ExDoc documentation for the public API.
