import Testing
@testable import Interprocs

struct IdHasherTests {
    @Test("All string values have correct sha256 hash outputs", arguments: [
        ("", "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="),
        ("bla", "TfPD9o/Mg7J+nULJBDGnJJnxeHXIGlmbVmyYiblpZwM="),
        ("skdjfniueucxs auof38k12kjfvs08vj 1q2jdfcspa f8529rj fjsndk842u80", "kW0Auip2Zf4/YLaE17eu08A6WpYT0FghXNdX1KWlZsk="),
        ("s9of8sf32 k auof38k12kjfvs08vj 1q2jdfcspa f8529rj we08f fjsndk842u80", "7o1VBp+bPjsK9ISLa558tJw4/rQwxs+DmEw+bF2bdVM="),
    ])
    func correctStringSHA256(_ input: String, _ expectedHash: String) async throws {
        let result = IdHasher(value: input).stringValue
        try #require(result == expectedHash)
    }
}
