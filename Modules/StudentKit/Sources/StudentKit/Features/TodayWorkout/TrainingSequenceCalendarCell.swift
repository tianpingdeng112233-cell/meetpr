import Foundation

enum TrainingSequenceCalendarCell: Equatable, Identifiable, Sendable {
  case training(TrainingSequenceDay)
  case rest(Date)

  enum Identity: Hashable, Sendable {
    case training(UUID)
    case rest(Date)
  }

  var id: Identity {
    switch self {
    case .training(let item): .training(item.id)
    case .rest(let date): .rest(date)
    }
  }

  var date: Date {
    switch self {
    case .training(let item): item.day.date
    case .rest(let date): date
    }
  }

  var trainingDay: TrainingSequenceDay? {
    if case .training(let item) = self { return item }
    return nil
  }
}
