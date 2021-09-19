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

class GOFI.TXT.TaskRow: DragListRow {
    private Gtk.CheckButton check_button;
    private Gtk.Button delete_button;
    private DynOrientationBox label_box;
    private TaskMarkupLabel markup_label;
    private Gtk.Label status_label;
    private TaskEditEntry edit_entry;

    private Gtk.Revealer bottom_bar_revealer;
    private Gtk.Stack title_stack;

    private Gtk.Button sched_button;
    private Gtk.Label due_label;

    private Gtk.Label threshold_label;

    private Gtk.Image recur_indicator;

    private Gtk.ToggleButton timer_button;
    private Gtk.Image timer_image;

    private Gtk.Revealer due_revealer;
    private Gtk.Revealer threshold_revealer;
    private Gtk.Revealer recur_revealer;

    private BaselineCenterBin check_bin;

    private Gtk.ToggleButton timer_value_button;
    private TaskTimerValuePopover? timer_popover;

    private bool editing;
    private bool focus_cooldown_active;
    private const string FILTER_PREFIX = "gofi:";

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

    public TaskRow (TxtTask task) {
        this.task = task;
        check_bin = new BaselineCenterBin ();
        TextMeasurementWidget.add_listener (check_bin);
        check_bin.set_offset_func (TXT.TextMeasurementWidget.get_label_baseline_offset);

        title_stack = new BaselineStack ();

        edit_entry = null;
        editing = false;
        focus_cooldown_active = false;
        markup_label = new TaskMarkupLabel (task);
        markup_label.halign = Gtk.Align.START;
        markup_label.valign = Gtk.Align.BASELINE;
        status_label = new Gtk.Label (null);
        status_label.halign = Gtk.Align.END;
        status_label.valign = Gtk.Align.BASELINE;
        status_label.use_markup = true;
        status_label.no_show_all = true;
        update_status_label ();

        label_box = new DynOrientationBox (2, 0);
        label_box.set_primary_widget (markup_label);
        label_box.set_secondary_widget (status_label);
        label_box.valign = Gtk.Align.BASELINE;

        check_button = new Gtk.CheckButton ();
        check_button.active = task.done;
        var sc = kbsettings.get_shortcut (KeyBindingSettings.SCK_MARK_TASK_DONE);
        check_button.tooltip_markup = sc.get_accel_markup (_("Mark the task as complete"));

        title_stack.add_named (label_box, "label");

        check_bin.add (check_button);

        check_button.valign = Gtk.Align.START;
        title_stack.valign = Gtk.Align.BASELINE;
        check_bin.valign = Gtk.Align.BASELINE;

        var layout_grid = new Gtk.Grid ();
        layout_grid.orientation = Gtk.Orientation.VERTICAL;
        layout_grid.attach (check_bin, 0, 0);
        layout_grid.attach (title_stack, 1, 0);
        layout_grid.column_spacing = 4;

        due_label = new Gtk.Label (null);
        threshold_label = new Gtk.Label (null);
        recur_indicator = new Gtk.Image.from_icon_name (
            "media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON
        );

        timer_button = new Gtk.ToggleButton ();
        timer_image = new Gtk.Image.from_icon_name (
            "media-playback-start-symbolic", Gtk.IconSize.BUTTON
        );
        timer_button.add (timer_image);
        timer_button.clicked.connect (() => task_selected ());

        delete_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);
        // delete_button.relief = Gtk.ReliefStyle.NONE;
        delete_button.show_all ();
        delete_button.clicked.connect (on_delete_button_clicked);

        var creation_info_widget = get_creation_time_widget ();

        edit_entry = new TaskEditEntry ("");
        edit_entry.valign = Gtk.Align.BASELINE;
        title_stack.add_named (edit_entry, "edit_entry");
        title_stack.homogeneous = false;

        var bottom_bar = new Gtk.Grid ();
        bottom_bar.margin_top = 6;
        bottom_bar.row_spacing = 6;

        bottom_bar_revealer = new Gtk.Revealer ();
        bottom_bar_revealer.add (bottom_bar);
        bottom_bar_revealer.reveal_child = false;

        layout_grid.attach (bottom_bar_revealer, 1,1, 1, 1);

        timer_value_button = new Gtk.ToggleButton.with_label ("-");
        update_timer_value_label ();
        timer_value_button.clicked.connect (on_timer_value_button_clicked);

        var sched_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        sched_button = new Gtk.Button ();
        sched_button.hexpand = true;
        sched_button.halign = Gtk.Align.START;

        sched_button.add (sched_box);

        sched_button.clicked.connect (on_sched_button_clicked);


