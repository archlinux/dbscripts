#include <Python.h>
#include <alpm.h>

static PyObject *
alpm_vercmp(PyObject *self, PyObject *args)
{
	const char *v1, *v2;
	int ret;

	if (!PyArg_ParseTuple(args, "ss", &v1, &v2))
		return NULL;
	ret = alpm_pkg_vercmp(v1, v2);
	return Py_BuildValue("i", ret);
}

static PyMethodDef AlpmMethods[] = {
	{"vercmp",  alpm_vercmp, METH_VARARGS,
		"Execute vercmp."},
	{NULL, NULL, 0, NULL}        /* Sentinel */
};

PyMODINIT_FUNC
initalpm(void)
{
	(void) Py_InitModule("alpm", AlpmMethods);
}

int
main(int argc, char *argv[])
{
	/* Pass argv[0] to the Python interpreter */
	Py_SetProgramName(argv[0]);

	/* Initialize the Python interpreter.  Required. */
	Py_Initialize();

	/* Add a static module */
	initalpm();
	return 0;
}
