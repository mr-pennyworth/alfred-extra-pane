import json
import os


HOME = os.path.expanduser('~')
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
