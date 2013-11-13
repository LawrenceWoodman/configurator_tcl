# A configuration parsing module
#
# Copyright (C) 2013 Lawrence Woodman <lwoodman@vlifesystems.com>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

package require Tcl 8.5

namespace eval configurator {
  namespace export {[a-z]*}
}

proc configurator::parseConfig {args} {
  lassign [HandleArgs $args] keys exposeCmds script
  set safeInterp [interp create -safe]

  catch {
    set config [dict create]
    $safeInterp eval {unset {*}[info vars]}

    ExposeCorrectCmds $safeInterp $exposeCmds
    CreateKeyCmds $safeInterp $keys

    $safeInterp eval $script
    return $config
  } returnResult returnOptions

  interp delete $safeInterp
  return -options $returnOptions $returnResult
}

proc configurator::UnknownHandler {int configVariable args} {
  lassign $args key
  set values [lrange $args 1 end]
  if {[llength $values] != 1} {
    Usage "$key arg"
  }
  upvar $configVariable config
  SetConfig $key 1 "arg" config {*}$values
}

proc configurator::SetConfig {key numValues argsUsage configVariable \
                                   args} {
  set numArgs [llength $args]
  if { $numArgs == 0 || \
      ($numValues ne "many" && $numValues != $numArgs)} {
    Usage "$key $argsUsage"
  } else {
    upvar $configVariable config
    if {$numValues eq "many" || $numValues > 1} {
      dict set config $key $args
    } else {
      dict set config $key [lindex $args 0]
    }
  }
}

proc configurator::HandleArgs {_args} {
  set keys {}
  set exposeCmds {}
  set scriptPos 0
  foreach {option value} $_args {
    if {![string match {-*} $option]} {
      break
    }
    switch $option {
      "-keys" {
        set keys $value
        incr scriptPos 2
      }
      "-expose" {
        set exposeCmds $value
        incr scriptPos 2
      }
      default {
        return -code error "bad option \"$option\": must be -expose or -keys"
      }
    }
  }

  set _args [lrange $_args $scriptPos end]

  if {[llength $_args] != 1} {
    Usage "parseConfig ?-option value ...? script"
  }

  set script [lindex $_args 0]
  list $keys $exposeCmds $script
}

proc configurator::ExposeCorrectCmds {int exposeCmds} {
  if {[llength $exposeCmds] == 0} {
    $int eval {namespace delete ::}
  } else {
    foreach command [$int eval {info commands}] {
      $int hide $command
    }

    foreach {hiddenName exposedName} $exposeCmds {
      $int expose $hiddenName $exposedName
    }
  }
}

proc configurator::CreateKeyCmds {int keys} {
  foreach {key keyConfig} $keys {
    lassign $keyConfig numValues argsUsage
    $int alias $key configurator::SetConfig $key $numValues $argsUsage config
  }

  if {[llength $keys] == 0} {
    $int alias unknown configurator::UnknownHandler $int config
  } else {
    foreach {key keyConfig} $keys {
      lassign $keyConfig numValues argsUsage
      $int alias $key configurator::SetConfig $key $numValues $argsUsage config
    }
  }
}

proc configurator::Usage {msg} {
  return -code error -level 2 "wrong # args: should be \"$msg\""
}
