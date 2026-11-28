#if DEMO_MODE && DEMO_USER_STUDENT
  import CoreModels
  import Foundation
  import StudentKit

  struct DemoShowcase {
    // A separate identity also isolates per-student drafts, badges and migration markers.
    static let studentID = ShowcaseChartHistory.studentID
    static let coachID = id(2)
    static let coachName = "周砚"
    let today: Date
    let plan: StudentPlanView
    let logs: [StudentSetLog]
    let points: [E1RMHistoryPoint]
    let videoURL: URL?

    static func launch(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
      guard arguments.contains("-demo-showcase") else { return nil }
      let path = arguments.firstIndex(of: "-demo-showcase-video").flatMap {
        arguments.dropFirst($0 + 1).first
      }
      return Self(
        today: Date(), videoURL: path.flatMap { $0.hasPrefix("/") ? URL(filePath: $0) : nil })
    }

    init(today: Date, videoURL: URL? = nil) {
      self.today = Calendar.current.startOfDay(for: today)
      self.videoURL =
        videoURL ?? Bundle.main.url(forResource: "coach-demo-video", withExtension: "mp4")
      let training = DemoShowcaseTraining(today: self.today)
      plan = training.plan
      logs = training.logs
      points = Self.estimates(training: training, today: self.today)
    }

    static func id(_ number: Int) -> UUID {
      UUID(
        uuid: (
          0x27, 0x11, 0x26, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0,
          UInt8(truncatingIfNeeded: number >> 16), UInt8(truncatingIfNeeded: number >> 8),
          UInt8(truncatingIfNeeded: number)
        ))
    }

    static func day(_ offset: Int, from anchor: Date) -> Date {
      guard let result = Calendar.current.date(byAdding: .day, value: offset, to: anchor) else {
        preconditionFailure("无效的训练日期")
      }
      return result
    }

    static var utcCalendar: Calendar {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      return calendar
    }

    // The plan API carries date-only fields as UTC midnight. Logs use local gym time.
    static func planDate(_ deviceDay: Date) -> Date {
      let parts = Calendar(identifier: .gregorian).dateComponents(
        [.year, .month, .day], from: deviceDay)
      guard let date = utcCalendar.date(from: parts) else { preconditionFailure("无效的计划日期") }
      return date
    }

    static func dayString(_ date: Date) -> String {
      date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }

    private var birthDate: Date { Self.day(-9_625, from: today) }

    var user: User {
      User(
        id: Self.studentID, phone: "+86 138 0000 0000", name: "陈屿", gender: .male,
        birthDate: birthDate,
        heightCm: 178, weightKg: 83, unitSystem: .metric, role: .coachedStudent,
        createdAt: Self.day(-120, from: today), updatedAt: today)
    }

    var profile: OnboardingProfile {
      let prior = Self.day(-120, from: today)
      let weekdays: [TrainingDay] = [.sun, .mon, .tue, .wed, .thu, .fri, .sat]
      return OnboardingProfile(
        userId: Self.studentID, unitPreference: .kg, gender: .male,
        birthDate: Self.dayString(birthDate),
        heightCm: 178, weightKg: 83, trainingYears: 4, squatStance: .lowBar,
        deadliftStyle: .sumo, benchGrip: .standard, squat1RMKg: 205, bench1RMKg: 132.5,
        deadlift1RMKg: 245,
        trainingDays: plan.days.prefix(4).map {
          weekdays[Self.utcCalendar.component(.weekday, from: $0.date) - 1]
        },
        gymTier: .commercial, dailyLifeIntensity: 3, lifeStress: 2, recoverySpeed: 4, sleepHours: 4,
        injuryNotes: "左膝髌腱不适，已恢复。", injuryAreas: [.knee], isCompeting: true,
        competitionDate: Self.dayString(Self.day(38, from: today)),
        targetWeightClass: "2027 浙江省力量举锦标赛 · 83kg",
        noteToCoach: "这次想把三项开把都做稳。", completedAt: prior, createdAt: prior, updatedAt: today)
    }

    var binding: BindRequest {
      BindRequest(
        id: Self.id(4), studentId: Self.studentID, coachId: Self.coachID,
        coachDisplayName: Self.coachName, inviteCodeId: Self.id(5), status: .accepted,
        submittedAt: Self.day(-96, from: today), respondedAt: Self.day(-95, from: today),
        expiredAt: Self.day(-89, from: today))
    }

    var bodyWeights: [String: Decimal] {
      var result: [String: Decimal] = [:]
      for ago in 0..<90 where ago % 7 == 0 || ago % 7 == 3 {
        let progress = Double(ago) / 89
        // One gentle wave over the full window varies the pace of the decline.
        let variation = 0.1 * sin(2 * .pi * progress)
        let tenths = 830 + Int(((progress + variation) * 10).rounded())
        result[Self.dayString(Self.day(-ago, from: today))] = Decimal(tenths) / 10
      }
      return result
    }

    var records: [PRBreakthroughEvent] {
      let squat = points.filter { $0.family == .squat && $0.origin == .logged }
      let weekSix = plan.days[20].date
      guard let point = squat.first(where: { $0.computedAt >= weekSix }),
        let previous = squat.last(where: { $0.computedAt < weekSix }),
        point.sourceWeightKg > previous.sourceWeightKg
      else { return [] }
      return [
        PRBreakthroughEvent(
          id: Self.id(8), studentId: Self.studentID, exerciseId: point.exerciseId, family: .squat,
          setLogId: point.setLogId, pointId: point.id, breakthroughE1RMKg: point.e1RMKg,
          previousMaxE1RMKg: previous.e1RMKg, breakthroughWeightKg: point.sourceWeightKg,
          previousMaxWeightKg: previous.sourceWeightKg, occurredAt: point.computedAt,
          acknowledgedAt: point.computedAt)
      ]
    }

    private static func estimates(training: DemoShowcaseTraining, today: Date) -> [E1RMHistoryPoint]
    {
      let primary = training.plan.days.prefix(3).map { $0.exercises[0].exercise }
      let familyByID = Dictionary(
        uniqueKeysWithValues: primary.compactMap { exercise in
          exercise.mainLiftFamily.map { (exercise.id, $0) }
        })
      var points: [E1RMHistoryPoint] = []
      for (index, exercise) in primary.enumerated() {
        for (period, daysAgo) in [111, 83, 60].enumerated() {
          let value: Double = [188, 122, 227][index] + Double(period) * 1.5
          let key = 60_000 + index * 10 + period
          points.append(
            E1RMHistoryPoint(
              id: id(key), studentId: studentID, exerciseId: exercise.id,
              family: exercise.mainLiftFamily,
              setLogId: id(key + 100), computedAt: day(-daysAgo, from: today), e1RMKg: value,
              sourceWeightKg: value, sourceReps: 1, sourceRPE: 10, origin: .imported))
        }
      }
      for log in training.logs {
        guard let exerciseID = log.exerciseID, let family = familyByID[exerciseID],
          let kilograms = log.weightKg, let rpe = log.rpe
        else { continue }
        let weight = NSDecimalNumber(decimal: kilograms).doubleValue
        let effort = NSDecimalNumber(decimal: rpe).doubleValue
        guard let value = E1RMCalculator.calculate(weightKg: weight, reps: log.reps, rpe: effort)
        else { continue }
        points.append(
          E1RMHistoryPoint(
            id: log.id, studentId: studentID, exerciseId: exerciseID, family: family,
            setLogId: log.id, computedAt: log.loggedAt, e1RMKg: value, sourceWeightKg: weight,
            sourceReps: log.reps, sourceRPE: effort))
      }
      return points
    }
  }
#endif
