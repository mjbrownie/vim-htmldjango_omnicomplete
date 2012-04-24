" Vim completion script
" Language: htmldjango
" Maintainer:   Michael Brown
" Last Change:  Sun 22 Apr 2012 01:29:23 EST
" Omnicomplete for django template taga/variables/filters
if !exists('g:htmldjangocomplete_html_flavour')
    " :verbose function htmlcomplete#CheckDoctype for details
    " No html5!
    "'html401t' 'xhtml10s' 'html32' 'html40t' 'html40f' 'html40s'
    "'html401t' 'html401f' 'html401s' 'xhtml10t' 'xhtml10f' 'xhtml10s'
    "'xhtml11'
    let g:htmldjangocomplete_html_flavour = 'xhtml11'
endif

"{{{1 The actual omnifunc
function! htmldjangocomplete#CompleteDjango(findstart, base)
    "{{{2 findstart = 1 when we need to get the text length
    "
    if a:findstart == 1

        "Fallback to htmlcomplete
        if searchpair('{{','','}}','n') == 0 && searchpair('{%',"",'%}','n') == 0
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
        if match (line,"{% extends ") > -1 || match(line,"{% include ") > -1
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
        if searchpair('{{','','}}','n') == 0 && searchpair('{%',"",'%}','n') == 0
            let matches = htmlcomplete#CompleteTags(a:findstart,a:base)
            "suppress all DOCTYPE matches
            call filter(matches, 'stridx(v:val["word"],"DOCTYPE") == -1')
            return matches
        endif

        "TODO: Reduce load always nature of this plugin
        call s:load_libs()
        "get context look for {% {{ and |
        let line = getline('.')
        let start = col('.') -1

        " Special case for extends and import
        if match (line,"{% extends ") > -1 || match(line,"{% include ") > -1
            execute "python htmldjangocomplete('template', '" . a:base . "')"
            return g:htmldjangocomplete_completions
        endif

        "check for {% load %}
        if match(line, '{% load ') >  -1
            execute "python htmldjangocomplete('load', '" . a:base . "')"
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

        "fallback to htmlcomplete TODO This doesn't work as expected.
        "Might need to turn off some doctype setting.
        "
        "call htmlcomplete#CompleteTags(1, a:base)
        "return htmlcomplete#CompleteTags(0, a:base)
    endif
endfunction

"Supporting vim function {{{1
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
DEBUG = False

TEMPLATE_EXTS = ['.html','.txt','.htm']

import vim
from django.template import get_library
#Later versions of django seem to be fussy about get_library paths.
try:
    from django.template import import_library
except ImportError:
    import_library = get_library


from django.template.loaders.app_directories import app_template_dirs
from django.conf import settings as mysettings
import re
from operator import itemgetter
import pkgutil
import os
from glob import glob

try:
    from django.template import get_templatetags_modules
except ImportError:
    #I've lifted this version from the django source
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
def get_template_names(pattern):
    dirs = mysettings.TEMPLATE_DIRS + app_template_dirs
    matches = []
    for d in dirs:
        for m in glob(os.path.join(d,pattern + '*')):
            if os.path.isdir(m):
                for root,dirnames,filenames in os.walk(m):
                    for f in filenames:
                        fn,ext = os.path.splitext(f)
                        if ext in TEMPLATE_EXTS:
                            matches.append({
                                'word' : os.path.join(root,f).replace(d + '/',''),
                                'info' : 'found in %s' % d
                            }
                            )
            else:
                matches.append({
                    'word' : m.replace(d + '/',''),
                    'info' : 'found in %s' % d
                }
                )

    return matches

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

# {{{2 load options
# TODO At the moment this is being loaded every match
htmldjango_opts = {}

htmldjango_opts['load'] = get_tag_libraries()
def_filters = import_library('django.template.defaultfilters')
htmldjango_opts['filter'] = _get_opt_dict(def_filters,'filters','default')
def_tags = import_library('django.template.defaulttags')
htmldjango_opts['tag'] = _get_opt_dict(def_tags,'tags','default')

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
                if DEBUG:
                    raise e

#TODO I may be able to populate RequestContext via middleware component
htmldjango_opts['variable'] = []

# Main Python function {{{2
def htmldjangocomplete(context,match):
    if context == 'template':
        all = get_template_names(match)
    else:
        all = htmldjango_opts[context]

    vim.command("silent let g:htmldjangocomplete_completions = []")

    dictstr = '['
    # have to do this for double quoting

    all = [a for a in all if a['word'].startswith(match)]
    all = sorted(all, key=itemgetter('word'))

    for cmpl in all:
        dictstr += '{'
        for x in cmpl: dictstr += '"%s":"%s",' % (x,cmpl[x])
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

" vim:set foldmethod=marker:
