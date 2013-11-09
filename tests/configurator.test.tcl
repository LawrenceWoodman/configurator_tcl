package require tcltest
namespace import tcltest::*

# Add module dir to tm paths
set ThisScriptDir [file dirname [info script]]
set ModuleDir [file normalize [file join $ThisScriptDir ..]]
::tcl::tm::path add $ModuleDir

package require configurator
namespace import configurator::*


test makeSetConfigCmd-1 {Returns a list where the first element is the key} {
  set commandMap [makeSetConfigCmd device 1 "1|0"]
  lindex $commandMap 0
} device

test makeSetConfigCmd-2 {Returns a list referencing a function that will fail \
if the wrong number of arguments passed to it} -setup {
  set commandMap [makeSetConfigCmd device 1 "1|0"]
  set safeInterp [interp create -safe]
  set config [dict create]
  set cmd [lindex $commandMap 1]
} -body {
  {*}$cmd $safeInterp config
} -result {wrong # args: should be "device 1|0"} -returnCodes {error}

test makeSetConfigCmd-3 {Returns a list referencing a function that will \
accept many arguments if requested} -setup {
  set commandMap [makeSetConfigCmd options many "option ?option ..?"]
  set safeInterp [interp create -safe]
  set config [dict create]
  set cmd [lindex $commandMap 1]
} -body {
  {*}$cmd $safeInterp config 1 5 4 hello
} -result [dict create options {1 5 4 hello}]

test makeSetConfigCmd-4 {Returns a list referencing a function that will \
fail if many arguments requested but none given} -setup {
  set commandMap [makeSetConfigCmd options many "option ?option ..?"]
  set safeInterp [interp create -safe]
  set config [dict create]
  set cmd [lindex $commandMap 1]
} -body {
  {*}$cmd $safeInterp config
} -result {wrong # args: should be "options option ?option ..?"} \
  -returnCodes {error}


test makeSectionCmd-1 {Returns a list referencing a function that will \
fail with a sensible error message if wrong number of arguments given} -setup {
  set deviceSectionAliases [list [makeSetConfigCmd dma 1 "1|0"]]
  set commandMap [makeSectionCmd device $deviceSectionAliases \
                                 "deviceName deviceDetails"]
  set safeInterp [interp create -safe]
  set config [dict create]
  set cmd [lindex $commandMap 1]
} -body {
  {*}$cmd $safeInterp config
} -result {wrong # args: should be "device deviceName deviceDetails"} \
  -returnCodes {error}

test makeSectionCmd-2 {Returns a list referencing a function that will \
create a nested dictionary and parse a script} -setup {
  set deviceSectionAliases [list             \
    [makeSetConfigCmd write_cache 1 "1|0"]   \
    [makeSetConfigCmd dma 1 "1|0"]]
  set commandMap [makeSectionCmd device $deviceSectionAliases \
                                 "deviceName deviceDetails"]
  set deviceScript {
    write_cache 1
    dma 1
  }
  set safeInterp [interp create -safe]
  set config [dict create]
  set cmd [lindex $commandMap 1]
} -body {
  {*}$cmd $safeInterp config /dev/hda $deviceScript
} -result [dict create /dev/hda [dict create write_cache 1 dma 1]]


test parseConfig-1 {Returns correct dictionary for script passed} -setup {
  set script {
    device /dev/hda
    write_cache 1
    dma 1
    options ro boost
  }

  set commandMaps [list \
    [makeSetConfigCmd device 1 "1|0"]                       \
    [makeSetConfigCmd write_cache 1 "1|0"]                  \
    [makeSetConfigCmd dma 1 "1|0"]                          \
    [makeSetConfigCmd options many "option ?option ..?"]]
} -body {
  parseConfig $commandMaps $script
} -result [dict create device /dev/hda write_cache 1 dma 1 options {ro boost}]

test parseConfig-2 {Returns nested dictionary for script passed} -setup {
  set script {
    device /dev/hda {
      write_cache 1
      dma 1
      options ro boost
    }

    device /dev/hdb {
      write_cache 0
      dma 0
      options rw stable
    }
  }

  set deviceSectionAliases [list \
    [makeSetConfigCmd write_cache 1 "1|0"]                  \
    [makeSetConfigCmd dma 1 "1|0"]                          \
    [makeSetConfigCmd options many "option ?option ..?"]]

  set commandMaps [list \
    [makeSectionCmd device $deviceSectionAliases "deviceName deviceDetails"]]

} -body {
  parseConfig $commandMaps $script
} -result [dict create /dev/hda [dict create        \
                                      write_cache 1 \
                                      dma 1         \
                                      options {ro boost}]   \
                       /dev/hdb [dict create        \
                                      write_cache 0 \
                                      dma 0         \
                                      options {rw stable}]]

test parseConfig-3 {Ensure correct error when invalid command run} -setup {
  set script {
    bob 7
  }

  set commandMaps [list \
    [makeSetConfigCmd title 1 "title"]]

} -body {
  parseConfig $commandMaps $script
} -result {invalid command name "bob"} -returnCodes {error}

test parseConfig-4 {Ensure exposed commands are run in correct scope} -setup {
  set script {
    set a 5
    title "The answer to 2 + $a is [expr {2 + $a}]"
  }

  set commandMaps [list                 \
    [makeSetConfigCmd title 1 "title"]  \
    [exposeCmd set]                     \
    [exposeCmd expr]]
} -body {
  parseConfig $commandMaps $script
} -result {title {The answer to 2 + 5 is 7}}

test parseConfig-5 {Ensure that renamed exposed commands return correct \
error message when supplied with incorrect number of arguments} -setup {
  set script {
    %set a 5 7
  }

  set commandMaps [list [exposeCmd set %set]]
} -body {
  parseConfig $commandMaps $script
} -result {wrong # args: should be "%set varName ?newValue?"} \
-returnCodes {error}

test parseConfig-6 {Ensure that if setConfig commands run within procs they \
still update config appropriately} -setup {
  set script {
    proc setTitle sum {
      title "The sum is: $sum"
    }

    setTitle 5
  }

  set commandMaps [list                 \
    [makeSetConfigCmd title 1 "title"]  \
    [exposeCmd proc]]
} -body {
  parseConfig $commandMaps $script
} -result {title {The sum is: 5}}

cleanupTests
