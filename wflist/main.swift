import Alfred
import Foundation

let wflist = ScriptFilterResponse(
  items: Alfred.workflows().map { wf in
    var subtitle = ""
    if let description = wf.description { subtitle += description }
    if let author = wf.author { subtitle += " [by \(author)]" }
    return ScriptFilterResponse.Item.item(
      arg: wf.uid,
      title: wf.name,
      uid: wf.uid,
      subtitle: subtitle.trimmingCharacters(in: .whitespaces),
      match: "\(wf.name!) \(subtitle)",
      icon: .fromImage(at: wf.dir/"icon.png")
    )
  }
)

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let encoded = try! encoder.encode(wflist)
print(String(data: encoded, encoding: .utf8)!)
