" Vim completion script
" Language: htmldjango
" Maintainer:   Michael Brown
" Last Change:  Sun 13 May 2012 16:39:45 EST
" Version: 0.9.2
" Omnicomplete for django template taga/variables/filters
" {{{1 Environment Settings
if !exists('g:htmldjangocomplete_html_flavour')
    " :verbose function htmlcomplete#CheckDoctype for details
    " No html5!
    "'html401t' 'xhtml10s' 'html32' 'html40t' 'html40f' 'html40s'
    "'html401t' 'html401f' 'html401s' 'xhtml10t' 'xhtml10f' 'xhtml10s'
    "'xhtml11'
    let g:htmldjangocomplete_html_flavour = 'xhtml11'
endif

"Allow settings of DEBUG
if !exists('g:htmldjangocomplete_debug')
    let g:htmldjangocomplete_debug = 0
endif

"{{{1 The actual omnifunc
function! htmldjangocomplete#CompleteDjango(findstart, base)
    "{{{2 findstart = 1 when we need to get the text length
    "
    if a:findstart == 1

        "Fallback to htmlcomplete
        if searchpair('{{','','}}','nc') == 0 && searchpair('{%',"",'%}','nc') == 0
            if !exists('b:html_doctype')
                let b:html_doctype = 1
                let b:html_omni_flavor = g:htmldjangocomplete_html_flavour
            endif
            return htmlcomplete#CompleteTags(a:findstart,a:base)
        endif

        " locate the start of the word
        let line = getline('.')
        let start = col('.') - 1
        "special case for {% extends %} {% import %} needs to grab /'s
        "TODO make this match more flexible. It needs to know its in a string
        "also need to handle inline imports
        if s:get_context() == 'extends'|| s:get_context() == 'include'
            while start > 0 && line[start - 1] != '"' && line[start -1] != "'"
                        \ && line[start -1] != ' '
            let start -= 1
            endwhile
            return start
        endif
        "
        "default <word> case
        while start > 0 && line[start - 1] =~ '\a'
          let start -= 1
        endwhile
        return start
    "{{{2 findstart = 0 when we need to return the list of completions
    else
        "Fallback to htmlcomplete
        if searchpair('{{','','}}','nc') == 0 && searchpair('{%',"",'%}','nc') == 0
            let matches = htmlcomplete#CompleteTags(a:findstart,a:base)
            "suppress all DOCTYPE matches
            call filter(matches, 'stridx(v:val["word"],"DOCTYPE") == -1')
            return matches
        endif

        let context = s:get_context()

        if context == 'extends' || context == 'include'
            let context = 'template'
        endif

        "TODO: Reduce load always nature of this plugin
        call s:load_libs()
        "get context look for {% {{ and |
        let line = getline('.')
        let start = col('.') -1

        " Special case for extends and import
        " TODO 'filter' should really just be string filters
        if index(['template','load','url','filter','block', 'static'],context) != -1
            execute "python htmldjangocomplete('" . context . "', '" . a:base . "')"
            return g:htmldjangocomplete_completions
        endif

        while start > 0
            if line[start] == ':' && s:in_django(line,start) == 1
                execute "python htmldjangocomplete('variable', '" . a:base . "')"
                return g:htmldjangocomplete_completions
            elseif line[start] == '|' && s:in_django(line,start)
                execute "python htmldjangocomplete('filter', '" . a:base . "')"
                return g:htmldjangocomplete_completions
            elseif line[start] == '{' && line[start -1] == '{'
                execute "python htmldjangocomplete('variable', '" . a:base . "')"
                return g:htmldjangocomplete_completions
            elseif line[start] == '%' && line[start -1] == '{'
                execute "python htmldjangocomplete('tag', '" . a:base . "')"
                return g:htmldjangocomplete_completions
            else
                let start -= 1
            endif
        endwhile

        return [ {'word': "nomatch"} ]
        "fallback to htmlcomplete TODO This doesn't work as expected.
        "Might need to turn off some doctype setting.
        "
        "call htmlcomplete#CompleteTags(1, a:base)
        "return htmlcomplete#CompleteTags(0, a:base)
    endif
endfunction

"Supporting vim functions {{{1
function! s:get_context()
    let curpos = getpos('.')
    let line = getline('.')

    "tags
    let starttag = searchpairpos('{%', '', '%}', 'bn')
    if starttag != [0,0]
        let fragment = line[starttag[1]:curpos[2]]
        return split(fragment,' ')[1]
    endif

    return "other"
endfunction

"TODO This could probably be neater with an index check. need to get strings
"working
function! s:in_django(l,s)
    let line = a:l
    let start = a:s
    while start >= 0
        if line[start] == '}'
            return 0
        elseif line[start] == '{'
            return 1
        endif
        let start -= 1
    endwhile
    return 0
endfunction

"Python section {{{1
"imports {{{2
let g:htmldjangocomplete_completions = []
function! s:load_libs()
if has('python')
python << EOF
try:
    HTMLDJANGO_DEBUG = vim.eval("g:htmldjangocomplete_debug") == 0 and True or False
except:
    HTMLDJANGO_DEBUG = False

