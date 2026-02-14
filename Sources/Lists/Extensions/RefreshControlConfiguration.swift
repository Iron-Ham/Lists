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
  if onRefresh != nil, collectionView.refreshControl == nil {
    let refreshControl = UIRefreshControl()
    refreshControl.addTarget(target, action: action, for: .valueChanged)
    collectionView.refreshControl = refreshControl
  } else if onRefresh == nil {
    collectionView.refreshControl = nil
  }
}
