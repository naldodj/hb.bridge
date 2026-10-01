// Intentionally fails inside an HRB, exercising the worker's error boundary.
FUNCTION MTAddonFault()

   LOCAL aEmpty := {}

RETURN aEmpty[ 1 ]
