import UniformTypeIdentifiers

extension UTType {
    /// Matches the `com.multipathstorytool.story` UTI exported in Info.plist
    /// (see project.yml), tagged with the `.mpstory` file extension and
    /// conforming to `com.apple.package` (`UTType.package`) — SwiftData's
    /// DocumentGroup validates this conformance at runtime and crashes on
    /// launch if the document type conforms to `public.package` instead.
    static var storyDocument: UTType {
        UTType(exportedAs: "com.multipathstorytool.story")
    }
}