TEMPLATE_EXTS = ['.html','.txt','.htm']

import warnings
warnings.sys.warnoptions = ['-W']

import logging
import vim
import os

# Install the django-configurations importer (before Django setup).
if os.environ.get('DJANGO_CONFIGURATION'):
    try:
        import configurations.importer
        configurations.importer.install()
    except:
        sys.exit()

# Setup Django (required for >= 1.7).
import django
if hasattr(django, 'setup'):
    django.setup()

try:
    #for OLD versions od django
    from django.template import get_library
except:
    #for django 1.8+
    try:
        from django.template.base import get_library
    except:
        #for django 1.9+
        from django.template.backends.django import get_installed_libraries
        def get_library(libname):
            return get_installed_libraries()[libname]


from django.template.loaders import filesystem, app_directories
#Later versions of django seem to be fussy about get_library paths.
try:
    from django.template import import_library
except ImportError:
    try:
        from django.template.base import import_library
    except ImportError:
        import_library = get_library


try:
    from django.template.loaders.app_directories import app_template_dirs
except:
    from django.template.loaders.app_directories import get_app_template_dirs
    app_template_dirs = get_app_template_dirs('templates')

from django.conf import settings as mysettings
from django.template.loader import get_template
from django.template.loader_tags import ExtendsNode, BlockNode
from django.template import Template

import re
from operator import itemgetter
import pkgutil
import os
from glob import glob

try:
    from django.template import get_templatetags_modules
except ImportError:
    #I've lifted this version from the django source
    try:
        from importlib import import_module
    except ImportError:
        from django.utils.importlib import import_module

    def get_templatetags_modules():
        """
        Return the list of all available template tag modules.

        Caches the result for faster access.
        """
        _templatetags_modules = []
        # Populate list once per process. Mutate the local list first, and
        # then assign it to the global name to ensure there are no cases where
        # two threads try to populate it simultaneously.
        for app_module in ['django'] + list(mysettings.INSTALLED_APPS):
            try:
                templatetag_module = '%s.templatetags' % app_module
                import_module(templatetag_module)
                _templatetags_modules.append(templatetag_module)
            except ImportError:
                continue
        return _templatetags_modules

# {{{2 Support functions

def get_block_tags(start=''):

    #use regexp for extends as get_template will fail on tag errors
    rexp = re.compile('{%\s*extends\s*[\'"](.*)["\']\s*%}')
    base = None
    templates = [] # for cycle detection

    for l in vim.current.buffer[0:10]:
        match = rexp.match(l)
        if match:
            try:
                base = get_template(match.groups()[0])
            except:
                return []

    if not base:
        return []

    def _get_blocks(tpl, menu_prefix='', add_name = True):
        """
        recursive worker function
        """

        # TODO I Think this is a 1.8 compatibility thing sending the wrapper
        # class
        tpl = getattr(tpl, 'name', None) and tpl or tpl.template

        if tpl.name in templates and isinstance(tpl, Template):
            logging.info("cyclic extends detected!")
            return []
        else:
            templates.append(tpl.name)

        if menu_prefix == '' and isinstance(tpl, Template):
            menu_prefix = "%s > " % tpl.name

        blocks = [(block, block.name, menu_prefix)
                    for block in tpl.nodelist if isinstance(block, BlockNode)]

        for block, name, _ in blocks:
            if add_name:
                blocks += _get_blocks(block, '%s%s > ' % (menu_prefix, name))
            else:
                blocks += _get_blocks(block, '%s' % (menu_prefix))

        if len(tpl.nodelist) > 0 and isinstance(tpl.nodelist[0], ExtendsNode):
            logging.debug("parent_name")
            logging.debug(tpl.nodelist[0].parent_name)
            parent_template = str(tpl.nodelist[0].parent_name).replace(
                '"', '').replace("''", '')
            try:
                parent_tpl = get_template(parent_template)
                blocks += _get_blocks(parent_tpl)
            except TemplateDoesNotExist:
                logging.info("get_template:TemplateDoesNotExist - '%s'" %
                                parent_template)

        for node in tpl.nodelist:
            if not isinstance(node, BlockNode) and not isinstance(node,
                    ExtendsNode):
                try:
                    blocks += _get_blocks(node, menu_prefix, add_name=False)
                except AttributeError:
                    logging.info("node %s: no nodelist" % node)

        return blocks

    full_matches = _get_blocks(base)

    names = []
    matches = []
    # dedup matches TODO might be a better way of picking matches
    for match in full_matches:
        if not match[0] in names:
            matches.append(match)
            names.append(match[0])

    return [{'word':n,'menu':m} for b, n, m in matches if n.startswith(start)]

def get_template_names(pattern):

    dirs = getattr(mysettings, "TEMPLATE_DIRS", ()) + app_template_dirs
    if hasattr(mysettings, "TEMPLATES"):
        for d in [e["DIRS"] for e in mysettings.TEMPLATES]:
            dirs += tuple(d)

    matches = []
    for d in dirs:
        d = d + (os.path.sep if not d.endswith(os.path.sep) else '')
        for m in glob(os.path.join(d,pattern + '*')):
            if os.path.isdir(m):
                for root,dirnames,filenames in os.walk(m):
                    for f in filenames:
                        fn,ext = os.path.splitext(f)
                        if ext in TEMPLATE_EXTS:
                            matches.append({
                                'word' : os.path.join(root,f).replace(d,''),
                                'info' : 'found in %s' % d
                            }
                            )
            else:
                matches.append({
                    'word' : m.replace(d,''),
                    'info' : 'found in %s' % d
                }
                )

    return matches

