# $Id$

package require st_client

namespace eval ::stapi {
  # shared://port/[dir/]table[/stuff][?stuff]
  # options:
  #   -build dir
  #      Specify path to ctable build directory
  #
  variable ctable_serial 0
  variable shared_build_dir ""

  proc connect_shared {table_path {address ""} args} {
    variable shared_serial
    variable shared_build_dir

    if {[info exists shared_build_dir] && "$shared_build_dir" != ""]} {
      set opts(-build) $shared_build_dir
    }

    array set opts $args

    if {"$address" == ""} {
      set host localhost
      set port ""
    } elseif {![regexp {^(.*):(.*)$} $address _ host port]} {
      set host localhost
      set port $address
    }

    if {"$host" != "localhost" && "$host" != "127.0.0.1"} {
      return -code error "Can not make a shared connection to a remote server"
    }

    if {"$port" == ""} {
      set address $host
    } else {
      set address $host:$port
    }

    set uri ctable://$address/$table_path

    set ns ::stapi::shared[incr shared_serial]
    namespace eval $::ns [list proc handler {args} [info body shared_handler]]

    remote_ctable $uri ${ns}::master
    set handle [${ns}::master attach [pid]]
    set table [${ns}::master type]

    if [info exist opts(-build)] {
      if {[lsearch $::auto_path $opts(-build)] == -1} {
	lappend ::auto_path $opts(-build)
      }
    }

    namespace eval :: [list package require [string totitle $table]]
    $table create ${ns}::shared reader $handle

    set ${ns}::handle $handle
    set ${ns}::table $table
    return ${ns}::handler
  }
  register shared connect_shared

  # Simple handler, most commands are passed straight to the master.
  proc shared_handler {args} {
    set method [lindex $args 0]
    switch -glob -- [lindex $args 0] {
      search* {
	uplevel 1 [namespace which reader] $args
      }
      destroy {
	master destroy
	reader destroy
      }
      default {
	uplevel 1 [namespace which master] $args
      }
    }
  }
}

package provide st_shared 1.0
