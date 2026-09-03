import OSLog

/// Structured logging for diagnosing user-reported issues. Filter the user's
/// logs with:
///   log stream  --predicate 'subsystem == "com.textpolisher.app"' --info --debug
///   log show --last 10m --predicate 'subsystem == "com.textpolisher.app"' --info --debug
///
/// We log decisions and outcomes (and text *lengths*) but never the text itself.
enum Log {
    private static let subsystem = "com.textpolisher.app"
    static let polish = Logger(subsystem: subsystem, category: "polish")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let replace = Logger(subsystem: subsystem, category: "replace")
    static let engine = Logger(subsystem: subsystem, category: "engine")
}