try:
    from django.contrib.staticfiles import finders, storage
    def get_staticfiles(pattern):

        dirs = mysettings.STATICFILES_DIRS

        #TODO crude matching
        line = vim.current.line
        if 'script' in line:
            ext = ".*\.js$"
        elif 'style' in line:
            ext = ".*\.css$"
        elif 'img' in line:
            ext = ".*\.(gif|jpg|jpeg|png)$"
        else:
            ext = '.*'

        matches = []

        for finder in finders.get_finders():
            for path, storage in finder.list([]):
                if re.compile(ext,re.IGNORECASE).match(path) \
                    and path.startswith(pattern):
                    matches.append(dict(word=path,info=''))

        return matches
except:
    def get_staticfiles(pattern):
        return []

def get_tag_libraries():
    opts = []
    for module in get_templatetags_modules():
        mod = __import__(module,fromlist=['foo'])
        for l,m,i in pkgutil.iter_modules([os.path.dirname(mod.__file__)]):
            opts.append({'word':m,'menu':mod.__name__})

    return opts


def _get_doc(doc, name):
    if doc:
        return doc.replace('"',' ').replace("'",' ')
    return '%s: no doc' % name

def _get_opt_dict(lib,t,libname=''):
    opts = getattr(lib,t)
    return [
    {'word':f, 'info': _get_doc(opts[f].__doc__,f),'menu':libname} \
    for f in opts.keys()]

def load_app_tags():
    cb = vim.current.buffer
    for line in cb:
        m =  re.compile('{% load (.*)%}').match(line)
        if m:
            for lib in m.groups()[0].rstrip().split(' '):
                try:
                    l = get_library(lib)
                    htmldjango_opts['filter'] += _get_opt_dict(l,'filters',lib)
                    htmldjango_opts['tag'] += _get_opt_dict(l,'tags',lib)
                except Exception as e:
                    if HTMLDJANGO_DEBUG:
                        print "FAILED TO LOAD: %s" % lib
                        raise e
# {{{2 load options
# TODO At the moment this is being loaded every match
htmldjango_opts = {}

htmldjango_opts['load'] = get_tag_libraries()
def_filters = import_library('django.template.defaultfilters')
htmldjango_opts['filter'] = _get_opt_dict(def_filters,'filters','default')
def_tags = import_library('django.template.defaulttags')
htmldjango_opts['tag'] = _get_opt_dict(def_tags,'tags','default')
load_app_tags()

try:
    urls = __import__(mysettings.ROOT_URLCONF,fromlist=['foo'])
except:
    urls = None

def htmldjango_urls(pattern):
    matches = []
    def get_urls(urllist,parent=None):
        for entry in urllist:
            if hasattr(entry,'name') and entry.name:
                matches.append(dict(
                    word = entry.name,
                    info = entry.regex.pattern,
                    menu = parent and parent.urlconf_name or '')
                    )
            if hasattr(entry, 'url_patterns'):
                get_urls(entry.url_patterns, entry)
    if urls:
        get_urls(urls.urlpatterns)
    return matches

#TODO I may be able to populate RequestContext via middleware component
htmldjango_opts['variable'] = []
#TODO Write a function that gets all ancestor template blocks
htmldjango_opts['block'] = []

# Main Python function {{{2
def htmldjangocomplete(context,match):
    if context == 'template':
        all = get_template_names(match)
    elif context == 'static':
        all = get_staticfiles(match)
    elif context == 'url':
        all = htmldjango_urls(match)
    elif context == 'block':
        all = get_block_tags(match)
    else:
        all = htmldjango_opts[context]

    vim.command("silent let g:htmldjangocomplete_completions = []")

    dictstr = '['
    # have to do this for double quoting

    all = [a for a in all if a['word'].startswith(match)]
    all = sorted(all, key=itemgetter('word'))

    for cmpl in all:
        dictstr += '{'
        for x in cmpl: dictstr += '"%s":"%s",' % (x,cmpl[x].replace("\\", "\\\\")) # Windows slashes must be escaped
        dictstr += '"icase":0},'
    if dictstr[-1] == ',': dictstr = dictstr[:-1]
    dictstr += ']'
    vim.command("silent let g:htmldjangocomplete_completions = %s" % dictstr)
EOF
endif
endfunction
" Test Area {{{1
function! TestLoadLibs()
    call s:load_libs()
endfunction

function! HtmlDjangoDebug(on)
    if a:on
        echo "adding Breakpoint"
        breakadd func htmldjangocomplete#CompleteDjango
    else
        echo "remove Breakpoint"
        breakdel func htmldjangocomplete#CompleteDjango
    endif
endfunction
" vim:set foldmethod=marker:
