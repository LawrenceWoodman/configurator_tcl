configurator
============
A Tcl module to parse configuration scripts.

This module provides a simple way to parse a configuration script and create a dictionary from it.

Module Usage
------------
A configuration script is a valid Tcl script where the commands are used to set keys within the returned configuration dictionary.  If you don't pass the `-keys` option then any command that isn't recognised, is taken to be a command that sets a key with the same name to the single value given as an argument to it.

    package require configurator
    namespace import configurator::*

    set script {
      device /dev/hda
      desc {Main hdd}
      write_cache 1
      dma 1
      options {ro boost}
    }

    # Outputs a dictionary:
    #   device /dev/hda desc {Main hdd} write_cache 1 dma 1 options {ro boost}
    puts [parseConfig $script]

If you wanted to make the configuration script more resilient you can specify the accepted keys:

    set script {
      device /dev/hda
      desc {Main hdd}
      write_cache 1
      dma 1
      options ro boost
    }

    # Note the use of many, for options in the keys dictionary,
    # which allows options to take multiple values in the script.
    set keys {
      device {1 "1|0"}
      desc {1 "description"}
      write_cache {1 "1|0"}
      dma {1 "1|0"}
      options {many "option ?option ...?"}
    }

    # Outputs the same dictionary as above:
    #   device /dev/hda desc {Main hdd} write_cache 1 dma 1 options {ro boost}
    puts [parseConfig -keys $keys $script]


To make the configuration scripts more flexible you can export commands that have been hidden:

    set script {
      set a 5
      titles "Title with the number $a in it" \
             "Five is [%string length "five"] characters long"
    }

    set keys {
      titles {many "title ?title ...?"}
    }

    set exposeCmds {
      set set
      %string string
    }

    # Outputs a dictionary:
    #   titles {{Title with the number 5 in it} {Five is 4 characters long}
    puts [parseConfig -keys $keys -expose $exposeCmds $script]

If you wanted to be able to access commands from the master interpreter you can use the `-aliases` option:

    proc sum {a b} {
      expr {$a + $b}
    }

    set script {
      title "The sum of 5 and 6 is [%sum 5 6]"
    }

    set aliases {
      %sum sum
    }

    parseConfig -aliases $aliases $script


Exported Commands
-----------------

**configurator::parseConfig** _?-option value ...?_ _script_<br />
Parses the _script_ and outputs a dictionary representing the given configuration.The _option_s consist of:
<dl>
  <dt>-aliases</dt>
    <dd>A dictionary of slave interpreter commands mapped to master interpreter commands.  The keys are the slave interpreter command names and the values are the master interpreter command names.</dd>
  <dt>-expose</dt>
    <dd>A list of hidden commands to expose that takes the form: <code>exposeCommandName hiddenCommandName ?exposeCommandName hiddenCommandName ...?</code>.  When this option is chosen, instead of deleting the entire <code>::</code> namespace, the interpreter only hides the commands returned by <code>info commands</code>, so you will now be able to access for example <code>::string::length</code> as standard.</dd>
  <dt>-keys</dt>
    <dd>A dictionary of keys where each key is the key and the value is a list of the form: <code>{numValues argsUsage}</code>.</dd>
</dl>

Requirements
------------
*  Tcl 8.5+

Installation
------------
To install the module you can use the [installmodule.tcl](https://github.com/LawrenceWoodman/installmodule_tcl) script or if you want to manually copy the file `configurator-*.tm` to a specific location that Tcl expects to find modules.  This would typically be something like:

    /usr/share/tcltk/tcl8.6/tcl8/

To find out what directories are searched for modules, start `tclsh` and enter:

    foreach dir [split [::tcl::tm::path list]] {puts $dir}

or from the command line:

    $ echo "foreach dir [split [::tcl::tm::path list]] {puts \$dir}" | tclsh

Testing
-------
There is a testsuite in `tests/`.  To run it:

    $ tclsh tests/configurator.test.tcl

Contributions
-------------
If you want to improve this module make a pull request to the [repo](https://github.com/LawrenceWoodman/configurator_tcl) on github.  Please put any pull requests in a separate branch to ease integration and add a test to prove that it works.

Licence
-------
Copyright (C) 2013, Lawrence Woodman <lwoodman@vlifesystems.com>

This software is licensed under an MIT Licence.  Please see the file, LICENCE.md, for details.
