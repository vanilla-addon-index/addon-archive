# Changelog

All notable changes to this project will be documented in this file.

## [beta0.3.12] - 2025-01-27

### Fixed

- **ChatThrottleLib Error Resolved**: Successfully fixed "callbackFn: expected function, got number" error
- Ensured queueName parameter is never nil when calling ChatThrottleLib:SendAddonMessage
- Fixed typo in ChatThrottleLib error message (ChatMessage -> SendChatMessage)
- Removed debug code after successful resolution

### Changed

- Updated version numbers across all files (main: 3.8.10, vanilla: 3.8.9)

## [beta0.3.11] - 2025-01-27

### Fixed

- **ChatThrottleLib Error Debugging**: Added debug output to help identify parameter passing issues
- Fixed typo in ChatThrottleLib error message (ChatMessage -> SendChatMessage)
- Improved queueName validation to prevent nil values

### Changed

- Updated version numbers across all files (main: 3.8.9, vanilla: 3.8.8)

## [beta0.3.10] - 2025-01-27

### Fixed

- **ChatThrottleLib Callback Error**: Fixed "callbackFn: expected function, got number" error in AceComm-3.0 library
- Ensured queueName parameter is never nil when calling ChatThrottleLib:SendAddonMessage
- Addon communication should now work without throwing callback function errors

### Changed

- Updated version numbers across all files (main: 3.8.8, vanilla: 3.8.7)

## [beta0.3.9] - 2025-09-09

### Fixed

- **ChatThrottleLib Compatibility**: Fixed AceComm-3.0 library errors caused by version incompatibility between modern WoW message length restrictions and vanilla WoW clients
- Implemented proper version detection instead of disabling safety checks
- Messages longer than 255 bytes now work correctly on vanilla/TurtleWoW while maintaining safety on modern clients

### Changed

- Updated README.md to better explain what the addon does

## [beta0.3.8] - Previous Release

### Notes

- Previous version had ChatThrottleLib errors that were temporarily fixed by commenting out error checks
- This version properly addresses the underlying compatibility issue
