// ABOUTME: Pull-to-refresh support for UIKit list configurations.
// ABOUTME: RefreshControlManager owns the async refresh lifecycle and spinner dismissal.
import UIKit

/// Configures a `UIRefreshControl` on a collection view when `onRefresh` is non-nil,
/// or removes it when `onRefresh` is nil.
@MainActor
func configureRefreshControl(
  on collectionView: UICollectionView,
  onRefresh: (@MainActor () async -> Void)?,
  target: AnyObject,
  action: Selector
) {
  // UIRefreshControl is unsupported on Mac Catalyst in the Mac idiom; assigning one crashes.
  // UIDevice.current.userInterfaceIdiom is process-level and returns .mac for Mac idiom,
  // unlike behavioralStyle which requires the view to be in a window to resolve correctly.
  #if targetEnvironment(macCatalyst)
  guard UIDevice.current.userInterfaceIdiom != .mac else { return }
  #endif

  if onRefresh != nil, collectionView.refreshControl == nil {
    let refreshControl = UIRefreshControl()
    refreshControl.addTarget(target, action: action, for: .valueChanged)
    collectionView.refreshControl = refreshControl
  } else if onRefresh == nil {
    collectionView.refreshControl = nil
  }
}

// MARK: - RefreshControlManager

/// Manages pull-to-refresh lifecycle for UIKit list configurations.
///
/// Owns the `onRefresh` closure and the in-flight `refreshTask`, installs/removes a
/// `UIRefreshControl` on the collection view, and ensures the spinner is dismissed
/// and the task reference is cleaned up on every code path.
@MainActor
final class RefreshControlManager {

  // MARK: Internal

  /// The async closure invoked when the user pulls to refresh.
  /// Setting this installs or removes the refresh control on the associated collection view.
  var onRefresh: (@MainActor () async -> Void)? {
    didSet { configureIfNeeded() }
  }

  /// Associates this manager with a collection view. Must be called before setting `onRefresh`.
  func attach(to collectionView: UICollectionView) {
    self.collectionView = collectionView
  }

  /// Cancels any in-flight refresh task. Call from the owning configuration's `deinit`.
  ///
  /// `Task.cancel()` is thread-safe and nonisolated, so we store the task handle as
  /// `nonisolated(unsafe)` to allow direct cancellation from `deinit` without
  /// `MainActor.assumeIsolated` (which would trap if `deinit` fires off-main).
  nonisolated func cancel() {
    _refreshTask?.cancel()
  }

  // MARK: Private

  private weak var collectionView: UICollectionView?
  /// Backing storage for the in-flight refresh task, accessed as `refreshTask` on the main actor
  /// and as `_refreshTask` from `nonisolated cancel()`. Safe because `cancel()` only calls
  /// `Task.cancel()` which is itself thread-safe.
  private nonisolated(unsafe) var _refreshTask: Task<Void, Never>?

  private var refreshTask: Task<Void, Never>? {
    get { _refreshTask }
    set { _refreshTask = newValue }
  }

  private func configureIfNeeded() {
    guard let collectionView else { return }
    #if targetEnvironment(macCatalyst)
    guard UIDevice.current.userInterfaceIdiom != .mac else { return }
    #endif
    if onRefresh != nil, collectionView.refreshControl == nil {
      let refreshControl = UIRefreshControl()
      refreshControl.addAction(UIAction { [weak self] _ in
        guard let self, let onRefresh, refreshTask == nil else { return }
        refreshTask = Task { @MainActor [weak self] in
          defer {
            refreshControl.endRefreshing()
            self?.refreshTask = nil
          }
          await onRefresh()
        }
      }, for: .valueChanged)
      collectionView.refreshControl = refreshControl
    } else if onRefresh == nil {
      collectionView.refreshControl = nil
    }
  }
}
