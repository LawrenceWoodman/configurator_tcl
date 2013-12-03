# Helper functions for the tests

namespace eval TestHelpers {
}

proc TestHelpers::seta {int value} {
  $int invokehidden set a $value
}
