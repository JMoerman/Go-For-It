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

class GOFI.SimpleRecurrenceDialog : Gtk.Dialog {
    Gtk.Grid layout_grid;

    Gtk.Label due_label;
    Gtk.Switch due_switch;
    Granite.Widgets.DatePicker due_picker;

    Gtk.Label threshold_label;
    Gtk.Switch threshold_switch;
    Granite.Widgets.DatePicker threshold_picker;

    Gtk.Label repeat_label;
    Gtk.Switch repeat_switch;
    Gtk.ComboBoxText repetition_kind_cbox;

    Gtk.Label frequency_label;
    Gtk.ComboBoxText frequency_cbox;

    Gtk.Label interval_label;
    Gtk.SpinButton interval_spin;
    Gtk.Label freq_unit_label;

    Gtk.Label past_due_label;
    Gtk.ComboBoxText past_due_cbox;
    Gtk.Revealer past_due_revealer;

    const int H_SPACING = 6;
    // const int V_SPACING = 0;

    public GOFI.Date? due_date {
        owned get {
            if (due_switch.active) {
                return new GOFI.Date (due_picker.date);
            }
            return null;
        }
        set {
            if (value != null) {
                due_picker.date = value.dt;
                due_switch.active = true;
            } else {
                due_switch.active = false;
            }
        }
    }

    public GOFI.Date? threshold_date {
        owned get {
            if (threshold_switch.active) {
                return new GOFI.Date (threshold_picker.date);
            }
            return null;
        }
        set {
            if (value != null) {
                threshold_picker.date = value.dt;
                threshold_switch.active = true;
            } else {
                threshold_switch.active = false;
            }
        }
    }

    public SimpleRecurrence? rec_obj {
        owned get {
            if (!repeat_switch.active) {
                return null;
            }

            ICal.RecurrenceFrequency freq;
            int interval;

            switch (frequency_cbox.active_id) {
                case "daily":
                    freq = ICal.RecurrenceFrequency.DAILY_RECURRENCE;
                    break;
                case "weekly":
                    freq = ICal.RecurrenceFrequency.WEEKLY_RECURRENCE;
                    break;
                case "monthly":
                    freq = ICal.RecurrenceFrequency.MONTHLY_RECURRENCE;
                    break;
                default:
                    freq = ICal.RecurrenceFrequency.YEARLY_RECURRENCE;
                    break;
            }

            interval = interval_spin.get_value_as_int ();

            return new SimpleRecurrence (freq, (short) interval);
        }
        set {
            if (value == null) {
                return;
            }

            var rec = value;
            interval_spin.value = (double) rec.interval;
            switch (rec.freq) {
                case ICal.RecurrenceFrequency.DAILY_RECURRENCE:
                    frequency_cbox.active_id = "daily";
                    break;
                case ICal.RecurrenceFrequency.WEEKLY_RECURRENCE:
                    frequency_cbox.active_id = "weekly";
                    break;
                case ICal.RecurrenceFrequency.MONTHLY_RECURRENCE:
                    frequency_cbox.active_id = "monthly";
                    break;
                default:
                    frequency_cbox.active_id = "yearly";
                    break;
            }
        }
    }

    public RecurrenceMode recur_mode {
        get {
            if (!repeat_switch.active) {
                return RecurrenceMode.NO_RECURRENCE;
            }
            if (repetition_kind_cbox.active_id == "by_completion") {
                return RecurrenceMode.ON_COMPLETION;
            }
            switch (repetition_kind_cbox.active_id) {
                case "skip":
                    return RecurrenceMode.PERIODICALLY_SKIP_OLD;
                case "auto_reschedule":
                    return RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE;
                default:
                    return RecurrenceMode.PERIODICALLY;
            }
        }
        set {
            switch (value) {
                case RecurrenceMode.PERIODICALLY:
                    repeat_switch.active = true;
                    repetition_kind_cbox.active_id = "by_due";
                    past_due_cbox.active_id = "default";
                    break;
                case RecurrenceMode.PERIODICALLY_SKIP_OLD:
                    repeat_switch.active = true;
                    repetition_kind_cbox.active_id = "by_due";
                    past_due_cbox.active_id = "skip";
                    break;
                case RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE:
                    repeat_switch.active = true;
                    repetition_kind_cbox.active_id = "by_due";
                    past_due_cbox.active_id = "auto_reschedule";
                    break;
                case RecurrenceMode.ON_COMPLETION:
                    repeat_switch.active = true;
                    repetition_kind_cbox.active_id = "by_completion";
                    break;
                default:
                    repeat_switch.active = false;
                    break;
            }
        }
    }

