# place_inverters.tcl (Quartus Lite-safe)
# Manual LAB list version (no get_locations).
#
# Steps:
#   1) Fill in the LAB_LIST below with 16 valid LAB_X#_Y# strings from Chip Planner.
#   2) source place_inverters.tcl
#   3) place_inverters 13 16
#
# For extra credit alternate placement:
#   - Make a second LAB list (different region) OR call with offset if you provide more than 16 entries.

package require ::quartus::project
package require ::quartus::flow

# ---------------------------
# EDIT THIS: paste valid LAB locations you saw in Chip Planner
# Must contain at least num_chains entries (16 for your case).
# Example format: LAB_X12_Y34
# ---------------------------
set LAB_LIST {
    LAB_X39_Y30
    LAB_X39_Y29
	 LAB_X39_Y28
	 LAB_X39_Y27
	 LAB_X39_Y26
	 LAB_X39_Y25
	 LAB_X39_Y24
	 LAB_X39_Y23
	 LAB_X39_Y22
	 LAB_X39_Y21
	 LAB_X39_Y20
	 LAB_X39_Y19
	 LAB_X39_Y18
	 LAB_X39_Y17
	 LAB_X39_Y16
	 LAB_X39_Y15
}

set LAB_LIST_ORIG {
    LAB_X16_Y30
    LAB_X16_Y29
	 LAB_X16_Y28
	 LAB_X16_Y27
	 LAB_X16_Y26
	 LAB_X16_Y25
	 LAB_X16_Y24
	 LAB_X16_Y23
	 LAB_X16_Y22
	 LAB_X16_Y21
	 LAB_X16_Y20
	 LAB_X16_Y19
	 LAB_X16_Y18
	 LAB_X16_Y17
	 LAB_X16_Y16
	 LAB_X16_Y15
}

# ---------------------------
# Helpers
# ---------------------------

proc _extract_chain_idx {full} {
    if {[regexp {gen_ros:([0-9]+)} $full -> c]} { return $c }
    if {[regexp {gen_ros\(([0-9]+)\)} $full -> c]} { return $c }
    return -1
}

proc _extract_stage_idx {full} {
    if {[regexp {stage\[([0-9]+)\]} $full -> s]} { return $s }
    return -1
}

proc _cmp_tuple {a b} {
    set ca [lindex $a 0]; set sa [lindex $a 1]
    set cb [lindex $b 0]; set sb [lindex $b 1]
    if {$ca < $cb} {return -1}
    if {$ca > $cb} {return 1}
    if {$sa < $sb} {return -1}
    if {$sa > $sb} {return 1}
    return [string compare [lindex $a 2] [lindex $b 2]]
}

proc _collect_stage_nodes {} {
    # If this returns 0, change post_fitter -> post_synthesis
    set coll [get_names -filter "*|stage[*]*" -observable_type post_fitter]
    set nodes {}
    foreach_in_collection n $coll {
        set full [get_name_info -info full_path $n]
        set c [_extract_chain_idx $full]
        set s [_extract_stage_idx $full]
        if {$s >= 0} {
            lappend nodes [list $c $s $full]
        }
    }
    return [lsort -command _cmp_tuple $nodes]
}

# ---------------------------
# Main
# ---------------------------

proc place_inverters {n_total num_chains {offset 0}} {
    global LAB_LIST

    if {[llength $LAB_LIST] < ($offset + $num_chains)} {
        error "LAB_LIST does not have enough entries. Need at least offset+num_chains."
    }

    puts "---- place_inverters (manual LAB list) ----"
    puts "Constrain: stage[1] of each chain into LABs from LAB_LIST"
    puts "Chains=$num_chains, n_total=$n_total, offset=$offset"
    puts "LAB_LIST entries=[llength $LAB_LIST]"

    set nodes [_collect_stage_nodes]
    if {[llength $nodes] == 0} {
        puts "ERROR: Found 0 stage[*] nodes."
        puts "Fix: edit _collect_stage_nodes and switch observable_type post_fitter -> post_synthesis"
        return
    }

    # Build stage[1] anchor per chain
    array set chain_stage1 {}
    foreach t $nodes {
        set c [lindex $t 0]
        set s [lindex $t 1]
        set full [lindex $t 2]
        if {$s == 1} {
            set chain_stage1($c) $full
        }
    }

    # Chain order 0..num_chains-1 if possible
    set chain_order {}
    for {set c 0} {$c < $num_chains} {incr c} {
        if {[info exists chain_stage1($c)]} {
            lappend chain_order $c
        }
    }
    if {[llength $chain_order] == 0} {
        set chain_order [lsort -integer [array names chain_stage1]]
        puts "WARNING: Using discovered chain keys: $chain_order"
    }

    # Remove old location assignments for anchors
    foreach c $chain_order {
        catch { remove_location_assignment -to $chain_stage1($c) }
    }

    # Assign each chain to a distinct LAB
    set placed 0
    for {set i 0} {$i < $num_chains} {incr i} {
        set c    [lindex $chain_order $i]
        set node $chain_stage1($c)
        set lab  [lindex $LAB_LIST [expr {$offset + $i}]]

        catch { set_location_assignment $lab -to $node }
        incr placed
    }

    puts "Placed $placed stage[1] anchors into LABs."
    puts "Next: Full Compilation -> Chip Planner screenshot -> Memory screenshot."
}

puts "Loaded place_inverters.tcl (manual LAB list version)."
puts "Edit LAB_LIST at the top, then call: place_inverters 13 16"