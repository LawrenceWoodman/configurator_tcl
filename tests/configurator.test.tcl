package require tcltest
namespace import tcltest::*

# Add module dir to tm paths
set ThisScriptDir [file dirname [info script]]
set ModuleDir [file normalize [file join $ThisScriptDir ..]]
::tcl::tm::path add $ModuleDir

source [file join $ThisScriptDir test_helpers.tcl]

package require configurator
namespace import configurator::*


test parseConfig-1 {Returns correct dictionary for script passed using \
-keys} -setup {
  set script {
    device /dev/hda
    desc {Main hdd}
    write_cache 1
    dma 1
    options ro boost
  }

  set keys {
    device {device 1 "1|0"}
    desc {desc 1 "description"}
    write_cache {write_cache 1 "1|0"}
    dma {dma 1 "1|0"}
    options {options many "option ?option ...?"}
  }
} -body {
  parseConfig -keys $keys $script
} -result [dict create device /dev/hda desc "Main hdd" write_cache 1 \
                       dma 1 options {ro boost}]

test parseConfig-2 {Returns correct dictionary for script passed without \
-keys} -setup {
  set script {
    device /dev/hda
    desc {Main hdd}
    write_cache 1
    dma 1
    options {ro boost}
  }
} -body {
  parseConfig $script
} -result [dict create device /dev/hda desc "Main hdd" write_cache 1 \
                       dma 1 options {ro boost}]

test parseConfig-3 {Ensure correct error when invalid command run} -setup {
  set script {
    bob 7
  }

  set keys {
    title {title 1 "title"}
  }

} -body {
  parseConfig -keys $keys $script
} -result {invalid command name "bob"} -returnCodes {error}

test parseConfig-4 {Ensure error raised when wrong number of arguments \
passed to fixed arg key} -setup {
  set script {
    title 2 hello how
  }

  set keys {
    title {title 2 "chapter title"}
  }

} -body {
  parseConfig -keys $keys $script
} -result {wrong # args: should be "title chapter title"} -returnCodes {error}

test parseConfig-5 {Ensure error raised when wrong number of arguments \
passed to many arg key} -setup {
  set script {
    options
  }

  set keys {
    options {options many "option ?option ...?"}
  }

} -body {
  parseConfig -keys $keys $script
} -result {wrong # args: should be "options option ?option ...?"} \
-returnCodes {error}

test parseConfig-6 {Ensure a key taking many arguments returns the \
values as a list even if only 1 item given} -setup {
  set script {
    titles "this is a title"
  }

  set keys {
    titles {titles many "title ?title ...?"}
  }

} -body {
  parseConfig -keys $keys $script
} -result [dict create titles [list {this is a title}]]

test parseConfig-7 {Ensure a key not specified by -keys returns an \
error when not passed any arguments} -setup {
  set script {
    title
  }
} -body {
  parseConfig $script
} -result {wrong # args: should be "title arg"} -returnCodes {error}

test parseConfig-8 {Ensure that you can use a different name for a key \
command than the field name} -setup {
  set script {
    !title "this is a title"
  }

  set keys {
    !title {title 1 "title title"}
  }

} -body {
  parseConfig -keys $keys $script
} -result [dict create title {this is a title}]

test parseConfig-9 {Ensure that namespace children are removed by \
default} -setup {
  set script {
    titles "this is a number: [::tcl::string::length "title"]"
  }

  set keys {
    title {title 1 "title title"}
  }
} -body {
  parseConfig -keys $keys $script
} -result {invalid command name "::tcl::string::length"} -returnCodes {error}

test parseConfig-10 {Ensure that commands are hidden by default} -setup {
  set script {
    set a 5
  }

  set keys {
    title {title 1 "title title"}
  }
} -body {
  parseConfig -keys $keys $script
} -result {invalid command name "set"} -returnCodes {error}

test parseConfig-11 {Ensure that commands can be exposed including \
using a different name} -setup {
  set script {
    set a 5
    titles "Title with the number $a in it" \
           "Five is [%string length "five"] characters long"
  }

  set keys {
    titles {titles many "title ?title ...?"}
  }

  set exposeCmds {
    set set
    %string string
  }
} -body {
  parseConfig -keys $keys -exposeCmds $exposeCmds $script
} -result [dict create titles [list \
  {Title with the number 5 in it} \
  {Five is 4 characters long}]]

test parseConfig-12 {Ensure that renamed exposed commands return correct \
error message when supplied with incorrect number of arguments} -setup {
  set script {
    %set a 5 7
  }

  set exposeCmds {
    %set set
  }
} -body {
  parseConfig -exposeCmds $exposeCmds $script
} -result {wrong # args: should be "%set varName ?newValue?"} \
-returnCodes {error}

test parseConfig-13 {Ensure that if setConfig commands run within procs \
they still update config appropriately} -setup {
  set script {
    proc setTitle sum {
      title "The sum is: $sum"
    }

    setTitle 5
  }

  set exposeCmds {
    proc proc
  }
} -body {
  parseConfig -exposeCmds $exposeCmds $script
} -result {title {The sum is: 5}}

test parseConfig-14 {Ensure that master commands can be called} -setup {
  set script {
    title "The sum of 5 and 6 is [sum 5 6]"
  }

  set masterCmds {
    sum tcl::mathop::+
  }
} -body {
  parseConfig -masterCmds $masterCmds $script
} -result {title {The sum of 5 and 6 is 11}}

test parseConfig-15 {Ensure that master commands work as command prefixes} \
-setup {
  set script {
    title "The sum of 5 and 6 is [add6 5]"
  }

  set masterCmds {
    add6 {tcl::mathop::+ 6}
  }
} -body {
  parseConfig -masterCmds $masterCmds $script
} -result {title {The sum of 5 and 6 is 11}}

test parseConfig-16 {Ensure that slave commands can interact with slave \
environment} -setup {
  set script {
    seta 7
    title "a is set to: $a"
  }

  set slaveCmds {
    seta TestHelpers::seta
  }

} -body {
  parseConfig -slaveCmds $slaveCmds $script
} -result {title {a is set to: 7}}

test parseConfig-17 {Ensure that namespace children are not removed when \
-slaveCmds is used} -setup {
  set script {
    title "this is a number: [::tcl::string::length "title"]"
  }

  set keys {
    title {title 1 "title title"}
  }
} -body {
  parseConfig -keys $keys -slaveCmds {} $script
} -result {title {this is a number: 5}}

test parseConfig-18 {Ensure that namespace children are not removed when \
-exposeCmds is used} -setup {
  set script {
    title "this is a number: [::tcl::string::length "title"]"
  }

  set keys {
    title {title 1 "title title"}
  }
} -body {
  parseConfig -keys $keys -exposeCmds {} $script
} -result {title {this is a number: 5}}

cleanupTests
