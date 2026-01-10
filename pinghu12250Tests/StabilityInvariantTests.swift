//
//  StabilityInvariantTests.swift
//  pinghu12250
//
//  稳定性不变量测试
//  用于验证 Slider、JSON 解码等关键路径的安全性
//

import XCTest
@testable import pinghu12250

// MARK: - Slider 安全测试

final class SliderSafetyTests: XCTestCase {

    // MARK: - RangeGuard 测试

    func testGuardPage_ValidRange() {
        // 正常情况
        XCTAssertEqual(RangeGuard.guardPage(5, totalPages: 10), 5)
        XCTAssertEqual(RangeGuard.guardPage(1, totalPages: 100), 1)
        XCTAssertEqual(RangeGuard.guardPage(100, totalPages: 100), 100)
    }

    func testGuardPage_ZeroTotalPages() {
        // totalPages = 0 时应该返回 1
        XCTAssertEqual(RangeGuard.guardPage(1, totalPages: 0), 1)
        XCTAssertEqual(RangeGuard.guardPage(5, totalPages: 0), 1)
    }

    func testGuardPage_NegativeTotalPages() {
        // totalPages < 0 时应该返回 1
        XCTAssertEqual(RangeGuard.guardPage(1, totalPages: -1), 1)
        XCTAssertEqual(RangeGuard.guardPage(5, totalPages: -10), 1)
    }

    func testGuardPage_OutOfRange() {
        // page 超出范围时应该 clamp
        XCTAssertEqual(RangeGuard.guardPage(0, totalPages: 10), 1)
        XCTAssertEqual(RangeGuard.guardPage(-5, totalPages: 10), 1)
        XCTAssertEqual(RangeGuard.guardPage(15, totalPages: 10), 10)
        XCTAssertEqual(RangeGuard.guardPage(100, totalPages: 10), 10)
    }

    func testGuardTotalPages() {
        XCTAssertEqual(RangeGuard.guardTotalPages(10), 10)
        XCTAssertEqual(RangeGuard.guardTotalPages(1), 1)
        XCTAssertEqual(RangeGuard.guardTotalPages(0), 1)
        XCTAssertEqual(RangeGuard.guardTotalPages(-1), 1)
        XCTAssertEqual(RangeGuard.guardTotalPages(nil), 1)
    }

    func testGuardInt_ValidRange() {
        XCTAssertEqual(RangeGuard.guardInt(5, in: 1...10, default: 1), 5)
        XCTAssertEqual(RangeGuard.guardInt(nil, in: 1...10, default: 3), 3)
        XCTAssertEqual(RangeGuard.guardInt(15, in: 1...10, default: 1), 10) // clamp
        XCTAssertEqual(RangeGuard.guardInt(-5, in: 1...10, default: 1), 1)  // clamp
    }

    func testGuardDouble_NonFinite() {
        XCTAssertEqual(RangeGuard.guardDouble(Double.nan, in: 0...1, default: 0.5), 0.5)
        XCTAssertEqual(RangeGuard.guardDouble(Double.infinity, in: 0...1, default: 0.5), 0.5)
        XCTAssertEqual(RangeGuard.guardDouble(-Double.infinity, in: 0...1, default: 0.5), 0.5)
    }

    func testGuardDifficulty() {
        XCTAssertEqual(RangeGuard.guardDifficulty(3), 3)
        XCTAssertEqual(RangeGuard.guardDifficulty(nil), 3)
        XCTAssertEqual(RangeGuard.guardDifficulty(0), 1)
        XCTAssertEqual(RangeGuard.guardDifficulty(6), 5)
        XCTAssertEqual(RangeGuard.guardDifficulty(-1), 1)
    }

    func testGuardProgress() {
        XCTAssertEqual(RangeGuard.guardProgress(0.5), 0.5)
        XCTAssertEqual(RangeGuard.guardProgress(nil), 0.0)
        XCTAssertEqual(RangeGuard.guardProgress(-0.5), 0.0)
        XCTAssertEqual(RangeGuard.guardProgress(1.5), 1.0)
    }

    func testGuardFrame_InvalidDimensions() {
        let invalidFrame = CGRect(x: 0, y: 0, width: -10, height: 100)
        let defaultFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = RangeGuard.guardFrame(invalidFrame, default: defaultFrame)
        XCTAssertEqual(result, defaultFrame)
    }

    func testGuardFrame_NonFiniteDimensions() {
        let nanFrame = CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100)
        let defaultFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = RangeGuard.guardFrame(nanFrame, default: defaultFrame)
        XCTAssertEqual(result, defaultFrame)
    }
}

// MARK: - JSON 解码安全测试

final class JSONDecodeSafetyTests: XCTestCase {

