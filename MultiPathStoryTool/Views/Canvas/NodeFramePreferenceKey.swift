import CoreGraphics
import Foundation
import SwiftUI

/// Collects each rendered `NodeView`'s frame (in the shared "canvas"
/// coordinate space) so `ConnectorsCanvas` can derive edge geometry. Needed
/// because node height grows with passage text and can't be predicted
/// analytically.
struct NodeFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
