import json
import os
import sqlite3

from collections import defaultdict
from contextlib import contextmanager
from plistlib import readPlist, writePlist
from subprocess import Popen, PIPE


HOME = os.path.expanduser('~')
DB_DIR = HOME + '/Library/Application Support/Alfred/Databases'
PREFS_DIR = os.environ['alfred_preferences']
WORKFLOW_DIR = '%s/workflows/%s' % (PREFS_DIR, os.environ['alfred_workflow_uid'])
APPEARANCE_PREFS = '%s/preferences/appearance/options/prefs.plist' % PREFS_DIR
USER_THEMES_DIR = '%s/themes' % PREFS_DIR
DEFAULT_THEMES_DIR = (
  '/Applications/Alfred 4.app/Contents/Frameworks'
  '/Alfred Framework.framework/Resources'
)


def cached(func):
  cache = {}
  def cached_func(*args):
    if args not in cache:
      cache[args] = func(*args)
    return cache[args]
  return cached_func

@cached
def script_filter():
  '''
  Return the plist info of the script filter
  There might be multiple script filters

  1) only one of which calls this script: that will be returned
  2) more than one call this script:
       environment variable "keyword" is used
       if not set, the first script filter is returned
       best is to simply set the environment variable
  '''
  plist_path = WORKFLOW_DIR + '/info.plist'
  info = readPlist(plist_path)
  keyword = os.environ.get('keyword')

  for obj in info['objects']:
    if (obj['type'].endswith('scriptfilter')
        and 'alfred-extra-pane' in obj['config']['script']
        and (keyword == obj['config']['keyword'] or keyword is None)):
      return obj
  

def script_filter_id():
  return script_filter()['uid']


def argument_required():
  return script_filter()['config']['argumenttype'] == 0

  
@contextmanager
def alfdb(db_name):
  db_path = '%s/%s.alfdb' % (DB_DIR, db_name)
  db = sqlite3.connect(db_path)
  try:
    yield db
  finally:
    db.commit()
    db.close()

  
def sort_by_knowledge(items):
  '''
  This is a GUESS based on LIMITED observation.

  sorting is based on
  1) how many times an item has been actioned (freq)
  2) latest timestamp of action               (timestamp)

  primarily sorted based on freq, ties are broken by timestamp

  special case:
  if the script filter has executed without an argument,
  and one of the resultant items has an entry in the latching table,
  the item goes to the top, irrespective of the above sorting.
  '''
  if all('uid' not in item for item in items):
    return items

  uid_to_latching_frequency_timestamp_map = defaultdict(lambda:(-1, 0, 0))
  knowledge_rows = []
  latching_rows = []

  with alfdb('knowledge') as db:
    # item is of format: script_filter_id.item_uid
    uuid_len = len(script_filter_id())
    knowledge_rows = db.execute('''
      SELECT item, ts
      FROM knowledge
      WHERE item LIKE "''' + script_filter_id() + '.%"'
    ).fetchall()

    # There's no latching when argument is mandatory
    # Also, latching is triggered only when script's been called
    # without an argument
    if not argument_required() and os.environ['arg'].strip() == '':
      latching_rows = db.execute('''
        SELECT item, strong
        FROM latching
        WHERE item LIKE "''' + script_filter_id() + '.%"'
      ).fetchall()

  for sf_uuid_n_uid, timestamp in knowledge_rows:
    uid = sf_uuid_n_uid[len(script_filter_id())+1:]
    latching, freq, ts = uid_to_latching_frequency_timestamp_map[uid]
    uid_to_latching_frequency_timestamp_map[uid] = (
      latching,
      freq + 1,
      max(ts, timestamp)
    )

  for sf_uuid_n_uid, latching in latching_rows:
    uid = sf_uuid_n_uid[len(script_filter_id())+1:]
    _, freq, ts = uid_to_latching_frequency_timestamp_map[uid]
    uid_to_latching_frequency_timestamp_map[uid] = (latching, freq, ts)
    
  return sorted(
    items,
    key=lambda item: uid_to_latching_frequency_timestamp_map[item['uid']],
    reverse=True
  )


