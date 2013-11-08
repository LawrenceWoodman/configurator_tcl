# A configuration parsing module
#
# Copyright (C) 2013 Lawrence Woodman <lwoodman@vlifesystems.com>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

package require Tcl 8.5
package require cmdline

namespace eval configurator {
  namespace export {[a-z]*}
}

proc configurator::parseConfig {commandMaps script} {
  set safeInterp [interp create -safe]

  catch {
    set config [dict create]
     $safeInterp eval {unset {*}[info vars]}

    # Hide all the comands
    foreach command [$safeInterp eval {info commands}] {
      $safeInterp hide $command
    }

    $safeInterp alias unknown \
                      configurator::UnknownHandler $commandMaps $safeInterp

    $safeInterp eval $script
    return $config
  } returnResult returnOptions

  interp delete $safeInterp
  return -options $returnOptions $returnResult
}

proc configurator::UnknownHandler {commandMaps int args} {
  foreach commandMap $commandMaps {
    lassign $commandMap slaveCmd masterCmd
    lassign $args commandExecuted
    if {$commandExecuted eq $slaveCmd} {
      set commandArgs [lrange $args 1 end]
      return [uplevel 1 [list {*}$masterCmd $int {*}$commandArgs]]
    }
  }
  return -code error "invalid command name \"$commandExecuted\""
}

proc configurator::SetConfig {key numValues argsUsage int args} {
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

proc configurator::Section {cmdName commandMaps argsUsage int args} {
  if {[llength $args] != 2} {
    Usage "$cmdName $argsUsage"
  }
  lassign $args sectionName script
  upvar config config
  dict set config $sectionName [
    configurator::parseConfig $commandMaps $script]
}

proc configurator::InvokeHiddenCmd {cmdName exposeAs int args} {
  set returnCode [catch {
    $int invokehidden $cmdName {*}$args
  } returnResult returnOptions]
  if {$returnCode == 1} {
    # Use $exposeAs name in error mesage
    set returnResult [regsub {(wrong # args: should be ")([^ ]+)( .*"$)} \
                             $returnResult                               \
                             "\\1$exposeAs\\3"]
  }
  return -code $returnCode -options $returnOptions $returnResult
}

proc configurator::makeSetConfigCmd {key numValues argsUsage} {
  list $key [list configurator::SetConfig $key $numValues $argsUsage]
}

proc configurator::makeSectionCmd {cmdName commandMaps argsUsage} {
  list $cmdName [list configurator::Section $cmdName $commandMaps $argsUsage]
}

proc configurator::exposeCmd {cmdName {exposeAs {}}} {
  if {[llength $exposeAs] == 0} {
    set exposeAs $cmdName
  }
  list $exposeAs [list configurator::InvokeHiddenCmd $cmdName $exposeAs]
}

proc configurator::Usage {msg} {
  return -code error -level 2 "wrong # args: should be \"$msg\""
}
