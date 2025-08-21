import XCTest
@testable import BobCamAgent

final class BobCamAgentTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testVisionServiceInitialization() throws {
        // Test VisionService can be initialized
        let visionService = VisionService()
        XCTAssertNotNil(visionService)
        XCTAssertEqual(visionService.serviceState, .idle)
    }
    
    func testCameraServiceInitialization() throws {
        // Test CameraService can be initialized
        let cameraService = CameraService()
        XCTAssertNotNil(cameraService)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