    public signal void save_clicked ();

    public SimpleRecurrenceDialog (Gtk.Window? parent_window = null) {
        this.set_modal (true);
        this.set_transient_for (parent_window);

        init_widgets ();
        place_widgets ();

        update_rec_sensitive (false);
        threshold_picker.sensitive = false;
        due_picker.sensitive = false;

        this.title = _("Dates for task");
        this.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        this.add_button (_("Save"), Gtk.ResponseType.OK);

        /* Action Handling */
        this.response.connect ((s, response) => {
            switch (response) {
                case Gtk.ResponseType.CANCEL:
                    this.destroy ();
                    break;
                case Gtk.ResponseType.OK:
                    save_clicked ();
                    break;
            }
        });
    }

    private void init_widgets () {
        due_label = DialogUtils.create_header_label (_("Due:"));
        due_switch = new Gtk.Switch ();
        due_picker = new Granite.Widgets.DatePicker ();

        threshold_label = DialogUtils.create_header_label (_("Show after:"));
        threshold_switch = new Gtk.Switch ();
        threshold_picker = new Granite.Widgets.DatePicker ();

        repeat_label = DialogUtils.create_header_label (_("Repeat:"));
        repeat_switch = new Gtk.Switch ();
        repetition_kind_cbox = new Gtk.ComboBoxText ();

        repetition_kind_cbox.prepend ("by_completion", _("Repeat after completion"));
        repetition_kind_cbox.prepend ("by_due", _("Repeat periodically"));

        frequency_label = DialogUtils.create_header_label (_("Frequency:"));
        frequency_cbox = new Gtk.ComboBoxText ();

        frequency_cbox.prepend ("yearly", _("Yearly"));
        frequency_cbox.prepend ("monthly", _("Monthly"));
        frequency_cbox.prepend ("weekly", _("Weekly"));
        frequency_cbox.prepend ("daily", _("Daily"));

        interval_label = DialogUtils.create_header_label (_("Every:"));

        interval_spin = new Gtk.SpinButton.with_range (1, 999, 1);

        freq_unit_label = new Gtk.Label (null);

        past_due_label = DialogUtils.create_header_label (_("When the due date has passed:"));
        past_due_cbox = new Gtk.ComboBoxText ();
        past_due_cbox.prepend ("auto_reschedule", _("Reschedule task after due date has passed"));
        past_due_cbox.prepend ("skip", _("After completion, schedule new task at the next future date"));
        past_due_cbox.prepend ("default", _("After completion, schedule new task at the next date"));

        frequency_cbox.active_id = "daily";
        repetition_kind_cbox.active_id = "by_due";
        past_due_cbox.active_id = "default";
        interval_spin.value = 1.0;

        update_freq_unit_label ();

        connect_signals ();
    }

    private void place_widgets () {
        layout_grid = new Gtk.Grid ();
        layout_grid.orientation = Gtk.Orientation.VERTICAL;

        var due_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, H_SPACING);
        due_box.add (due_switch);
        due_box.add (due_picker);
        due_switch.valign = Gtk.Align.CENTER;

        var threshold_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, H_SPACING);
        threshold_box.add (threshold_switch);
        threshold_box.add (threshold_picker);
        threshold_switch.valign = Gtk.Align.CENTER;

        var repeat_kind_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, H_SPACING);
        repeat_kind_box.add (repeat_switch);
        repeat_kind_box.add (frequency_cbox);
        repeat_switch.valign = Gtk.Align.CENTER;
        frequency_cbox.hexpand = true;

        interval_spin.valign = Gtk.Align.CENTER;
        interval_spin.hexpand = true;
        freq_unit_label.halign = Gtk.Align.START;

