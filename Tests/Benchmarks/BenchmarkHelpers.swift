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
  let us = Double(d.components.attoseconds) / 1_000_000_000_000_000.0
    + Double(d.components.seconds) * 1000.0
  return String(format: "%.3f", us)
}

/// Computes the speedup ratio of `baseline` over `candidate`.
func speedup(_ candidate: Duration, _ baseline: Duration) -> String {
  let ratio = Double(baseline.components.attoseconds) / Double(candidate.components.attoseconds)
  return String(format: "%.1fx", ratio)
}
