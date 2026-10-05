// Intentionally fails inside an HRB, exercising the worker's error boundary.
FUNCTION mtaddonfault()

    LOCAL aEmpty := {}

RETURN aEmpty[ 1 ]
