//
//  StatusStateMachineTests.swift
//  SonarTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import Sonar

class StatusStateMachineTests: XCTestCase {

    var machine: StatusStateMachine!
    var persisting: PersistenceDouble!
    var currentDate: Date!

    override func setUp() {
        persisting = PersistenceDouble()
        machine = StatusStateMachine(
            persisting: persisting,
            dateProvider: self.currentDate
        )
    }

    func testDefaultIsOk() {
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))
    }

    func testOkToSymptomatic() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 6))!
        machine.selfDiagnose(symptoms: [.cough], startDate: startDate)

        XCTAssertEqual(machine.state, .symptomatic(StatusState.Symptomatic(symptoms: [.cough], startDate: startDate)))
    }

    func testTickFromSymptomaticToCheckin() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        let symptomatic = StatusState.Symptomatic(symptoms: [.cough], startDate: startDate)
        persisting.statusState = .symptomatic(symptomatic)

        currentDate = Calendar.current.date(byAdding: .hour, value: -1, to: symptomatic.expiryDate)!
        machine.tick()
        XCTAssertTrue(machine.state.isSymptomatic)

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: symptomatic.expiryDate)!
        machine.tick()
        guard case .checkin(let checkin) = machine.state else {
            XCTFail()
            return
        }

        XCTAssertEqual(checkin.checkinDate, symptomatic.expiryDate)
    }

    func testTickWhenExposedBeforeSeven() {
        let exposureDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 6))!
        let expiry = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 14, hour: 7))!
        persisting.statusState = .exposed(StatusState.Exposed(exposureDate: exposureDate))

        currentDate = Calendar.current.date(byAdding: .hour, value: -1, to: expiry)!
        machine.tick()
        XCTAssertTrue(machine.state.isExposed)

        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: expiry)!
        machine.tick()
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))
    }

    func testTickWhenExposedAfterSeven() {
        let exposureDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 8))!
        let expiry = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 15, hour: 7))!
        persisting.statusState = .exposed(StatusState.Exposed(exposureDate: exposureDate))

        currentDate = Calendar.current.date(byAdding: .hour, value: -1, to: expiry)!
        machine.tick()
        XCTAssertTrue(machine.state.isExposed)

        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: expiry)!
        machine.tick()
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))
    }

    func testCheckinOnlyCough() {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: checkinAt)!
        machine.checkin(symptoms: [.cough])
        XCTAssertEqual(machine.state, .ok(StatusState.Ok()))
    }

    func testCheckinOnlyTemperature() {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: checkinAt)!
        machine.checkin(symptoms: [.temperature])

        let nextCheckin = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2, hour: 7))!
        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: nextCheckin)))
    }

    func testCheckinBothCoughAndTemperature() {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        currentDate = Calendar.current.date(byAdding: .hour, value: 1, to: checkinAt)!
        machine.checkin(symptoms: [.cough, .temperature])

        let nextCheckin = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2, hour: 7))!
        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.cough, .temperature], checkinDate: nextCheckin)))
    }

    func testCheckinWithTemperatureAfterMultipleDays() {
        let checkinAt = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1, hour: 7))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.cough], checkinDate: checkinAt))

        // 2020.04.04
        currentDate = Calendar.current.date(byAdding: .day, value: 3, to: checkinAt)!
        machine.checkin(symptoms: [.temperature])

        let nextCheckin = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 5, hour: 7))!
        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: nextCheckin)))
    }

    func testIgnoreExposedWhenSymptomatic() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1))!
        persisting.statusState = .symptomatic(StatusState.Symptomatic(symptoms: [.cough], startDate: startDate))

        currentDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2))!
        machine.exposed()

        XCTAssertEqual(machine.state, .symptomatic(StatusState.Symptomatic(symptoms: [.cough], startDate: startDate)))
    }

    func testIgnoreExposedWhenCheckingIn() {
        let checkinDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 1))!
        persisting.statusState = .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: checkinDate))

        currentDate = Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 2))!
        machine.exposed()

        XCTAssertEqual(machine.state, .checkin(StatusState.Checkin(symptoms: [.temperature], checkinDate: checkinDate)))
    }

}