    func testSafeDecodeArray_PartialFailure() {
        // 数组中部分元素无效时，应该返回有效的元素
        let json = """
        [
            {"value": "A", "text": "Option A"},
            {"invalid": "data"},
            {"value": "B", "text": "Option B"}
        ]
        """
        let data = json.data(using: .utf8)!

        struct TestOption: Codable {
            let value: String
            let text: String
        }

        let result = SafeJSONDecoder.shared.decodeArray([TestOption].self, from: data)

        // 应该返回 2 个有效元素
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].value, "A")
        XCTAssertEqual(result[1].value, "B")
    }

    func testSafeDecodeArray_AllInvalid() {
        let json = """
        [
            {"invalid": "data1"},
            {"invalid": "data2"}
        ]
        """
        let data = json.data(using: .utf8)!

        struct TestOption: Codable {
            let value: String
            let text: String
        }

        let result = SafeJSONDecoder.shared.decodeArray([TestOption].self, from: data)

        // 应该返回空数组
        XCTAssertTrue(result.isEmpty)
    }

    func testSafeDecode_WithDefault() {
        let invalidJson = "not valid json"
        let data = invalidJson.data(using: .utf8)!

        struct TestModel: Codable {
            let name: String
        }

        let defaultModel = TestModel(name: "default")
        let result = SafeJSONDecoder.shared.decode(TestModel.self, from: data, default: defaultModel)

        XCTAssertEqual(result.name, "default")
    }

    func testSafeDecode_ValidData() {
        let json = """
        {"name": "test"}
        """
        let data = json.data(using: .utf8)!

        struct TestModel: Codable {
            let name: String
        }

        let result = SafeJSONDecoder.shared.decode(TestModel.self, from: data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test")
    }

    func testSafeDecode_KeyNotFound() {
        // 测试 keyNotFound 错误
        let json = """
        {"wrongKey": "value"}
        """
        let data = json.data(using: .utf8)!

        struct TestModel: Codable {
            let requiredKey: String
        }

        let result = SafeJSONDecoder.shared.decode(TestModel.self, from: data)

        XCTAssertNil(result)
        // 验证诊断被记录
        let failures = JSONDecodeFailureStorage.shared.loadAll()
        XCTAssertFalse(failures.isEmpty)
    }
}

// MARK: - StateSanityChecker 测试

final class StateSanityCheckerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StateSanityChecker.shared.clearFatalState()
        StateSanityChecker.shared.clearCrashCount()
    }

    func testHealthyState() async {
        let result = await StateSanityChecker.shared.performStartupCheck()
        XCTAssertTrue(result.isHealthy)
    }

    func testFatalStateRecovery() async {
        // 标记致命状态
        StateSanityChecker.shared.markFatalUIState(reason: "Test fatal error")

        let result = await StateSanityChecker.shared.performStartupCheck()
        XCTAssertTrue(result.needsRecovery)

        if case .requireRecovery(let reason, _, _) = result {
            XCTAssertEqual(reason, "Test fatal error")
        } else {
            XCTFail("Expected requireRecovery result")
        }
    }

    func testConsecutiveCrashesThreshold() async {
        // 模拟多次崩溃
        for _ in 0..<3 {
            StateSanityChecker.shared.markFatalUIState(reason: "Crash \(UUID().uuidString)")
            _ = await StateSanityChecker.shared.performStartupCheck()
        }

        // 再次标记并检查
        StateSanityChecker.shared.markFatalUIState(reason: "Final crash")
        let result = await StateSanityChecker.shared.performStartupCheck()

        if case .requireFullReset = result {
            // 预期结果
        } else {
            XCTFail("Expected requireFullReset after multiple crashes")
        }
    }

    func testDangerousAreaMarking() {
        StateSanityChecker.shared.markDangerousEntry(screen: "TestScreen", context: "TestContext")

        // 不能直接测试内部状态，但可以验证不会崩溃
        StateSanityChecker.shared.markSafeExit()
    }
}

// MARK: - HeavyOperationGuard 测试

final class HeavyOperationGuardTests: XCTestCase {

    func testPerformHeavyOperation_Success() async {
        let result = await HeavyOperationGuard.shared.performHeavyOperation(
            name: "TestOp",
            timeout: 5
        ) {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            return "Success"
        }

        switch result {
        case .success(let value):
            XCTAssertEqual(value, "Success")
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testPerformHeavyOperation_Timeout() async {
        let result = await HeavyOperationGuard.shared.performHeavyOperation(
            name: "TestOp",
            timeout: 0.1
        ) {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
            return "Should not reach"
        }

        switch result {
        case .success:
            XCTFail("Expected timeout")
        case .failure(let error):
            XCTAssertEqual(error, .timeout)
        }
    }

    func testCameraPermissionCheck() async {
        // 这个测试在模拟器上可能会失败，因为没有真实的相机
        let result = await HeavyOperationGuard.shared.checkCameraPermissionSafely()
        // 只验证不会崩溃
        XCTAssertNotNil(result)
    }
}

// MARK: - SliderDiagnostics 测试

final class SliderDiagnosticsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SliderDiagnostics.shared.clear()
    }

    func testRecordInvalidRange() {
        SliderDiagnostics.recordInvalidRange(min: 10, max: 5, step: 1)

        let diagnostics = SliderDiagnostics.shared.getAllDiagnostics()
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].type, "invalid_range")
    }

    func testRecordInvalidStep() {
        SliderDiagnostics.recordInvalidStep(0)
        SliderDiagnostics.recordInvalidStep(-1)

        let diagnostics = SliderDiagnostics.shared.getAllDiagnostics()
        XCTAssertEqual(diagnostics.count, 2)
    }

    func testDiagnosticsLimit() {
        // 验证诊断记录数量限制
        for i in 0..<100 {
            SliderDiagnostics.recordInvalidRange(min: Double(i), max: 0, step: nil)
        }

        let diagnostics = SliderDiagnostics.shared.getAllDiagnostics()
        XCTAssertLessThanOrEqual(diagnostics.count, 50) // maxCount = 50
    }
}
