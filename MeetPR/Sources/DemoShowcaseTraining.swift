#if DEMO_MODE && DEMO_USER_STUDENT
  import CoreModels
  import Foundation

  /// A single pass creates the prescription and its actual sets with matching slot identities.
  struct DemoShowcaseTraining {
    let plan: StudentPlanView
    let logs: [StudentSetLog]

    init(today: Date) {
      var days: [StudentPlanDay] = []
      var logs: [StudentSetLog] = []
      for session in 0..<48 {
        days.append(Self.trainingDay(session: session, today: today, logs: &logs))
      }
      let cycleID = DemoShowcase.id(3)
      self.logs = logs
      self.plan = StudentPlanView(
        cycleID: cycleID,
        handoff: .init(
          currentPlanID: cycleID,
          plans: [
            .init(
              id: cycleID, name: "省赛备赛周期", weeks: 12, completedTrainingDays: 25,
              totalTrainingDays: days.count, status: .current)
          ]),
        weekIndex: 7, startDate: days[0].date,
        endDate: DemoShowcase.planDate(DemoShowcase.day(39, from: today)),
        publishedAt: DemoShowcase.day(-45, from: today), days: days)
    }

    private static func trainingDay(session: Int, today: Date, logs: inout [StudentSetLog])
      -> StudentPlanDay
    {
      let week = session / 4 + 1
      let slot = session % 4
      let date = DemoShowcase.day((week - 1) * 7 + [0, 2, 4, 6][slot] - 44, from: today)
      let completed = session < 25
      let movements = Movement.schedule[slot]
      var exercises: [StudentPlanExercise] = []
      for (index, movement) in movements.enumerated() {
        let row = session * 10 + index
        let exercise = movement.exercise(created: DemoShowcase.day(-120, from: today))
        let work = movement.work(week: week)
        var sets: [PrescribedSet] = []
        for setIndex in 0..<work.count {
          let key = row * 10 + setIndex
          sets.append(work.set(key: key, setIndex: setIndex, movement: movement))
          if completed {
            let short = index > 1 && setIndex == 1 && session % 9 == 3
            let harder = index > 0 && setIndex == work.count - 1 && session % 3 == 0
            logs.append(
              StudentSetLog(
                id: DemoShowcase.id(40_000 + key), studentID: DemoShowcase.studentID,
                planExerciseID: DemoShowcase.id(1_000 + row), exerciseID: exercise.id,
                setIndex: setIndex,
                loggedAt: date.addingTimeInterval(
                  Double(18 * 3600 + index * 660 + setIndex * 160)),
                weightKg: work.weightKg, reps: work.reps - (short ? 1 : 0),
                rpe: work.rpe + (harder ? 0.5 : 0), completed: true, failed: short))
          }
        }
        exercises.append(
          StudentPlanExercise(
            id: DemoShowcase.id(1_000 + row), exercise: exercise, sequenceIndex: index,
            prescribedSets: sets,
            notes: session == 25 && index == 0 ? "脚跟踩稳，杠铃在胸口停稳再推。今天前三组留两次余力。" : nil))
      }
      return StudentPlanDay(
        id: DemoShowcase.id(100 + session), weekNumber: week, dayOfWeek: slot + 1,
        sortOrder: session, date: DemoShowcase.planDate(date),
        completedAt: completed ? date.addingTimeInterval(19 * 3600) : nil,
        completionSource: completed ? "manual" : nil, exercises: exercises)
    }
  }

  private enum Movement: Int {
    case squat, bench, deadlift, pauseSquat, closeBench, deficitPull
    case splitSquat, row, legCurl, pushdown, facePull

    static let schedule: [[Self]] = [
      [.squat, .pauseSquat, .splitSquat, .legCurl],
      [.bench, .closeBench, .row, .pushdown, .facePull],
      [.deadlift, .deficitPull, .row, .legCurl],
      [.bench, .pauseSquat, .splitSquat, .facePull],
    ]

    var family: LiftFamily? {
      switch self {
      case .squat, .pauseSquat: .squat
      case .bench, .closeBench: .bench
      case .deadlift, .deficitPull: .deadlift
      default: nil
      }
    }

    func exercise(created: Date) -> Exercise {
      let names = [
        "低杠深蹲", "竞技卧推", "相扑硬拉", "暂停深蹲", "窄握卧推", "赤字硬拉",
        "保加利亚分腿蹲", "哑铃划船", "俯卧腿弯举", "绳索下压", "绳索面拉",
      ]
      let muscles: [MuscleGroup] = [
        .quad, .chest, .glute, .quad, .triceps, .hamstring,
        .quad, .back, .hamstring, .triceps, .shoulder,
      ]
      let equipment: Equipment
      switch self {
      case .splitSquat, .row: equipment = .dumbbell
      case .legCurl: equipment = .machine
      case .pushdown, .facePull: equipment = .cable
      default: equipment = .barbell
      }
      let main = self == .squat || self == .bench || self == .deadlift
      return Exercise(
        id: DemoShowcase.id(50 + rawValue), name: names[rawValue],
        exerciseType: main ? .mainLift : (family == nil ? .accessory : .mainLiftVariation),
        mainLiftFamily: family, isCompetitionLift: main,
        competitionStance: self == .squat ? .lowBar : (self == .deadlift ? .sumo : nil),
        muscleGroups: [muscles[rawValue]], equipment: [equipment], createdAt: created)
    }

    func work(week: Int) -> Work {
      let light = week == 4 || week == 12
      let reps = week <= 4 ? 5 : (week <= 8 || week == 12 ? 3 : 1)
      let rpe: Decimal = week <= 2 ? 7 : (week == 12 ? 6 : (week == 11 ? 9 : 8))
      // Plate-loaded primary lifts. W4 keeps the five-rep exposure and halves the volume.
      let loads: [Decimal]
      switch self {
      case .squat: loads = [150, 152.5, 157.5, 160, 172.5, 175, 175, 177.5, 190, 192.5, 197.5, 140]
      case .bench: loads = [97.5, 100, 102.5, 102.5, 112.5, 112.5, 115, 115, 122.5, 125, 127.5, 90]
      case .deadlift:
        loads = [182.5, 185, 192.5, 192.5, 207.5, 210, 210, 212.5, 225, 230, 235, 165]
      default:
        let base: [Decimal] = [140, 85, 150, 20, 32.5, 40, 30, 17.5]
        let weightKg = base[rawValue - Movement.pauseSquat.rawValue]
        return Work(
          weightKg: weightKg, reps: family == nil ? 10 : 5, rpe: light ? 6 : 7,
          count: light ? 1 : (week > 8 ? 2 : 3))
      }
      return Work(
        weightKg: loads[week - 1], reps: reps, rpe: rpe, count: light ? 2 : (week > 8 ? 3 : 4))
    }
  }

  private struct Work {
    let weightKg: Decimal
    let reps: Int
    let rpe: Decimal
    let count: Int

    func set(key: Int, setIndex: Int, movement: Movement) -> PrescribedSet {
      // Paused squat uses the registered 205 weightKg anchor. Close-grip bench is autoregulated.
      let percent = movement == .pauseSquat
      let flexible = movement == .closeBench
      return PrescribedSet(
        id: DemoShowcase.id(10_000 + key), setIndex: setIndex,
        weightKg: percent || flexible ? nil : weightKg,
        intensity: percent ? .percentage(68) : .rpe(rpe),
        loadMode: percent ? .percentage : (flexible ? .rpe : .fixedWeight),
        reps: reps, restSeconds: movement.family == nil ? 75 : 180)
    }
  }
#endif
