/* Copyright 2017-2020 Go For It! developers
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

using GOFI.TXT.TxtUtils;

class GOFI.TXT.TaskRowLayout : Gtk.Container {
    private Gtk.CheckButton check_button;
    private Gtk.Button delete_button;
    private TaskMarkupLabel markup_label;
    private Gtk.Label status_label;
    private Gtk.Entry edit_entry;
    private Gtk.Button close_edit_button;

    private Gtk.Stack title_stack;
    private Gtk.Stack misc_stack;

    private Gtk.Button sched_button;
    private Gtk.Label due_label;

    private Gtk.Label threshold_label;

    private Gtk.Image recur_indicator;

    private Gtk.ToggleButton timer_button;
    private Gtk.Image timer_image;

    private Gtk.Revealer due_revealer;
    private Gtk.Revealer threshold_revealer;
    private Gtk.Revealer recur_revealer;

    private Gtk.ToggleButton timer_value_button;
    private TaskTimerValuePopover? timer_popover;

    private bool editing;
    private bool string_changed;

    private const string FILTER_PREFIX = "gofi:";

    public int column_spacing {
        get;
        set;
        default = 6;
    }

    public bool is_editing {
        get {
            return editing;
        }
    }

    public bool is_active {
        set {
            if (value) {
                timer_image.set_from_icon_name (
                    "media-playback-start-symbolic", Gtk.IconSize.BUTTON
                );
            } else {
                timer_image.set_from_icon_name (
                    "media-playback-pause-symbolic", Gtk.IconSize.BUTTON
                );
            }
        }
    }

    public TxtTask task {
        get;
        private set;
    }

    public signal void task_selected ();
    public signal void timer_started (bool start);
    public signal void link_clicked (string uri);
    public signal void deletion_requested ();

    public TaskRowLayout (TxtTask task) {
        base.set_has_window (true);
        base.set_can_focus (false);
        base.set_redraw_on_allocate (false);

        this.handle_border_width ();

        this.task = task;

        initialize_contents ();
    }

    private void initialize_contents () {
        check_button = new Gtk.CheckButton ();
        check_button.active = task.done;
        var sc = kbsettings.get_shortcut (KeyBindingSettings.SCK_MARK_TASK_DONE);
        check_button.tooltip_markup = sc.get_accel_markup (_("Mark the task as complete"));

        _set_child_parent (check_button);
        check_button.show_all ();

        initialize_title_area ();
        initialize_misc_area ();
        connect_signals ();
    }

    private void initialize_title_area () {
        markup_label = new TaskMarkupLabel (task);
        status_label = new Gtk.Label (null);
        status_label.use_markup = true;
        status_label.no_show_all = true;
        update_status_label ();

        var label_box = new DynOrientationBox (2, 0);
        label_box.set_primary_widget (markup_label);
        label_box.set_secondary_widget (status_label);
        label_box.valign = Gtk.Align.BASELINE;
        markup_label.halign = Gtk.Align.START;
        markup_label.valign = Gtk.Align.BASELINE;
        status_label.halign = Gtk.Align.END;
        status_label.valign = Gtk.Align.BASELINE;

        edit_entry = new Gtk.Entry ();
        close_edit_button = new Gtk.Button.from_icon_name ("collapse-symbolic");
        close_edit_button.get_style_context ().add_class ("flat");
        var edit_grid = new Gtk.Grid ();
        edit_grid.orientation = Gtk.Orientation.HORIZONTAL;
        edit_grid.add (edit_entry);
        edit_grid.add (close_edit_button);
        edit_entry.hexpand = true;

        title_stack = new Gtk.Stack ();
        title_stack.homogeneous = false;
        title_stack.interpolate_size = true;
        title_stack.transition_type = Gtk.StackTransitionType.SLIDE_DOWN;

        title_stack.add_named (label_box, "label");
        title_stack.add_named (edit_grid, "edit_entry");

        _set_child_parent (title_stack);
        title_stack.show_all ();
    }

    private void initialize_misc_area () {

        timer_value_button = new Gtk.ToggleButton.with_label ("-");
        update_timer_value_label ();

        delete_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);

        var creation_info_widget = get_creation_time_widget ();

        sched_button = new Gtk.Button ();
        due_label = new Gtk.Label (null);
        threshold_label = new Gtk.Label (null);
        recur_indicator = new Gtk.Image.from_icon_name (
            "media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON
        );

        due_revealer = new Gtk.Revealer ();
        threshold_revealer = new Gtk.Revealer ();
        recur_revealer = new Gtk.Revealer ();

        due_revealer.add (due_label);
        threshold_revealer.add (threshold_label);
        recur_revealer.add (recur_indicator);

        update_schedule_labels (new DateTime.now_local ());

        var sched_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        sched_box.add (threshold_revealer);
        sched_box.add (due_revealer);
        sched_box.add (recur_revealer);

        sched_button.add (sched_box);

        var bottom_bar = new Gtk.Grid ();
        bottom_bar.margin_top = 6;
        bottom_bar.row_spacing = 6;

        if (!task.done) {
            timer_button = new Gtk.ToggleButton ();
            timer_image = new Gtk.Image.from_icon_name (
                "media-playback-start-symbolic", Gtk.IconSize.BUTTON
            );
            timer_button.add (timer_image);
            timer_button.clicked.connect (() => task_selected ());

            var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            button_box.add (timer_value_button);
            button_box.add (timer_button);
            bottom_bar.attach (button_box, 0, 0, 3, 1);
            button_box.get_style_context ().add_class ("linked");
        } else {
            bottom_bar.attach (timer_value_button, 0, 0, 3, 1);
        }
        timer_value_button.hexpand = true;

        bottom_bar.attach (sched_button, 0, 1);
        sched_button.hexpand = true;
        sched_button.halign = Gtk.Align.START;
        if (creation_info_widget != null) {
            bottom_bar.attach (creation_info_widget, 1, 1);
        }
        bottom_bar.attach (delete_button, 2, 1);

        misc_stack = new Gtk.Stack ();
        misc_stack.vhomogeneous = false;
        misc_stack.interpolate_size = true;
        misc_stack.transition_type = Gtk.StackTransitionType.SLIDE_DOWN;
        misc_stack.add_named (new Gtk.Grid (), "inactive");
        misc_stack.add_named (bottom_bar, "active");

        _set_child_parent (misc_stack);
        misc_stack.show_all ();
    }

    private Gtk.Widget? get_creation_time_widget () {
        GOFI.Date? completion_date = task.completion_date;
        GOFI.Date? creation_date = task.creation_date;
        if (creation_date == null) {
            return null;
        }
        return new ExplanationWidget (
            get_creation_time_info_str (creation_date, completion_date)
        );
    }

    private string get_creation_time_info_str (GOFI.Date creation_date, GOFI.Date? completion_date) {
        /// See https://valadoc.org/glib-2.0/GLib.DateTime.format.html for
        // formatting of DateTime
        string date_format = _("%Y-%m-%d");

        if (task.done && completion_date != null) {
            return _("Task completed at %1$s, created at %2$s").printf (
                completion_date.dt.format (date_format),
                creation_date.dt.format (date_format)
            );
        } else {
            return _("Task created at %s").printf (
                    creation_date.dt.format (date_format)
            );
        }
    }

    private void update_schedule_labels (DateTime now) {
        var threshold_date = task.threshold_date;
        var due_date = task.due_date;
        if (due_date == null && threshold_date == null) {
            due_label.label = "📅 " + _("Schedule");
            due_revealer.reveal_child = true;
            return;
        }

        string threshold_str = null;
        if (threshold_date != null) {
            bool show_year = threshold_date.dt.get_year () != now.get_year ();
            var date_format =
                Granite.DateTime.get_default_date_format (false, true, show_year);
            threshold_str = threshold_date.dt.format (date_format);
            threshold_label.label = "👁️ " + threshold_str;
            threshold_revealer.reveal_child = true;
        } else {
            threshold_revealer.reveal_child = false;
        }

        string due_str = null;
        if (due_date != null) {
            bool show_year = due_date.dt.get_year () != now.get_year ();
            var date_format =
                Granite.DateTime.get_default_date_format (false, true, show_year);
            due_str = due_date.dt.format (date_format);
            due_label.label = "📅 " + due_str;
            due_revealer.reveal_child = true;
        } else {
            due_revealer.reveal_child = false;
        }

        var recur_mode = task.recur_mode;

        if (recur_mode != RecurrenceMode.NO_RECURRENCE) {
            recur_revealer.reveal_child = true;
        } else {
            recur_revealer.reveal_child = false;
        }
    }

    private void update_status_label () {
        var timer_value = task.timer_value;
        if (task.done && timer_value >= 60) {
            var timer_value_str = Utils.seconds_to_pretty_string (timer_value);
            status_label.label = "<i>%s</i>".printf (timer_value_str);
            status_label.show ();
        } else if ((task.status & TaskStatus.TIMER_ACTIVE) != 0) {
            status_label.label = "⏰";
            status_label.show ();
        } else {
            status_label.hide ();
        }
    }

    private void update_timer_value_label () {
        var duration = task.duration;
        var timer_value = task.timer_value;
        string timer_str = Utils.seconds_to_separated_timer_string (timer_value);
        if (duration > 0) {
            timer_value_button.label = _("%1$s / %2$s").printf (
                timer_str,
                Utils.seconds_to_separated_timer_string (duration)
            );
        } else {
            timer_value_button.label = timer_str;
        }
    }

    public void edit (bool wrestle_focus=false) {
        if (editing) {
            return;
        }

        edit_entry.text = task.to_simple_txt ();
        string_changed = false;

        title_stack.visible_child_name = "edit_entry";
        misc_stack.visible_child_name = "active";

        edit_entry.grab_focus ();

        editing = true;
        warning ("stub");
        return;
    }

    public void stop_editing () {
        if (!editing) {
            return;
        }
        title_stack.visible_child_name = "label";
        misc_stack.visible_child_name = "inactive";
        editing = false;
    }

    private void connect_signals () {
        timer_value_button.clicked.connect (on_timer_value_button_clicked);
        sched_button.clicked.connect (on_sched_button_clicked);
        delete_button.clicked.connect (on_delete_button_clicked);
        check_button.toggled.connect (on_check_toggled);
        markup_label.activate_link.connect (on_activate_link);

        key_release_event.connect (on_row_key_release);
        edit_entry.key_release_event.connect (on_entry_key_release);

        task.done_changed.connect (on_task_done_changed);
        task.notify["status"].connect (on_task_status_changed);
        task.notify["timer-value"].connect (on_task_duration_changed);
        task.notify["duration"].connect (on_task_duration_changed);

        edit_entry.focus_out_event.connect (on_entry_focus_out);
        edit_entry.activate.connect (update_task_from_entry_string);
        edit_entry.changed.connect (on_entry_changed);

        close_edit_button.clicked.connect (stop_editing);
    }

    private void on_task_duration_changed () {
        update_status_label ();
        update_timer_value_label ();
    }

    private void on_check_toggled () {
        task.done = !task.done;
    }

    private void on_task_done_changed () {
        destroy ();
    }

    private void on_task_status_changed () {
        var status = task.status;
        if ((status & TaskStatus.TIMER_SELECTED) != TaskStatus.NONE) {
            if ((status & TaskStatus.TIMER_ACTIVE) != TaskStatus.NONE) {
                timer_image.set_from_icon_name (
                    "media-playback-pause-symbolic", Gtk.IconSize.BUTTON
                );
            } else {
                timer_image.set_from_icon_name (
                    "media-playback-start-symbolic", Gtk.IconSize.BUTTON
                );
            }
        } else {
            timer_image.set_from_icon_name (
                "media-playback-start-symbolic", Gtk.IconSize.BUTTON
            );
        }
        update_status_label ();
    }

    private bool on_activate_link (string uri) {
        if (uri.has_prefix (FILTER_PREFIX)) {
            link_clicked (uri.offset (FILTER_PREFIX.length));
            return true;
        }
        return false;
    }

    private void on_timer_value_button_clicked () {
        if (timer_popover == null) {
            timer_popover = new TaskTimerValuePopover (timer_value_button, task);
            timer_popover.popup ();
            timer_popover.hide.connect (on_popover_hidden);
        } else {
            timer_popover.popdown ();
        }
    }

    private void on_popover_hidden () {
        timer_value_button.active = false;

        GLib.Idle.add (on_popover_animation_finished);
    }

    private bool on_popover_animation_finished () {
        timer_popover.destroy ();
        timer_popover = null;

        return GLib.Source.REMOVE;
    }

    private void on_sched_button_clicked () {
        var dia = new SimpleRecurrenceDialog (this.get_toplevel () as Gtk.Window);
        dia.recur_mode = task.recur_mode;
        dia.rec_obj = task.recur;

        dia.threshold_date = task.threshold_date;
        dia.due_date = task.due_date;
        dia.show_all ();

        dia.save_clicked.connect (on_schedule_dialog_save_clicked);
    }

    private void on_delete_button_clicked () {
        deletion_requested ();
    }

    private void on_entry_changed () {
        string_changed = true;
    }

    private bool on_entry_focus_out () {
        update_task_from_entry_string ();
        return false;
    }

    private void update_task_from_entry_string () {
        if (string_changed) {
            task.update_from_simple_txt (edit_entry.text.strip ());
            string_changed = false;
        }
    }

    private void on_schedule_dialog_save_clicked (SimpleRecurrenceDialog dia) {
        task.recur_mode = dia.recur_mode;
        task.due_date = dia.due_date;
        task.threshold_date= dia.threshold_date;
        task.recur = dia.rec_obj;
        dia.destroy ();
    }

    private bool on_row_key_release (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.Delete:
                if (!editing || !edit_entry.has_focus) {
                    deletion_requested ();
                    return true;
                }
                break;
            default:
                return false;
        }
        return false;
    }

    private bool on_entry_key_release (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.Escape:
                if (editing) {
                    stop_editing ();
                    return true;
                }
                break;
            default:
                return false;
        }
        return false;
    }

    public override void realize () {
        Gtk.Allocation allocation;
        Gdk.WindowAttr attributes = Gdk.WindowAttr ();
        Gdk.WindowAttributesType attributes_mask;
        Gdk.Window window;

        this.get_allocation (out allocation);
        this.set_realized (true);

        attributes.x = allocation.x;
        attributes.y = allocation.y;
        attributes.width = allocation.width;
        attributes.height = allocation.height;
        attributes.window_type = Gdk.WindowType.CHILD;

        attributes.event_mask = (Gdk.EventMask.ENTER_NOTIFY_MASK |
                                 Gdk.EventMask.LEAVE_NOTIFY_MASK |
                                 Gdk.EventMask.POINTER_MOTION_MASK |
                                 Gdk.EventMask.EXPOSURE_MASK |
                                 Gdk.EventMask.BUTTON_PRESS_MASK |
                                 Gdk.EventMask.BUTTON_RELEASE_MASK
                                 //Gdk.EventMask.KEY_PRESS_MASK |
                                 //Gdk.EventMask.KEY_RELEASE_MASK
                                 );
        attributes.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;

        attributes_mask = Gdk.WindowAttributesType.X |
                          Gdk.WindowAttributesType.Y;

        window = new Gdk.Window (
            this.get_parent_window (), attributes, attributes_mask
        );
        window.set_user_data (this);
        this.set_window (window);
    }

    public override void add (Gtk.Widget widget) {
        warning ("add called on TaskRowLayout!");
    }

    private void _set_child_parent (Gtk.Widget? widget) {
        if (widget == null) {
            return;
        }
        widget.set_parent (this);
        widget.set_child_visible (true);
    }

    public override void remove (Gtk.Widget widget) {
        warning ("remove called on TaskRowLayout!");
    }

    public override void forall_internal (bool include_internals, Gtk.Callback callback) {
        if (include_internals) {
            callback (title_stack);
            callback (misc_stack);
            callback (check_button);
        }
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        int child_min_width, child_nat_width, check_min_width, check_nat_width;

        check_button.get_preferred_width (out check_min_width, out check_nat_width);
        title_stack.get_preferred_width (out child_min_width, out child_nat_width);

        minimum_width = check_min_width + child_min_width + column_spacing;
        natural_width = check_nat_width + child_nat_width + column_spacing;

        misc_stack.get_preferred_width (out child_min_width, out child_nat_width);

        minimum_width = int.max (check_min_width + child_min_width + column_spacing, minimum_width);
        natural_width = int.max (check_nat_width + child_nat_width + column_spacing, natural_width);
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        int minimum_width;
        get_preferred_width (out minimum_width, null);
        get_preferred_height_for_width (minimum_width, out minimum_height, out natural_height);
    }

    private void get_top_row_dimensions (Gtk.Allocation allocation, out int height, out Gtk.Allocation check_allocation, out Gtk.Allocation title_allocation) {
        int title_min_width, title_nat_width, check_min_width, check_nat_width, misc_min_width, misc_nat_width;
        check_allocation = {};
        title_allocation = {};

        check_button.get_preferred_width (out check_min_width, out check_nat_width);
        title_stack.get_preferred_width (out title_min_width, out title_nat_width);
        misc_stack.get_preferred_width (out misc_min_width, out misc_nat_width);

        int check_width = allocation.width - int.max (title_nat_width, misc_nat_width) - column_spacing;
        check_allocation.x = allocation.x;
        if (check_width >= check_nat_width) {
            check_allocation.width = check_nat_width;
        } else if (check_width >= check_min_width) {
            check_allocation.width = check_width;
        } else {
            check_allocation.width = check_min_width;
        }

        title_allocation.x = allocation.x + check_allocation.width + column_spacing;
        title_allocation.width = allocation.width - check_allocation.width - column_spacing;

        int title_min_height, title_nat_height;
        title_stack.get_preferred_height_for_width (int.MAX/2, out title_min_height, out title_nat_height);
        title_stack.get_preferred_height_for_width (title_allocation.width, out title_allocation.height, out title_nat_height);
        check_button.get_preferred_height_for_width (check_allocation.width, out check_allocation.height, out title_nat_height);

        int title_min_center = title_min_height/2;
        int check_center = check_allocation.height/2;

        int centerline = int.max (check_center, title_min_center);
        check_allocation.y = centerline - check_center;
        title_allocation.y = centerline - title_min_center;

        height = int.max (
            check_allocation.y + check_allocation.height,
            title_allocation.y + title_allocation.height
        );

        check_allocation.y += allocation.y;
        title_allocation.y += allocation.y;
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        int top_row_height;
        Gtk.Allocation check_allocation, title_allocation;
        get_top_row_dimensions (allocation, out top_row_height, out check_allocation, out title_allocation);

        check_button.size_allocate (check_allocation);
        title_stack.size_allocate (title_allocation);
        misc_stack.size_allocate (Gtk.Allocation () {
            x = title_allocation.x,
            y = allocation.y + top_row_height,
            width = title_allocation.width,
            height = allocation.height - top_row_height
        });

        base.size_allocate (allocation);
    }

    public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
        Gtk.Allocation allocation = {};
        Gtk.Allocation check_allocation, title_allocation;
        int top_row_height;
        int misc_min_height, misc_nat_height;

        allocation.width = width;

        get_top_row_dimensions (allocation, out top_row_height, out check_allocation, out title_allocation);

        misc_stack.get_preferred_height_for_width (title_allocation.width, out misc_min_height, out misc_nat_height);
        minimum_height = misc_min_height + top_row_height;
        natural_height = misc_nat_height + top_row_height;
    }
}

class GOFI.TXT.TaskRow: DragListRow {

    private TaskRowLayout layout;

    public bool is_editing {
        get {
            return layout.is_editing;
        }
    }

    public bool is_active {
        set {
            layout.is_active = value;
        }
    }

    public TxtTask task {
        get {
            return layout.task;
        }
    }

    public signal void task_selected ();
    public signal void timer_started (bool start);
    public signal void link_clicked (string uri);
    public signal void deletion_requested ();

    public TaskRow (TxtTask task) {
        layout = new TaskRowLayout (task);
        layout.task_selected.connect (() => task_selected ());
        layout.timer_started.connect ((start) => timer_started (start));
        layout.link_clicked.connect ((uri) => link_clicked (uri));
        layout.deletion_requested.connect (() => deletion_requested ());

        this.add (layout);
    }

    public void edit (bool bla) {
        layout.edit (bla);
    }

    public void stop_editing () {
        layout.stop_editing ();
    }
}

class GOFI.TXT.TaskTimerValuePopover : Gtk.Popover {
    private Gtk.Grid popover_layout;

    private Gtk.SpinButton timer_h_spin;
    private Gtk.SpinButton timer_m_spin;
    private Gtk.SpinButton timer_s_spin;

    private Gtk.SpinButton duration_h_spin;
    private Gtk.SpinButton duration_m_spin;
    private Gtk.SpinButton duration_s_spin;

    private TodoTask task;
    private bool updating;

    public TaskTimerValuePopover (Gtk.Widget? relative_to, TodoTask task) {
        Object (relative_to: relative_to);

        this.task = task;
        updating = false;

        popover_layout = new Gtk.Grid ();
        popover_layout.column_spacing = 6;
        popover_layout.margin = 6;

        timer_h_spin = new Gtk.SpinButton.with_range (0, 4800, 1);
        timer_m_spin = new Gtk.SpinButton.with_range (0, 59, 1);
        timer_s_spin = new Gtk.SpinButton.with_range (0, 59, 1);

        timer_h_spin.orientation = Gtk.Orientation.VERTICAL;
        timer_m_spin.orientation = Gtk.Orientation.VERTICAL;
        timer_s_spin.orientation = Gtk.Orientation.VERTICAL;

        duration_h_spin = new Gtk.SpinButton.with_range (0, 4800, 1);
        duration_m_spin = new Gtk.SpinButton.with_range (0, 59, 1);
        duration_s_spin = new Gtk.SpinButton.with_range (0, 59, 1);

        duration_h_spin.orientation = Gtk.Orientation.VERTICAL;
        duration_m_spin.orientation = Gtk.Orientation.VERTICAL;
        duration_s_spin.orientation = Gtk.Orientation.VERTICAL;

        set_spin_values ();

        const int timer_spin_row = 1;
        const int duration_spin_row = 3;

        popover_layout.attach (new Granite.HeaderLabel ("Timer:"), 0, timer_spin_row - 1, 5, 1);
        popover_layout.attach (timer_h_spin, 0, timer_spin_row);
        popover_layout.attach (new Gtk.Label (":"), 1, timer_spin_row);
        popover_layout.attach (timer_m_spin, 2, timer_spin_row);
        popover_layout.attach (new Gtk.Label (":"), 3, timer_spin_row);
        popover_layout.attach (timer_s_spin, 4, timer_spin_row);

        popover_layout.attach (new Granite.HeaderLabel ("Duration:"), 0, duration_spin_row - 1, 5, 1);
        popover_layout.attach (duration_h_spin, 0, duration_spin_row);
        popover_layout.attach (new Gtk.Label (":"), 1, duration_spin_row);
        popover_layout.attach (duration_m_spin, 2, duration_spin_row);
        popover_layout.attach (new Gtk.Label (":"), 3, duration_spin_row);
        popover_layout.attach (duration_s_spin, 4, duration_spin_row);

        popover_layout.show_all ();

        this.add (popover_layout);
    }

    private void set_spin_values () {
        update_timer_spin_values ();
        update_duration_spin_values ();
        connect_timer_spin_signals ();
        connect_duration_spin_signals ();
    }

    private void update_timer_spin_values () {
        uint hours, minutes, seconds;

        Utils.uint_to_time (task.timer_value, out hours, out minutes, out seconds);
        timer_h_spin.value = (double) hours;
        timer_m_spin.value = (double) minutes;
        timer_s_spin.value = (double) seconds;
    }

    private void update_duration_spin_values () {
        uint hours, minutes, seconds;

        Utils.uint_to_time (task.duration, out hours, out minutes, out seconds);
        duration_h_spin.value = (double) hours;
        duration_m_spin.value = (double) minutes;
        duration_s_spin.value = (double) seconds;
    }

    private void connect_timer_spin_signals () {
        timer_h_spin.value_changed.connect (on_timer_spin_changed);
        timer_m_spin.value_changed.connect (on_timer_spin_changed);
        timer_s_spin.value_changed.connect (on_timer_spin_changed);
        task.notify["timer-value"].connect (on_task_timer_value_changed);
    }

    private void connect_duration_spin_signals () {
        duration_h_spin.value_changed.connect (on_duration_spin_changed);
        duration_m_spin.value_changed.connect (on_duration_spin_changed);
        duration_s_spin.value_changed.connect (on_duration_spin_changed);
        task.notify["duration"].connect (on_task_duration_changed);
    }

    private void on_duration_spin_changed () {
        if (updating) {
            return;
        }
        updating = true;
        task.duration = Utils.time_to_uint (
            (uint) duration_h_spin.get_value_as_int (),
            (uint) duration_m_spin.get_value_as_int (),
            (uint) duration_s_spin.get_value_as_int ()
        );
        updating = false;
    }

    private void on_timer_spin_changed () {
        if (updating) {
            return;
        }
        updating = true;
        task.timer_value = Utils.time_to_uint (
            (uint) timer_h_spin.get_value_as_int (),
            (uint) timer_m_spin.get_value_as_int (),
            (uint) timer_s_spin.get_value_as_int ()
        );
        updating = false;
    }

    private void on_task_duration_changed () {
        if (updating) {
            return;
        }
        updating = true;
        update_duration_spin_values ();
        updating = false;
    }

    private void on_task_timer_value_changed () {
        if (updating) {
            return;
        }
        updating = true;
        update_timer_spin_values ();
        updating = false;
    }
}
