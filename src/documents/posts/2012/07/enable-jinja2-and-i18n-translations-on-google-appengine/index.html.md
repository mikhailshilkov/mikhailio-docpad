---
layout: post
title: Enable jinja2 and i18n translations on Google AppEngine
date: 2012-07-26
tags: ["AppEngine","i18n","jinja2","Python","Python","Translations"]
---

My initial goal was to make our new application (based on python/AppEngine) translatable. This means the following requirements:

1.  All strings in the application must be translatable
2.  Translations should preferably stored in separate files
3.  It should be easy to use the translations both in .py files and html templates
The solution that I came to after a couple of hours includes the following components: Babel (string file generation), i18n.gettext (getting strings in code) and jinja2 <% trans %> tag (getting strings in templates). The setup of all this is not obvious, so I'll put the steps in this blog post. Let's start!

1. Intall Babel: [http://babel.edgewall.org/](http://babel.edgewall.org/)
You need to install it, not just ref from the application, as you'll need its comman 'pybabel' to generate locale-specific files. I use Windows, so I just downloaded the installation package.
Make sure that Python folders are in your PATH variable. I use Python 2.7, so to make Babel work I'll need the following values in PATH: "C:\Python27;C:\Python27\Scripts". Scripts folder contains the pybabel executable.

2. Install jinja2: [http://jinja.pocoo.org](http://jinja.pocoo.org/)
Once again, you need to install it, as Babel will need it to parse strings in templates. Just run

[sourcecode language="text" gutter="false"]
easy_install Jinja2
[/sourcecode]

3. Put Babel and [gaepytz](http://pypi.python.org/pypi/gaepytz) libraries inside your GAE application. They are required for i18n module.

4. Configure jinja2 to be used in your application. You'll need the following entry in app.yaml:

[sourcecode language="text" gutter="false"]
libraries:
- name: jinja2
  version: "2.6"
[/sourcecode]

and your webhandler.py will look something similar to this:

[sourcecode language="python" gutter="false"]
import webapp2
from webapp2_extras import jinja2
from webapp2_extras import i18n
from google.appengine.ext.webapp.util import run_wsgi_app

class MainHandler(webapp2.RequestHandler):
    @webapp2.cached_property
    def jinja2(self):
        return jinja2.get_jinja2(app=self.app)

    def get(self):
        i18n.get_i18n().set_locale('ru_RU') # sample locale assigned
        ... # your web site functionality goes here

# jinja2 config with i18n enabled
config = {'webapp2_extras.jinja2': {
             'template_path': 'templates',
             'environment_args': { 'extensions': ['jinja2.ext.i18n'] }
           }
          }
application = webapp2.WSGIApplication([('.*', MainHandler)], config=config)

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()
[/sourcecode]
This code will work if you put your jinja2 templates into "templates" folder.

4. Create the translations markup. This means, you define the translatable strings in python code with a commonly used '_' alias:
[sourcecode language="python" gutter="false"]
from webapp2_extras.i18n import gettext as _

def do_some_text():
    return _('some text')
[/sourcecode]
or in jijna2 template with {% trans %} block:
[sourcecode language="html" gutter="false"]
{% block buttons %}
<div>	
    <div onclick="window.print()">{% trans %}Print{% endtrans %}</div>
</div>
{% endblock %}
[/sourcecode]

5. Create a Babel configuration file babel.cfg (put it into the application folder for now):
[sourcecode language="text" gutter="false"]
[jinja2: **/templates/**.html]
encoding = utf-8
[python: source/*.py]
[extractors] 
jinja2 = jinja2.ext:babel_extract
[/sourcecode]
This file instructs Babel to extract translatable strings from html jinja2 templates in "templates" folder and python files in "source" folder. 

6. Now it's time to create translations. First, add a "locale" folder in application root. Still being in root folder, run the following pybabel command to extract the translatable strings from the code
[sourcecode language="text" gutter="false"]
pybabel extract -F ./babel.cfg -o ./locale/messages.pot ./
[/sourcecode]
then initialize the locales with 
[sourcecode language="text" gutter="false"]
pybabel init -l en_US -d ./locale -i ./locale/messages.pot
pybabel init -l ru_RU -d ./locale -i ./locale/messages.pot
[/sourcecode]
Now open locale\ru_RU\LC_MESSAGES\messages.po file in your favorite text editor, and produce the translations (you have to change 'msgstr' only):
[sourcecode language="text" gutter="false"]
#: templates/sample.html:10
msgid "Print"
msgstr "Печать"
#: source/test.py:13
msgid "some text"
msgstr "немного текста"
[/sourcecode]
And finally compile the texts with
[sourcecode language="text" gutter="false"]
pybabel compile -f -d ./locale
[/sourcecode]

7. Every time you need to add more strings, you should do the same steps as in 6, but use "update" instead of "init":
[sourcecode language="text" gutter="false"]
pybabel update -l en_US -d ./locale -i ./locale/messages.pot
pybabel update -l ru_RU -d ./locale -i ./locale/messages.pot
[/sourcecode]

Done! You should be able to run the application and see the strings translated.