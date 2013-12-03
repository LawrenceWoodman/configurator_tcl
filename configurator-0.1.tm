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
  lassign [HandleArgs $args] options script
  set safeInterp [interp create -safe]

  catch {
    set config [dict create]
    $safeInterp eval {unset {*}[info vars]}
    ProcessOptions $safeInterp $options

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
  set optionsKeys {
    -masterCmds masterCmds -expose exposeCmds
    -keys keyCmds -slaveCmds slaveCmds
  }
  set options {}
  foreach {option value} $_args {
    if {![string match {-*} $option]} {
      break
    }
    if {[dict exists $optionsKeys $option]} {
      dict set options [dict get $optionsKeys $option] $value
    } else {
      return -code error \
          "bad option \"$option\": must be -expose, -keys, -masterCmds or\
-slaveCmds"
    }
  }

  set scriptPos [expr {2 * [dict size $options]}]
  set _args [lrange $_args $scriptPos end]

  if {[llength $_args] != 1} {
    Usage "parseConfig ?-option value ...? script"
  }

  set script [lindex $_args 0]
  list $options $script
}

proc configurator::ProcessOptions {int options} {
  if {[dict exists $options exposeCmds] || \
      [dict exists $options slaveCmds]} {
    HideAllCmds $int
  } else {
    $int eval {namespace delete ::}
  }

  if {[dict exists $options exposeCmds]} {
    ExposeCmds $int [dict get $options exposeCmds]
  }

  if {[dict exists $options masterCmds]} {
    CreateMasterCmds $int [dict get $options masterCmds]
  }

  if {[dict exists $options slaveCmds]} {
    CreateSlaveCmds $int [dict get $options slaveCmds]
  }

  if {[dict exists $options keyCmds]} {
    CreateKeyCmds $int [dict get $options keyCmds]
  } else {
    $int alias unknown configurator::UnknownHandler $int config
  }
}

proc configurator::CreateMasterCmds {int masterCmds} {
  dict for {slaveCmd masterCmd} $masterCmds {
    $int alias $slaveCmd $masterCmd
  }
}

proc configurator::HideAllCmds {int} {
  foreach command [$int eval {info commands}] {
    $int hide $command
  }
}

proc configurator::ExposeCmds {int exposeCmds} {
  dict for {exposedName hiddenName} $exposeCmds {
    $int expose $hiddenName $exposedName
  }
}

proc configurator::CreateKeyCmds {int keys} {
  foreach {commandName keyConfig} $keys {
    lassign $keyConfig key numValues argsUsage
    $int alias $commandName configurator::SetConfig $key $numValues \
        $argsUsage config
  }

  foreach {commandName keyConfig} $keys {
    lassign $keyConfig key numValues argsUsage
    $int alias $commandName configurator::SetConfig $key $numValues \
        $argsUsage config
  }
}

proc configurator::CreateSlaveCmds {int slaveCmds} {
  dict for {slaveCmd masterCmd} $slaveCmds {
    $int alias $slaveCmd $masterCmd $int
  }
}

proc configurator::Usage {msg} {
  return -code error -level 2 "wrong # args: should be \"$msg\""
}
