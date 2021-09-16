/* Copyright 2021 Go For It! developers
*
* This file is part of Go For It!.
*
* Go For It! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* Go For It! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with Go For It!. If not, see http://www.gnu.org/licenses/.
*/

/**
 * Version of Gtk.Stack that exports the baseline of the visible_child and
 * aligns itself using the baseline that it gets assigned.
 */
class BaselineStack : Gtk.Stack {
    public override void get_preferred_height_and_baseline_for_width (int width, out int minimum_height, out int natural_height, out int minimum_baseline, out int natural_baseline) {
        if (width < 0) {
            int temp;
            base.get_preferred_width (out width, out temp);
        }
        var child = visible_child;
        if (child != null) {
            child.get_preferred_height_and_baseline_for_width (
                width, out minimum_height, out natural_height,
                out minimum_baseline, out natural_baseline
            );
        } else {
            minimum_baseline = -1;
            natural_baseline = -1;
        }
        base.get_preferred_height_for_width (width, out minimum_height, out natural_height);
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        int baseline = get_allocated_baseline ();
        if (baseline > 0) {
            int minimum_height;
            int natural_height;
            int minimum_baseline;
            int natural_baseline;
            var child = visible_child;
            if (child != null) {
                child.get_preferred_height_and_baseline_for_width (
                    allocation.width, out minimum_height, out natural_height,
                    out minimum_baseline, out natural_baseline
                );
                // Make sure that the baseline of the child matches the baseline
                // that is assigned to this Stack by moving this Stack down.
                int correction = baseline - allocation.y - minimum_baseline;
                allocation.y += correction;
                allocation.height -= correction;
            }
        }

        base.size_allocate (allocation);
    }
}
