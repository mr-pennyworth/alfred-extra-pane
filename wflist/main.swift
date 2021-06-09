import Alfred
import Foundation

let wflist = ScriptFilterResponse(
  items: Alfred.workflows().map { wf in
    ScriptFilterResponse.Item.item(
      arg: wf.uid,
      title: wf.name,
      uid: wf.uid,
      icon: .fromImage(at: wf.dir/"icon.png")
    )
  }
)

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let encoded = try! encoder.encode(wflist)
print(String(data: encoded, encoding: .utf8)!)