#if USE_GRANITE
        var past_due_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
#else
        var past_due_box = new Gtk.Box (Gtk.Orientation.VERTICAL, DialogUtils.SPACING_SETTINGS_ROW);
#endif
        past_due_box.add (past_due_label);
        past_due_box.add (past_due_cbox);

        past_due_revealer = new Gtk.Revealer ();
        past_due_revealer.add (past_due_box);

        layout_grid.column_spacing = 6;
        layout_grid.attach (due_label, 0, 0);
        layout_grid.attach (due_box, 0, 1);

        layout_grid.attach (threshold_label, 1, 0);
        layout_grid.attach (threshold_box, 1, 1);

        layout_grid.attach (repeat_label, 0, 2, 2);
        layout_grid.attach (repeat_kind_box, 0, 3);
        layout_grid.attach (repetition_kind_cbox, 1, 3);

        layout_grid.attach (interval_label, 0, 4, 2);
        layout_grid.attach (interval_spin, 0, 5, 1);
        layout_grid.attach (freq_unit_label, 1, 5, 1);

        layout_grid.attach (past_due_revealer, 0, 6, 2);

#if !USE_GRANITE
        // We're using margins instead of setting the grid spacing to a non 0
        // value as otherwise space would still be reserved around
        // past_due_revealer, even if its contents would be hidden.
        due_label.margin_top = 0;
        due_box.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        threshold_label.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        threshold_box.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        repeat_label.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        repeat_kind_box.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        frequency_label.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        frequency_cbox.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        interval_label.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        interval_box.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
        past_due_box.margin_top = DialogUtils.SPACING_SETTINGS_ROW;
#endif

        var content_area = this.get_content_area ();
        content_area.margin = 10;
        content_area.add (layout_grid);
    }

    private void update_freq_unit_label () {
        switch (frequency_cbox.active_id) {
            case "daily":
                freq_unit_label.label = ngettext ("Day", "Days", (ulong)interval_spin.value);
                break;
            case "weekly":
                freq_unit_label.label = ngettext ("Week", "Weeks", (ulong)interval_spin.value);
                break;
            case "monthly":
                freq_unit_label.label = ngettext ("Month", "Months", (ulong)interval_spin.value);
                break;
            default:
                freq_unit_label.label = ngettext ("Year", "Years", (ulong)interval_spin.value);
                break;
        }
    }

    private void connect_signals () {
        repetition_kind_cbox.changed.connect (on_repition_kind_changed);
        frequency_cbox.changed.connect (update_freq_unit_label);
        interval_spin.value_changed.connect (update_freq_unit_label);

        repeat_switch.notify["active"].connect (on_repeat_switch_changed);
        due_switch.notify["active"].connect (on_due_switch_changed);
        threshold_switch.notify["active"].connect (on_threshold_switch_changed);
    }

    private void on_repition_kind_changed () {
        if (repetition_kind_cbox.active_id == "by_due") {
            update_freq_unit_label ();
            interval_label.label = _("Every:");
            past_due_revealer.reveal_child = true;
        } else {
            interval_label.label = _("Schedule next task after:");
            past_due_revealer.reveal_child = false;
        }
    }

    private void on_repeat_switch_changed () {
        update_rec_sensitive (repeat_switch.active);
    }

    private void on_due_switch_changed () {
        due_picker.sensitive = due_switch.active;
    }

    private void on_threshold_switch_changed () {
        threshold_picker.sensitive = threshold_switch.active;
    }

    private void update_rec_sensitive (bool sensitive) {
        repetition_kind_cbox.sensitive = sensitive;
        frequency_cbox.sensitive = sensitive;
        interval_spin.sensitive = sensitive;
        freq_unit_label.sensitive = sensitive;
        interval_label.sensitive = sensitive;
        past_due_revealer.reveal_child =
            sensitive && repetition_kind_cbox.active_id == "by_due";
    }
}
