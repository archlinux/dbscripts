from distutils.core import setup, Extension

alpm = Extension('alpm',
		libraries = ['alpm'],
		sources = ['alpm.c'])

setup (name = 'Alpm',
		version = '1.0',
		description = 'Alpm bindings',
		ext_modules = [alpm])
