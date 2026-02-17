// ABOUTME: Shared benchmark utilities: median-of-N timing, millisecond formatting, speedup ratios.
// ABOUTME: Provides benchmark(), ms(), speedup(), and BenchItem used by all benchmark test files.
import Foundation

/// Measures the median duration over `runs` iterations after `warmup` throwaway runs.
func benchmark(warmup: Int = 5, runs: Int = 15, _ block: () -> Void) -> Duration {
  let clock = ContinuousClock()
  for _ in 0 ..< warmup {
    block()
  }
  var times = [Duration]()
  for _ in 0 ..< runs {
    times.append(clock.measure { block() })
  }
  times.sort()
  return times[times.count / 2]
}

/// Formats a Duration as milliseconds with 3 decimal places.
func ms(_ d: Duration) -> String {
  let milliseconds = Double(d.components.attoseconds) / 1_000_000_000_000_000.0
    + Double(d.components.seconds) * 1000.0
  return String(format: "%.3f", milliseconds)
}

/// Computes the speedup ratio of `baseline` over `candidate`.
func speedup(_ candidate: Duration, _ baseline: Duration) -> String {
  let candidateMs = Double(candidate.components.attoseconds) / 1_000_000_000_000_000.0
    + Double(candidate.components.seconds) * 1000.0
  let baselineMs = Double(baseline.components.attoseconds) / 1_000_000_000_000_000.0
    + Double(baseline.components.seconds) * 1000.0
  guard candidateMs > 0 else { return "N/A" }
  return String(format: "%.1fx", baselineMs / candidateMs)
}

// MARK: - BenchItem

/// A realistic item type mimicking a typical app model (e.g. a message or contact row).
/// Uses the Apple-recommended pattern: snapshots store `Item.ID` (UUID), not the full item.
/// Compiler-synthesized `Hashable`/`Equatable` — no manual overrides.
struct BenchItem: Identifiable, Hashable, Sendable {
  let id: UUID
  let title: String
  let subtitle: String
  let imageURLString: String
  let badgeCount: Int
  let isRead: Bool
}

/// Creates an array of N unique UUIDs for use as snapshot item identifiers.
func makeBenchItemIDs(_ count: Int) -> [BenchItem.ID] {
  (0 ..< count).map { _ in UUID() }
}