        if (!task.done) {
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
        if (creation_info_widget != null) {
            bottom_bar.attach (creation_info_widget, 1, 1);
        }
        bottom_bar.attach (delete_button, 2, 1);


        due_revealer = new Gtk.Revealer ();
        threshold_revealer = new Gtk.Revealer ();
        recur_revealer = new Gtk.Revealer ();

        due_revealer.add (due_label);
        threshold_revealer.add (threshold_label);
        recur_revealer.add (recur_indicator);

        sched_box.add (threshold_revealer);
        sched_box.add (due_revealer);
        sched_box.add (recur_revealer);

        update_schedule_labels (new DateTime.now_local ());

        this.add (layout_grid);
        layout_grid.margin = 5;
        layout_grid.margin_bottom = 3;
        layout_grid.margin_top = 3;

        connect_signals ();
        show_all ();
    }

    ~TaskRow () {
        TextMeasurementWidget.remove_listener (check_bin);
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

    private void on_global_baseline_offsets_changed () {
        check_bin.queue_resize ();
    }

    private void on_sched_button_clicked () {
        var dia = new SimpleRecurrenceDialog ();
        dia.recur_mode = task.recur_mode;
        dia.rec_obj = task.recur;

        dia.threshold_date = task.threshold_date;
        dia.due_date = task.due_date;
        dia.show_all ();

        dia.save_clicked.connect (on_schedule_dialog_save_clicked);
    }

    private void on_schedule_dialog_save_clicked (SimpleRecurrenceDialog dia) {
        task.recur_mode = dia.recur_mode;
        task.due_date = dia.due_date;
        task.threshold_date= dia.threshold_date;
        task.recur = dia.rec_obj;
        dia.destroy ();
    }

    public void edit (bool wrestle_focus=false) {
        if (editing) {
            return;
        }
        bottom_bar_revealer.reveal_child = true;
        edit_entry.text = task.to_simple_txt ();
        edit_entry.edit ();

        title_stack.visible_child_name = "edit_entry";

        editing = true;
        check_bin.set_offset_func (TXT.TextMeasurementWidget.get_entry_baseline_offset);
        warning ("stub");
        return;
    }

    public void update_schedule_labels (DateTime now) {
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

    private void on_delete_button_clicked () {
        deletion_requested ();
    }

    private void on_edit_entry_string_changed () {
        task.update_from_simple_txt (edit_entry.text.strip ());
    }

    private void on_edit_entry_finished () {
        stop_editing ();
    }

    /**
     * Using a cooldown to work around a Gtk issue:
     * The ListBoxRow will steal focus again after activating and in addition
     * to that for a moment neither the row nor the entry may have focus.
     * We give everything a moment to settle and stop editing as soon as neither
     * this row or the entry has focus.
     */
    private bool on_focus_out () {
        if (focus_cooldown_active || !editing || timer_popover != null) {
            return false;
        }
        focus_cooldown_active = true;
        GLib.Timeout.add (
            50, focus_cooldown_end, GLib.Priority.DEFAULT_IDLE
        );
        return false;
    }

    private bool focus_cooldown_end () {
        focus_cooldown_active = false;
        if (!editing) {
            return false;
        }
        if (!has_focus && get_focus_child () == null && timer_popover == null) {
            stop_editing ();
            return false;
        }
        return GLib.Source.REMOVE;
    }

    private bool release_focus_claim () {
        edit_entry.hold_focus = false;
        return false;
    }

    public void stop_editing () {
        if (!editing) {
            return;
        }
        var had_focus = edit_entry.has_focus;
        title_stack.visible_child_name = "label";
        bottom_bar_revealer.reveal_child = false;
        editing = false;
        if (had_focus) {
            grab_focus ();
        }
        check_bin.set_offset_func (TXT.TextMeasurementWidget.get_label_baseline_offset);
    }

    private bool on_row_key_release (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.Delete:
                if (!editing || !edit_entry.has_focus) {
                    deletion_requested ();
                    return true;
                }
                break;
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

    private void connect_signals () {
        check_button.toggled.connect (on_check_toggled);
        markup_label.activate_link.connect (on_activate_link);

        set_focus_child.connect (on_set_focus_child);
        focus_out_event.connect (on_focus_out);
        key_release_event.connect (on_row_key_release);

        task.done_changed.connect (on_task_done_changed);
        task.notify["status"].connect (on_task_status_changed);
        task.notify["timer-value"].connect (on_task_duration_changed);
        task.notify["duration"].connect (on_task_duration_changed);

        edit_entry.string_changed.connect (on_edit_entry_string_changed);
        edit_entry.editing_finished.connect (on_edit_entry_finished);
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

    private void on_set_focus_child (Gtk.Widget? widget) {
        if (widget == null && !has_focus) {
            on_focus_out ();
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

    public Gtk.Widget? get_creation_time_widget () {
        GOFI.Date? completion_date = task.completion_date;
        GOFI.Date? creation_date = task.creation_date;
        if (creation_date == null) {
            return null;
        }
        return new ExplanationWidget (
            get_creation_time_info_str (creation_date, completion_date)
        );
    }

    public string get_creation_time_info_str (GOFI.Date creation_date, GOFI.Date? completion_date) {
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

    class TaskEditEntry : Gtk.Entry {
        public signal void editing_finished ();
        public signal void string_changed ();
        private uint8 focus_wrestle_counter;

        public bool hold_focus {
            get {
                return focus_wrestle_counter != 0;
            }
            set {
                if (value) {
                    // 1 seems to be sufficient right now
                    focus_wrestle_counter = 1;
                } else {
                    focus_wrestle_counter = 0;
                }
            }
        }

        public TaskEditEntry (string description) {
            can_focus = true;
            text = description;
            focus_wrestle_counter = 0;
            focus_out_event.connect (() => {
                if (focus_wrestle_counter == 0) {
                    return false;
                }
                focus_wrestle_counter--;
                grab_focus ();
                return false;
            });
        }

        private void abort_editing () {
            editing_finished ();
        }

        private void stop_editing () {
            string_changed ();
            abort_editing ();
        }

        public void edit () {
            show ();
            grab_focus ();
            activate.connect (stop_editing);
        }
    }

    class TaskMarkupLabel : Gtk.Label {
        private TxtTask task;

        private string markup_string;

        public TaskMarkupLabel (TxtTask task) {
            this.task = task;

            update ();

            hexpand = true;
            wrap = true;
            wrap_mode = Pango.WrapMode.WORD_CHAR;
            this.xalign = 0f;

            connect_signals ();
            show_all ();
        }

        private void gen_markup () {
            markup_string = make_links (task.get_descr_parts ());

            var done = task.done;
            var duration = task.duration;

            if (task.priority != TxtTask.NO_PRIO) {
                var prefix = _("priority");
                var priority = task.priority;
                char prio_char = priority + 65;
                markup_string = @"<b><a href=\"$prefix:$prio_char\">($prio_char)</a></b> $markup_string";
            }
            if (duration > 0) {
                var timer_value = task.timer_value;
                string timer_str = _("%1$s / %2$s").printf (
                    Utils.seconds_to_separated_timer_string (timer_value),
                    Utils.seconds_to_separated_timer_string (duration)
                );
                markup_string = "%s <i>(%s)</i>".printf (
                    markup_string, timer_str
                );
            }
            if (done) {
                markup_string = "<s>" + markup_string + "</s>";
            }
        }

        /**
         * Used to find projects and contexts and replace those parts with a
         * link.
         * @param description the string to took for contexts or projects
         */
        private string make_links (TxtPart[] description) {
            var length = description.length;
            var markup_parts = new string[length];
            string? delimiter = null, prefix = null, val = null;

            for (uint i = 0; i < length; i++) {
                unowned TxtPart part = description[i];
                val = GLib.Markup.escape_text (part.content);

                switch (part.part_type) {
                    case TxtPartType.CONTEXT:
                        prefix = _("context");
                        delimiter = "@";
                        break;
                    case TxtPartType.PROJECT:
                        prefix = _("project");
                        delimiter = "+";
                        break;
                    case TxtPartType.URI:
                        string uri, display_uri;
                        if (part.tag_name == null || part.tag_name == "") {
                            uri = part.content;
                            display_uri = val;
                        } else {
                            uri = part.tag_name + ":" + part.content;
                            display_uri = part.tag_name + ":" + val;
                        }
                        markup_parts[i] =
                            @"<a href=\"$uri\" title=\"$display_uri\">$display_uri</a>";
                        continue;
                    case TxtPartType.TAG:
                        markup_parts[i] = part.tag_name + ":" + val;
                        continue;
                    default:
                        markup_parts[i] = val;
                        continue;
                }
                markup_parts[i] = @" <a href=\"$FILTER_PREFIX$prefix:$val\" title=\"$val\">" +
                                  @"$delimiter$val</a>";
            }

            return string.joinv (" ", markup_parts);
        }

        private void update () {
            gen_markup ();
            set_markup (markup_string);
        }

        private void connect_signals () {
            task.notify.connect (on_task_notify);
        }

        private void on_task_notify (ParamSpec pspec) {
            switch (pspec.get_name ()) {
                case "description":
                case "priority":
                case "timer-value":
                case "duration":
                    update ();
                    break;
                default:
                    break;
            }
        }
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
