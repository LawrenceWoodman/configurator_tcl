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
    HideAllCmds $safeInterp
    ProcessOptions $safeInterp $options

    set returnVal [$safeInterp eval $script]
    if {[dict exists $options -returnKey]} {
      dict set config [dict get $options -returnKey] $returnVal
    }

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
  set validOptions {-exposeCmds -keys -masterCmds -returnKey -slaveCmds}

  set options {}
  foreach {option value} $_args {
    if {![string match {-*} $option]} {
      break
    }
    if {[lsearch $validOptions $option] != -1} {
      dict set options $option $value
    } else {
      return -code error \
          "bad option \"$option\": must be -exposeCmds, -keys, -masterCmds \
-returnKey or -slaveCmds"
    }
  }

  set scriptPos [expr {2 * [dict size $options]}]

  if {$scriptPos != ([llength $_args] - 1)} {
    Usage "parseConfig ?-option value ...? script"
  }

  set script [lindex $_args $scriptPos]
  list $options $script
}

proc configurator::ProcessOptions {int options} {
  if {![dict exists $options -exposeCmds] &&
      ![dict exists $options -slaveCmds]} {
    $int invokehidden namespace delete ::
  }

  foreach {option value} $options {
    switch $option {
      -exposeCmds {ExposeCmds $int $value}
      -masterCmds {CreateMasterCmds $int $value}
      -slaveCmds  {CreateSlaveCmds $int $value}
      -keys       {CreateKeyCmds $int $value}
    }
  }

  if {![dict exists $options -keys]} {
    $int alias unknown configurator::UnknownHandler $int config
  }
}

proc configurator::CreateMasterCmds {int masterCmds} {
  dict for {slaveCmd masterCmd} $masterCmds {
    $int alias $slaveCmd {*}$masterCmd
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
}

proc configurator::CreateSlaveCmds {int slaveCmds} {
  dict for {slaveCmd masterCmd} $slaveCmds {
    $int alias $slaveCmd $masterCmd $int
  }
}

proc configurator::Usage {msg} {
  return -code error -level 2 "wrong # args: should be \"$msg\""
}
