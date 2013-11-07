# A configuration parsing module
#
# Copyright (C) 2013 Lawrence Woodman <lwoodman@vlifesystems.com>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

package require Tcl 8.6
package require cmdline

namespace eval configurator {
  namespace export {[a-z]*}
}

proc configurator::parseConfig {args} {
  set options {
    {hidecmds "Hide all commands"}
    {exposecmds.arg {}
                    "Expose the specified commands to the slave interpreter"}
  }
  set thisCmdName [lindex [info level 0] 0]
  set usage ": $thisCmdName \[options] commands script\noptions:"
  array set params [::cmdline::getoptions args $options $usage]

  set safeInterp [interp create -safe]
  try {
    set config [dict create]
     $safeInterp eval {unset {*}[info vars]}

    if {$params(hidecmds)} {
      foreach command [$safeInterp eval {info commands}] {
        $safeInterp hide $command
      }
    }

    foreach exposeCmd $params(exposecmds) {
      $safeInterp expose $exposeCmd
    }

    lassign $args commandMaps script

    foreach commandMap $commandMaps {
      lassign $commandMap slaveCmd masterCmd
      $safeInterp alias $slaveCmd {*}$masterCmd
    }

    $safeInterp eval $script
  } finally {
    interp delete $safeInterp
  }
  return $config
}

proc configurator::SetConfig {key numValues argsUsage args} {
  set numArgs [llength $args]
  if { $numArgs == 0 || \
      ($numValues ne "many" && $numValues != $numArgs)} {
    Usage "$key $argsUsage"
  } else {
    upvar config config
    if {$numArgs == 1} {
      dict set config $key [lindex $args 0]
    } else {
      dict set config $key $args
    }
  }
}

proc configurator::Section {cmdName commandMaps argsUsage args} {
  if {[llength $args] != 2} {
    Usage "$cmdName $argsUsage"
  }
  lassign $args sectionName script
  upvar config config
  dict set config $sectionName [
    configurator::parseConfig $commandMaps $script]
}

proc configurator::makeSetConfigCmd {key numValues argsUsage} {
  list $key [list configurator::SetConfig $key $numValues $argsUsage]
}

proc configurator::makeSectionCmd {cmdName commandMaps argsUsage} {
  list $cmdName [list configurator::Section $cmdName $commandMaps $argsUsage]
}

proc configurator::Usage {msg} {
  return -code error -level 2 "wrong # args: should be \"$msg\""
}
