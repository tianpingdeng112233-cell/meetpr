import CoreModels
import Foundation

enum LoopJSONCodec {
  static var encoder: JSONEncoder {
    let encoder = MeetPRCodec.encoder
    encoder.keyEncodingStrategy = .useDefaultKeys
    return encoder
  }

  static var decoder: JSONDecoder {
    let decoder = MeetPRCodec.decoder
    decoder.keyDecodingStrategy = .useDefaultKeys
    return decoder
  }
}
