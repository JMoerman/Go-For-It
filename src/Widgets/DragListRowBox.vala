/* Copyright 2020 Go For It! developers
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

// This basic horizontal box as Gtk.Box has some undesirable behavior when using
// a height-for-width child.
// This container also aligns the start and end widgets above the baseline of
// the center widget, if the space is available.
class GOFI.DragListRowBox : Gtk.Container {
    private Gtk.Widget _start_widget;
    private Gtk.Widget _center_widget;
    private Gtk.Widget _end_widget;
    private int requested_edge_height;

    public int h_spacing {
        get {
            return _h_spacing;
        }
        set {
            _h_spacing = value;
        }
    }
    private int _h_spacing;

    public Gtk.Widget? start_widget {
        get {
            return _start_widget;
        }
        set {
            _remove (_start_widget);
            _start_widget = value;
            _set_child_parent (value);
        }
    }

    public Gtk.Widget? center_widget {
        get {
            return _center_widget;
        }
        set {
            _remove (_center_widget);
            _center_widget = value;
            _set_child_parent (value);
        }
    }

    public Gtk.Widget? end_widget {
        get {
            return _end_widget;
        }
        set {
            _remove (_end_widget);
            _end_widget = value;
            _set_child_parent (value);
        }
    }

    public DragListRowBox (int h_spacing = 0) {
        base.set_has_window (false);
        base.set_can_focus (true);
        base.set_redraw_on_allocate (false);

        this._h_spacing = h_spacing;

        this.handle_border_width ();

        this._start_widget = null;
        this._center_widget = null;
        this._end_widget = null;
    }

    public override void add (Gtk.Widget widget) {
        if (_center_widget == null) {
            center_widget = widget;
        }
    }

    private void _set_child_parent (Gtk.Widget? widget) {
        if (widget == null) {
            return;
        }
        widget.set_parent (this);
        widget.set_child_visible (true);
    }

    private void _remove (Gtk.Widget? widget) {
        if (widget == null) {
            return;
        }
        widget.unparent ();
        if (visible && widget.visible) {
            queue_resize ();
        }
    }

    public override void remove (Gtk.Widget widget) {
        if (_end_widget == widget) {
            _end_widget = null;
        } else if (_center_widget == widget) {
            _center_widget = null;
        } else if (_start_widget == widget) {
            _start_widget = null;
        } else {
            return;
        }
        _remove (widget);
    }

    public override void forall_internal (bool include_internals, Gtk.Callback callback) {
        if (_start_widget != null) {
            callback (_start_widget);
        }
        if (_center_widget != null) {
            callback (_center_widget);
        }
        if (_end_widget != null) {
            callback (_end_widget);
        }
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        int edge_min = 0;
        int center_min = 0;
        int center_nat = 0;

        get_edge_width (out edge_min);
        if (edge_min > 0) {
            if (
                _start_widget == null || !_start_widget.visible ||
                _end_widget == null || !_end_widget.visible
            ) {
                edge_min += _h_spacing;
            } else {
                edge_min += edge_min + 2 * _h_spacing;
            }
        }

        if (_center_widget != null && _center_widget.visible) {
            _center_widget.get_preferred_width (out center_min, out center_nat);
        }

        minimum_width = center_min + edge_min;
        natural_width = center_nat + edge_min;

        if (minimum_width == 0) {
            return;
        }
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        int minimum_width;
        get_preferred_width (out minimum_width, null);
        get_preferred_height_for_width (minimum_width, out minimum_height, out natural_height);
    }

    private void get_edge_width (out int width) {
        width = 0;

        if (_start_widget != null && _start_widget.visible) {
            _start_widget.get_preferred_width (out width, null);
        }
        if (_end_widget != null && _end_widget.visible) {
            int end_min;
            _end_widget.get_preferred_width (out end_min, null);

            width = int.max (end_min, width);
        }
    }

    private void get_edge_height (int width, out int height, out int nat_height) {
        height = 0;
        nat_height = 0;

        if (_start_widget != null && _start_widget.visible) {
            _start_widget.get_preferred_height_for_width (width, out height, out nat_height);
        }
        if (_end_widget != null && _end_widget.visible) {
            int end_min;
            int end_nat;
            _end_widget.get_preferred_height_for_width (width, out end_min, out end_nat);

            height = int.max (end_min, height);
            nat_height = int.max (end_nat, nat_height);
        }
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        int edge_width, edge_height;
        get_edge_width (out edge_width);
        get_edge_height (edge_width, out edge_height, null);

        int child_height = allocation.height;

        Gtk.Widget left;
        Gtk.Widget right;

        if (get_direction () != Gtk.TextDirection.RTL) {
            left = _start_widget;
            right = _end_widget;
        } else {
            left = _end_widget;
            right = _start_widget;
        }
        int baseline = 0;

        if (_center_widget != null && _center_widget.visible) {
            Gtk.Allocation center_alloc = Gtk.Allocation ();
            if (left != null && left.visible) {
                center_alloc.x = allocation.x + edge_width + _h_spacing;
            } else {
                center_alloc.x = allocation.x;
            }
            center_alloc.width = allocation.width - center_alloc.x + allocation.x;
            if (right != null && right.visible) {
                center_alloc.width -= _h_spacing + edge_width;
            }
            int min_height, nat_height, baseline_min;
            _center_widget.get_preferred_height_and_baseline_for_width (
                center_alloc.width, out min_height, out nat_height,
                out baseline_min, out baseline
            );
            center_alloc.y = allocation.y;
            center_alloc.height = child_height;
            if (nat_height < child_height) {
                baseline = baseline_min;
                if (!_center_widget.vexpand) {
                    int offset = (child_height - nat_height) / 2;
                    center_alloc.y = allocation.y + offset;
                    center_alloc.height = nat_height;
                    if (baseline > 0) {
                        baseline += offset;
                    }
                }
            }

            _center_widget.size_allocate (center_alloc);
        }

        int edge_y = allocation.y;
        int edge_wid_height = child_height;

        if (requested_edge_height <= child_height && baseline > 0) {
            edge_wid_height = requested_edge_height;
            int y_offset = baseline - requested_edge_height;
            edge_y = int.max (edge_y, edge_y + y_offset);
        }

        if (left != null && left.visible) {
            Gtk.Allocation start_alloc = Gtk.Allocation ();
            start_alloc.x = allocation.x;
            start_alloc.y = edge_y;
            start_alloc.height = edge_wid_height;
            start_alloc.width = edge_width;

            left.size_allocate (start_alloc);
        }

        if (right != null && right.visible) {
            Gtk.Allocation end_alloc = Gtk.Allocation ();
            end_alloc.x = allocation.x + allocation.width - edge_width;
            end_alloc.y = edge_y;
            end_alloc.height = edge_wid_height;
            end_alloc.width = edge_width;

            right.size_allocate (end_alloc);
        }

        base.size_allocate (allocation);
    }

    public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
        if (width < 0) {
            get_preferred_width (out width, null);
        }
        int edge_width;
        get_edge_width (out edge_width);
        get_edge_height (edge_width, out minimum_height, out requested_edge_height);
        natural_height = requested_edge_height;
        int edge_taken = 0;

        if (_start_widget != null && _start_widget.visible) {
            edge_taken += edge_width + _h_spacing;
        }
        if (_end_widget != null && _end_widget.visible) {
            edge_taken += edge_width + _h_spacing;
        }

        if (_center_widget != null && _center_widget.visible) {
            int center_min, center_nat;
            _center_widget.get_preferred_height_for_width (
                width - edge_taken,
                out center_min, out center_nat
            );
            minimum_height = int.max (minimum_height, center_min);
            natural_height = int.max (natural_height, center_nat);
        }
    }
}
