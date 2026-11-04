import Testing
@testable import MacDockShared

struct FoundationInfoTests {
    @Test
    func currentFoundationMetadataIsStable() {
        #expect(MacDockFoundationInfo.current.productVersion == "0.1.0")
        #expect(MacDockFoundationInfo.current.stage == "Foundation")
        #expect(MacDockFoundationInfo.current.stageLabel == "Stage: Foundation")
    }

    @Test
    func foundationMetadataSupportsValueEquality() {
        let first = MacDockFoundationInfo(productVersion: "0.1.0", stage: "Foundation")
        let second = MacDockFoundationInfo(productVersion: "0.1.0", stage: "Foundation")

        #expect(first == second)
    }
}
