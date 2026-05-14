//
//  Bundle+Localization.swift
//  Gangio
//
//  Runtime in-app language switching by swizzling `Bundle.main` to read
//  strings from a per-language sub-bundle. This makes Text("Some key") and
//  String(localized:) honor the user's selected language without restarting.
//

import Foundation
import ObjectiveC

private var bundleKey: UInt8 = 0

private final class GangioLocalizationBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Call this once at app launch to upgrade `Bundle.main`'s class so we can
    /// override its localization lookup.
    static func enableInAppLocalization() {
        object_setClass(Bundle.main, GangioLocalizationBundle.self)
    }
    
    /// Switch the in-app localization bundle to a specific language code
    /// (e.g. "en" or "tr"). Pass `nil` to revert to system default.
    static func setInAppLanguage(_ languageCode: String?) {
        guard object_getClass(Bundle.main) == GangioLocalizationBundle.self else {
            // Should not happen if `enableInAppLocalization()` was called.
            return
        }
        
        if let code = languageCode,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            objc_setAssociatedObject(Bundle.main, &bundleKey, langBundle, .OBJC_ASSOCIATION_RETAIN)
        } else {
            objc_setAssociatedObject(Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
