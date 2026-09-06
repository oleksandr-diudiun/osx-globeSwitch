import AppKit
import Carbon.HIToolbox
import ObjectiveC.runtime

@MainActor
final class SystemInputSourceIconProvider {
    private typealias ImageFunction = @convention(c) (
        AnyObject,
        Selector,
        AnyObject
    ) -> Unmanaged<AnyObject>?

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/KeyboardLayouts.framework"
    private static let managerClassName = "KLInputSourceIconManager"
    private static let imageSelector = NSSelectorFromString("titleImageForTISInputSource:")

    private let manager: NSObject?
    private let imageFunction: ImageFunction?
    private var imageCache: [String: NSImage] = [:]

    init() {
        guard let framework = Bundle(path: Self.frameworkPath),
              framework.load(),
              let managerType = NSClassFromString(Self.managerClassName) as? NSObject.Type,
              let method = class_getInstanceMethod(managerType, Self.imageSelector) else {
            manager = nil
            imageFunction = nil
            return
        }

        manager = managerType.init()
        imageFunction = unsafeBitCast(
            method_getImplementation(method),
            to: ImageFunction.self
        )
    }

    func image(for sourceID: String) -> NSImage? {
        if let cached = imageCache[sourceID] {
            return cached
        }

        guard let manager,
              let imageFunction,
              let inputSource = inputSource(withID: sourceID),
              let systemImage = imageFunction(
                  manager,
                  Self.imageSelector,
                  inputSource
              )?.takeUnretainedValue() as? NSImage else {
            return nil
        }

        let image = (systemImage.copy() as? NSImage) ?? systemImage
        image.isTemplate = true
        imageCache[sourceID] = image
        return image
    }

    private func inputSource(withID id: String) -> TISInputSource? {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceID: id,
            kTISPropertyInputSourceIsEnabled: true,
            kTISPropertyInputSourceIsSelectCapable: true
        ]
        guard let sources = TISCreateInputSourceList(filter as CFDictionary, false),
              let inputSources = sources.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        return inputSources.first
    }
}
