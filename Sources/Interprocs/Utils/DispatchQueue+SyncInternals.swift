import Foundation

extension DispatchQueue {
    static var distributedSync: DispatchQueue { .init(label: "com.libInterprocs.0x12fdead") }
}
