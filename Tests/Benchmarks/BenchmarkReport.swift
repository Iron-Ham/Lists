import Foundation
import ListKit
import Testing
import UIKit

/// Generates a markdown benchmark report comparing ListKit vs Apple's NSDiffableDataSourceSnapshot.
/// Results are written to /tmp/listkit_benchmark_results.txt.
struct BenchmarkReport {
  @Test
  func generateReport() throws {
    var lines = [String]()
    func log(_ s: String) {
      lines.append(s)
    }

    log("| Operation | ListKit | Apple | Speedup |")
    log("|:---|---:|---:|---:|")

    // Build 10k
    let items10k = Array(0 ..< 10000)
    let lk10k = benchmark {
      var s = DiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(items10k, toSection: "main")
    }
    let ap10k = benchmark {
      var s = NSDiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(items10k, toSection: "main")
    }
    log("| Build 10k items | \(ms(lk10k)) ms | \(ms(ap10k)) ms | **\(speedup(lk10k, ap10k))** |")

    // Build 50k
    let items50k = Array(0 ..< 50000)
    let lk50k = benchmark {
      var s = DiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(items50k, toSection: "main")
    }
    let ap50k = benchmark {
      var s = NSDiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(items50k, toSection: "main")
    }
    log("| Build 50k items | \(ms(lk50k)) ms | \(ms(ap50k)) ms | **\(speedup(lk50k, ap50k))** |")

    // Build 100 sections × 100 items
    let lkMulti = benchmark {
      var s = DiffableDataSourceSnapshot<Int, Int>()
      var c = 0
      for sec in 0 ..< 100 {
        s.appendSections([sec])
        s.appendItems(Array(c ..< c + 100), toSection: sec)
        c += 100
      }
    }
    let apMulti = benchmark {
      var s = NSDiffableDataSourceSnapshot<Int, Int>()
      var c = 0
      for sec in 0 ..< 100 {
        s.appendSections([sec])
        s.appendItems(Array(c ..< c + 100), toSection: sec)
        c += 100
      }
    }
    log("| Build 100 sections x 100 | \(ms(lkMulti)) ms | \(ms(apMulti)) ms | **\(speedup(lkMulti, apMulti))** |")

    // Delete 5k from 10k
    let delItems = Array(0 ..< 10000)
    let delTarget = Array(0 ..< 5000)
    let lkDel = benchmark {
      var s = DiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(delItems, toSection: "main")
      s.deleteItems(delTarget)
    }
    let apDel = benchmark {
      var s = NSDiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(delItems, toSection: "main")
      s.deleteItems(delTarget)
    }
    log("| Delete 5k from 10k | \(ms(lkDel)) ms | \(ms(apDel)) ms | **\(speedup(lkDel, apDel))** |")

    // Delete 25 sections from 50
    let lkDelSec = benchmark {
      var s = DiffableDataSourceSnapshot<Int, Int>()
      for sec in 0 ..< 50 {
        s.appendSections([sec])
        s.appendItems(Array(sec * 100 ..< sec * 100 + 100), toSection: sec)
      }
      s.deleteSections(stride(from: 0, to: 50, by: 2).map(\.self))
    }
    let apDelSec = benchmark {
      var s = NSDiffableDataSourceSnapshot<Int, Int>()
      for sec in 0 ..< 50 {
        s.appendSections([sec])
        s.appendItems(Array(sec * 100 ..< sec * 100 + 100), toSection: sec)
      }
      s.deleteSections(stride(from: 0, to: 50, by: 2).map(\.self))
    }
    log("| Delete 25/50 sections | \(ms(lkDelSec)) ms | \(ms(apDelSec)) ms | **\(speedup(lkDelSec, apDelSec))** |")

    // Reload 5k
    let rlItems = Array(0 ..< 10000)
    let rlTarget = Array(0 ..< 5000)
    let lkRl = benchmark {
      var s = DiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(rlItems, toSection: "main")
      s.reloadItems(rlTarget)
    }
    let apRl = benchmark {
      var s = NSDiffableDataSourceSnapshot<String, Int>()
      s.appendSections(["main"])
      s.appendItems(rlItems, toSection: "main")
      s.reloadItems(rlTarget)
    }
    log("| Reload 5k items | \(ms(lkRl)) ms | \(ms(apRl)) ms | **\(speedup(lkRl, apRl))** |")

    // Query itemIdentifiers 100x on 5k
    var lkSnap = DiffableDataSourceSnapshot<String, Int>()
    lkSnap.appendSections(["main"])
    lkSnap.appendItems(Array(0 ..< 5000), toSection: "main")
    var apSnap = NSDiffableDataSourceSnapshot<String, Int>()
    apSnap.appendSections(["main"])
    apSnap.appendItems(Array(0 ..< 5000), toSection: "main")
    let lkQ = benchmark { for _ in 0 ..< 100 {
      _ = lkSnap.itemIdentifiers
    } }
    let apQ = benchmark { for _ in 0 ..< 100 {
      _ = apSnap.itemIdentifiers
    } }
    log("| Query itemIdentifiers 100x | \(ms(lkQ)) ms | \(ms(apQ)) ms | **\(speedup(lkQ, apQ))** |")

    let output = lines.joined(separator: "\n")
    let path = "/tmp/listkit_benchmark_results.txt"
    try output.write(toFile: path, atomically: true, encoding: .utf8)
  }
}