def flatten(arrayless_json_obj):
  flattened = {}
  for key, value in arrayless_json_obj.items():
    if type(value) == dict:
      for fk, fv in flatten(value).items():
        flattened['%s.%s' % (key, fk)] = fv
    else:
      flattened[key] = value
  return flattened


def theme_css():
  ''' example output:
  :root {
     --separator-color: #F9915700;
     --search-text-font: System Light;
     --window-paddingVertical: 10;
     --result-shortcut-size: 16;
     ...
  }
  '''
  def convert(varname, val):
    if type(val) == int:
      if varname.endswith('blur'): return str(val) + '%'
      else: return '%dpx' % val
    elif not val.startswith('#'): return '"%s"' % val
    else: return val

  return ':root {\n  %s;\n}' % ';\n  '.join([
    '--%s: %s' % (varname.replace('.', '-'), convert(varname, val))
    for varname, val in theme().items()
  ])


@cached
def theme():
  bundled_theme_filename = {
    'theme.bundled.default': 'Alfred.alfredappearance',
    'theme.bundled.dark': 'Alfred Dark.alfredappearance',
    'theme.bundled.classic': 'Alfred Classic.alfredappearance',
    'theme.bundled.osx': 'Alfred macOS.alfredappearance',
    'theme.bundled.osxdark': 'Alfred macOS Dark.alfredappearance',
    'theme.bundled.frostyteal': 'Frosty Teal.alfredappearance',
    'theme.bundled.highcontrast': 'High Contrast.alfredappearance',
    'theme.bundled.modernavenir': 'Modern Avenir.alfredappearance'
  }
  theme_id = os.environ['alfred_theme']
  if theme_id.startswith('theme.bundled'):
    theme_path = '%s/%s' % (DEFAULT_THEMES_DIR, bundled_theme_filename[theme_id])
  else:
    theme_path = '%s/%s/theme.json' % (USER_THEMES_DIR, theme_id)

  with open(theme_path) as f:
    return flatten(json.load(f)['alfredtheme'])


def execJXA(script):
  p = Popen(['osascript', '-l', 'JavaScript', '-'],
            stdin=PIPE, stdout=PIPE, stderr=PIPE)
  stdout, stderr = p.communicate(script)
  return stdout


@cached
def search_field_height():
  # for any given font, the size of font in px is usually
  # smaller by a scaling factor than the height of the bounding box
  # for the text. For the default system font that alfred themes have,
  # that scaling factor is 1.2
  # there's no general way of finding this out programmatically
  # so, instead of basing this calculation off of the variables in the theme,
  # we resort to JXA
  #
  # NOTE: other places where alfred displays text, like title and subtitle,
  #       this scaling factor doesn't seem to come into play
  return int(execJXA('''
    function run(argv) {
      var system = Application('System Events');
      var alfred = system.processes['Alfred'];
      return alfred.windows[0].textFields[0].size.get()[1];
    }'''))


@cached
def result_height():
  th = theme()
  return (th['result.paddingVertical'] * 2
          + th['separator.thickness']
          + max(th['result.iconSize'],
                (th['result.text.size']
                 + th['result.textSpacing']
                 + th['result.subtext.size'])))

@cached
def result_width():
  th = theme()
  return (th['window.width']
          - 2*(th['window.paddingHorizontal'] + th['window.borderPadding']))


@cached
def results_top_left_x():
  th = theme()
  return th['window.paddingHorizontal'] + th['window.borderPadding']


@cached
def results_top_left_y():
  th = theme()
  return (th['window.borderPadding']
          + th['window.paddingVertical']
          + search_field_height()
          + th['search.spacing']
          + th['separator.thickness'])


@cached
def window_height(item_count):
  th = theme()
  return (th['window.borderPadding'] * 2
          + th['window.paddingVertical'] * 2
          + search_field_height()
          + th['search.spacing']
          + th['separator.thickness']
          + result_height() * item_count)

@cached
def max_visible_results():
  if not os.path.exists(APPEARANCE_PREFS): return 9
  # somehow, alfred's plist stores one less than what is shown in GUI
  return readPlist(APPEARANCE_PREFS).get('visibleresults', 8) + 1
