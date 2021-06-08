extension PanePosition: Codable {
  enum CodingKeys: CodingKey { case horizontal, vertical }
  enum HorizontalKeys: CodingKey { case placement, width, minHeight }
  enum VerticalKeys: CodingKey { case placement, height }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let key = container.allKeys.first

    switch key {
    case .vertical:
      let nested = try container.nestedContainer(
        keyedBy: VerticalKeys.self,
        forKey: .vertical
      )
      let placement = try nested.decode(
        VerticalPosition.self,
        forKey: .placement
      )
      let height = try nested.decode(Int.self, forKey: .height)
      self = .vertical(placement: placement, height: height)
    case .horizontal:
      let nested = try container.nestedContainer(
        keyedBy: HorizontalKeys.self,
        forKey: .horizontal
      )
      let placement = try nested.decode(
        HorizontalPosition.self,
        forKey: .placement
      )
      let width = try nested.decode(Int.self, forKey: .width)
      let minHeight = try? nested.decode(Int.self, forKey: .minHeight)
      self = .horizontal(
        placement: placement,
        width: width,
        minHeight: minHeight
      )
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Unabled to decode enum."
        )
      )
    }
  }


  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .vertical(let position, let height):
      var nested = container.nestedContainer(
        keyedBy: VerticalKeys.self,
        forKey: .vertical
      )
      try nested.encode(position, forKey: .placement)
      try nested.encode(height, forKey: .height)
    case .horizontal(let position, let width, let minHeight):
      var nested = container.nestedContainer(
        keyedBy: HorizontalKeys.self,
        forKey: .horizontal
      )
      try nested.encode(position, forKey: .placement)
      try nested.encode(width, forKey: .width)
      try nested.encode(minHeight, forKey: .minHeight)
    }
  }
}
