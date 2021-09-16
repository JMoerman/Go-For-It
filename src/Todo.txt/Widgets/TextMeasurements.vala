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
 * Provides a possibly terrible way to get the difference between the baseline
 * of text widgets and the center line of these widgets.
 * Idea: add these widgets to a container without actually drawing them but
 * calculating the baseline-center difference each time the size of this widget
 * is recalculated. (Actually, only size_allocate is used to calculate
 * this difference.)
 */
class GOFI.TXT.TextMeasurementWidget : Gtk.Container {

    public static int label_offset {
        get {
            return _label_offset;
        }
        private set {
            if (_label_offset != value) {
                _label_offset = value;
                call_queue_resize_on_listeners ();
            }
        }
    }
    private static int _label_offset;

    public static int entry_offset {
        get {
            return _entry_offset;
        }
        private set {
            if (_entry_offset != value) {
                _entry_offset = value;
                call_queue_resize_on_listeners ();
            }
        }
    }
    private static int _entry_offset;

    public static int get_label_baseline_offset () {
        return TextMeasurementWidget.label_offset;
    }
    public static int get_entry_baseline_offset () {
        return TextMeasurementWidget.entry_offset;
    }

    static construct {
        users = new GLib.List<unowned Gtk.Widget> ();
        _label_offset = 0;
        _entry_offset = 0;
    }

    private static GLib.List<unowned Gtk.Widget> users;

    public static void add_listener (Gtk.Widget widget) {
        users.prepend (widget);
    }
    public static void remove_listener (Gtk.Widget widget) {
        users.remove (widget);
    }

    private static void call_queue_resize_on_listeners () {
        foreach (var widget in users) {
            widget.queue_resize ();
        }
    }

    private Gtk.Label label;
    private Gtk.Entry entry;

    public signal void offsets_updated ();

    public TextMeasurementWidget () {
        base.set_has_window (false);
        base.set_can_focus (false);
        base.set_redraw_on_allocate (false);
        this.handle_border_width ();

        label = new Gtk.Label ("|");
        entry = new Gtk.Entry ();
        entry.text = "|";

        _set_child_parent (label);
        _set_child_parent (entry);

        label.show ();
        entry.show ();
        this.valign = Gtk.Align.BASELINE;
        label.valign = Gtk.Align.BASELINE;
        entry.valign = Gtk.Align.BASELINE;
    }

    private void _set_child_parent (Gtk.Widget? widget) {
        if (widget == null) {
            return;
        }
        widget.set_parent (this);
        widget.set_child_visible (true);
    }

    public override void forall_internal (bool include_internals, Gtk.Callback callback) {
        if (!include_internals) {
            return;
        }
        callback (label);
        callback (entry);
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        minimum_width = 0;
        natural_width = 0;
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        minimum_height = 0;
        natural_height = 0;
    }

    public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
        minimum_height = 0;
        natural_height = 0;
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        var child_allocation = allocation;
        int temp;
        int minimum_baseline;
        int natural_baseline;

        label.get_preferred_width (out child_allocation.width, out temp);

        label.get_preferred_height_and_baseline_for_width (
            allocation.width, out child_allocation.height, out temp,
            out minimum_baseline, out natural_baseline
        );

        label_offset = minimum_baseline - child_allocation.height / 2;
        // label.size_allocate (child_allocation); // Doesn't seem to help

        entry.get_preferred_width (out child_allocation.width, out temp);

        entry.get_preferred_height_and_baseline_for_width (
            allocation.width, out child_allocation.height, out temp,
            out minimum_baseline, out natural_baseline
        );

        entry_offset = minimum_baseline - child_allocation.height / 2;

        entry.size_allocate (child_allocation); // Seems to help

        base.size_allocate (allocation);
    }

    public override bool draw (Cairo.Context cr) {
        return true;
    }
}
