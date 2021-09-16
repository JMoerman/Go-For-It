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

public delegate int BaselineOffsetFunc ();

/**
 * Hacky version of Gtk.Bin which centers is child vertically with regards to
 * the text of another widget. The baseline of this other widget is used to
 * align the child widget. As the baseline isn't a center line we need an offset
 * to reconstruct this center line from.
 */
class BaselineCenterBin : Gtk.Bin {

    public void set_offset_func (owned BaselineOffsetFunc? _offset_func) {
        offset_func = (owned) _offset_func;
    }
    private BaselineOffsetFunc? offset_func;

    public override void get_preferred_height_and_baseline_for_width (int width, out int minimum_height, out int natural_height, out int minimum_baseline, out int natural_baseline) {
        if (width < 0) {
            int temp;
            base.get_preferred_width (out width, out temp);
        }
        base.get_preferred_height_for_width (width, out minimum_height, out natural_height);
        if (offset_func != null) {
            var baseline_offset = offset_func ();
            minimum_baseline = minimum_height / 2 + baseline_offset;
            natural_baseline = natural_height / 2 + baseline_offset;
        } else {
            minimum_baseline = -1;
            natural_baseline = -1;
        }
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        int baseline = get_allocated_baseline ();
        int minimum_height;
        int natural_height;
        base.get_preferred_height_for_width (allocation.width, out minimum_height, out natural_height);
        if (baseline > 0) {
            if (offset_func != null) {
                var baseline_offset = offset_func ();
                int correction = baseline - allocation.y - (minimum_height / 2) - baseline_offset;
                allocation.y += correction;
                allocation.height -= correction;
            }

        }
        base.size_allocate (allocation);
    }
}
