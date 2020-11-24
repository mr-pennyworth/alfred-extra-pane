# AlfredExtraPane
Spotight-like rich previews for [Alfred](https://alfredapp.com) workflows.

![](media/demo-fast.gif)

Q: What is this?  
A: An app that workflow creators can add to their script filters

Q: What does it do?  
A: It renders html from quicklookurl of every item in the json.

Q: How does it do it?  
A: By intercepting the json and by monitoring the following three:  
    - up-arrow and down-arrow keypresses  
    - ctrl-p and ctrl-n keypresses  
    - mouse hover over alfred results  

**Q: How to add it to a workflow?**  
A: By adding it to the script filter.
Here's an example (from the workflow in the above GIF):
notice how everything remains the same, just that at the very end,
json needs to be piped through the helper app

```bash
# Before:
items=$(curl 'http://localhost/search' --data "{ \"q\": \"$query\" }" | jq '.hits')
echo "{ \"items\": $items }"

# After:
items=$(curl 'http://localhost/search' --data "{ \"q\": \"$query\" }" | jq '.hits')
echo "{ \"items\": $items }" \
  | 'AlfredExtraPane.app/Contents/Resources/scripts/alfred-extra-pane'
```
 
### Sounds great! Now tell me everything that's not working!  
 - Multi-screen support
 - Take into account scrolling of results using mouse/trackpad
