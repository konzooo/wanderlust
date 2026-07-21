import Foundation

public protocol DrawerNavigating: AnyObject {
    func processDrawerSelection(_ row: DrawerRow)
} 