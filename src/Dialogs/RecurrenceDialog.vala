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

class GOFI.RecurrenceDialog : Gtk.Dialog {
    Gtk.Grid layout_grid;
    Gtk.Grid native_recur_grid;
    Gtk.Grid rrule_grid;

    Gtk.Stack periodic_settings_stack;

    Gtk.Label due_label;
    Granite.Widgets.DatePicker date_picker;

    Gtk.ComboBoxText time_mode_selector;
    Gtk.Revealer time_picker_revealer;
    Granite.Widgets.TimePicker time_picker;

    Gtk.Label repeat_label;
    Gtk.Switch repeat_switch;
    Gtk.ComboBoxText repetition_kind_cbox;

    Gtk.Label frequency_label;
    Gtk.ComboBoxText frequency_cbox;

    Gtk.Label interval_label;

    Gtk.SpinButton interval_spin;
    Gtk.Label freq_unit_label;

    Gtk.Box week_box;
    Gtk.ToggleButton mon_button;
    Gtk.ToggleButton tue_button;
    Gtk.ToggleButton wed_button;
    Gtk.ToggleButton thu_button;
    Gtk.ToggleButton fri_button;
    Gtk.ToggleButton sat_button;
    Gtk.ToggleButton sun_button;
    Gtk.Revealer week_box_revealer;

    Gtk.RadioButton day_radio;
    Gtk.RadioButton week_day_radio;
    Gtk.RadioButton custom_day_radio;
    Gtk.Revealer radio_revealer;
    Gtk.Box radio_box;
    bool fifth_week_was_selected;

    Gtk.Label rrule_info_label;
    Gtk.Label rrule_info_label2;
    Gtk.Entry rrule_entry;

    Gtk.Label week_start_label;
    Gtk.ComboBoxText week_start_cbox;
    Gtk.Revealer week_start_revealer;

    GLib.DateTime due_date {
        get;
        set;
    }

    private const short ARRAY_MAX = ICal.RecurrenceArrayMaxValues.RECURRENCE_ARRAY_MAX;

    bool had_inconstent_due_date {
        get;
        private set;
    }

    // Offset from monday
    public int week_offset {
        get;
        set;
    }

    public ICal.RecurrenceWeekday default_week_start {
        get;
        set;
    }

    public RecurrenceDialog (
        ICal.RecurrenceWeekday default_week_start, ICal.Recurrence? rrule,
        GLib.DateTime? due_date
    ) {
        this.default_week_start = default_week_start;

        setup_widgets ();
        connect_signals ();
        if (rrule != null) {
            set_rrule (rrule);
        } else {
            frequency_cbox.active_id = "daily";
            interval_spin.value = 1.0;
            week_offset = ical_week_day_to_day_int (default_week_start) - 1;
        }
        if (due_date != null) {
            this.due_date = due_date;
        } else {

        }
    }

    private void get_month_day (out int month_day, out int day_of_week, out int day_position) {
        int year, month, day;
        due_date.get_ymd (out year, out month, out day);
        day_of_week = due_date.get_day_of_week ();
        uint8 days_in_month = GLib.Date.get_days_in_month (
            (DateMonth) month, (DateYear) year
        );
        day_position = day / 7 + 1;

        if (day + 7 > days_in_month) {
            day_position = -1;
        }

        if (day == days_in_month) {
            month_day = -1;
        } else {
            month_day = day;
        }
    }

    public ICal.Recurrence? get_rrule () {
        ICal.Recurrence rrule;

        if (!repeat_switch.active) {
            return null;
        }

        var frequency_id = frequency_cbox.active_id;
        if (frequency_id == "by_rrule") {
            return new ICal.Recurrence.from_string (rrule_entry.text);
        }

        rrule = new ICal.Recurrence ();
        short interval = (short) interval_spin.get_value_as_int ();
        if (interval != 1) {
            rrule.set_interval (interval);
        }

        if (frequency_id == "daily") {
            rrule.set_freq (ICal.RecurrenceFrequency.DAILY_RECURRENCE);
        } else if (frequency_id == "weekly") {
            rrule.set_freq (ICal.RecurrenceFrequency.WEEKLY_RECURRENCE);

            if (week_offset != 0) { // Default value for WKST is MO
                rrule.set_week_start (day_int_to_ical_week_day (week_offset + 1));
            }

            var array = new GLib.Array<short> (false, false, sizeof (short));

            if (mon_button.active) {
                short day = encode_day (ICal.RecurrenceWeekday.MONDAY_WEEKDAY, 0);
                array.append_val (day);
            }

            if (tue_button.active) {
                short day = encode_day (ICal.RecurrenceWeekday.TUESDAY_WEEKDAY, 0);
                array.append_val (day);
            }

            if (wed_button.active) {
                short day = encode_day (ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY, 0);
                array.append_val (day);
            }

            if (thu_button.active) {
                short day = encode_day (ICal.RecurrenceWeekday.THURSDAY_WEEKDAY, 0);
                array.append_val (day);
            }

            if (fri_button.active) {
                short day = encode_day (ICal.RecurrenceWeekday.FRIDAY_WEEKDAY, 0);
                array.append_val (day);
            }

            if (sat_button.active) {
                short day = encode_day (ICal.RecurrenceWeekday.SATURDAY_WEEKDAY, 0);
                array.append_val (day);
            }

            if (sun_button.active) {
                short day = encode_day (ICal.RecurrenceWeekday.SUNDAY_WEEKDAY, 0);
                array.append_val (day);
            }

            rrule.set_by_day_array (array);
        } else {
            bool monthly = frequency_id == "monthly";
            if (monthly) {
                rrule.set_freq (ICal.RecurrenceFrequency.MONTHLY_RECURRENCE);
            } else {
                rrule.set_freq (ICal.RecurrenceFrequency.YEARLY_RECURRENCE);
            }

            int month_day, day_of_week, day_position;
            get_month_day (out month_day, out day_of_week, out day_position);
            var month = (short) due_date.get_month ();
            if (day_radio.active) {
                if (had_inconstent_due_date || month_day < 0) {
                    if (!monthly) {
                        rrule.set_by_month (0, month);
                        rrule.set_by_month (1, ARRAY_MAX);
                    }
                    rrule.set_by_month_day (0, (short) month_day);
                    rrule.set_by_month_day (1, ARRAY_MAX);
                }
            } else if (week_day_radio.active) {
                if (!monthly) {
                    rrule.set_by_month (0, month);
                    rrule.set_by_month (1, ARRAY_MAX);
                }
                rrule.set_by_day (0, encode_day (day_int_to_ical_week_day (day_of_week), day_position));
                rrule.set_by_day (1, ARRAY_MAX);
            } else {
                if (!monthly) {
                    rrule.set_by_month (0, month);
                    rrule.set_by_month (1, ARRAY_MAX);
                }
                rrule.set_by_day (0, encode_day (day_int_to_ical_week_day (day_of_week), 5));
                rrule.set_by_day (1, ARRAY_MAX);
            }
        }

        return rrule;
    }

    public void set_rrule (ICal.Recurrence rrule) {
        bool custom_rrule = false;

        var rrule_comp = new ICal.Recurrence ();
        var rrule_freq = rrule.get_freq ();
        short interval = rrule.get_interval ();
        var week_start = rrule.get_week_start ();
        rrule_comp.set_freq (rrule_freq);
        rrule_comp.set_interval (interval);
        rrule_comp.set_week_start (week_start);

        mon_button.active = false;
        tue_button.active = false;
        wed_button.active = false;
        thu_button.active = false;
        fri_button.active = false;
        sat_button.active = false;
        sun_button.active = false;

        var array_max = ICal.RecurrenceArrayMaxValues.RECURRENCE_ARRAY_MAX;
        uint year, month, due_day;

        if (week_start == ICal.RecurrenceWeekday.NO_WEEKDAY) {
            week_offset = ical_week_day_to_day_int (default_week_start) - 1;
        } else {
            week_offset = ical_week_day_to_day_int (week_start) - 1;
        }
        switch (rrule_freq) {
            case ICal.RecurrenceFrequency.DAILY_RECURRENCE:
                frequency_cbox.active_id = "daily";
                break;
            case ICal.RecurrenceFrequency.WEEKLY_RECURRENCE:
                var by_day = rrule.get_by_day_array ();
                rrule_comp.set_by_day_array (by_day);
                for (uint i = 0; i < by_day.length; i++) {
                    switch (ICal.Recurrence.day_day_of_week (by_day.index (i))) {
                        case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                            mon_button.active = true;
                            break;
                        case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                            tue_button.active = true;
                            break;
                        case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                            wed_button.active = true;
                            break;
                        case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                            thu_button.active = true;
                            break;
                        case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                            fri_button.active = true;
                            break;
                        case ICal.RecurrenceWeekday.SATURDAY_WEEKDAY:
                            sat_button.active = true;
                            break;
                        case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                            sun_button.active = true;
                            break;
                        default:
                            i = by_day.length;
                            break;
                    }
                }
                frequency_cbox.active_id = "weekly";
                break;
            case ICal.RecurrenceFrequency.MONTHLY_RECURRENCE:
                var month_day = rrule.get_by_month_day (0);
                var month_week_day = rrule.get_by_day (0);

                bool is_by_month_day = month_day != array_max;

                if (is_by_month_day || month_week_day != array_max) {
                    if (is_by_month_day) {
                        if (rrule.get_by_month_day (1) != array_max) {
                            custom_rrule = true;
                            break;
                        }
                    } else {
                        if (rrule.get_by_day (1) != array_max) {
                            custom_rrule = true;
                            break;
                        }
                    }

                    // We use the due date to let the user pick on which day
                    // of the month, the task should recur.
                    // We need to make sure that the due date matches the
                    // current RRULE
                    due_date.get_ymd (out year, out month, out due_day);
                    var ical_date = new ICal.Time.null_date ();
                    int prev_month = ((int) month) - int.max (interval, 1);
                    var days_in_month = GLib.Date.get_days_in_month (
                        (DateMonth) prev_month, (DateYear) year
                    );
                    ical_date.set_date ((int) year, prev_month, days_in_month);
                    var rrule_iter = new ICal.RecurIterator (
                        rrule,
                        ical_date
                    );

                    ical_date = rrule_iter.next ();

                    int sched_y, sched_m, sched_d;
                    ical_date.get_date (out sched_y, out sched_m, out sched_d);

                    if (year != sched_y || month != sched_m || due_day != sched_d) {
                        fix_inconsistent_due_date (sched_y, sched_m, sched_d);
                        had_inconstent_due_date = true;
                    } else {
                        had_inconstent_due_date = false;
                    }

                    if (is_by_month_day) {
                        rrule_comp.set_by_month_day (0, month_day);
                        day_radio.active = true;
                        fifth_week_was_selected = false;
                    } else {
                        rrule_comp.set_by_day (0, month_week_day);
                        if (ICal.Recurrence.day_position (month_week_day) == 5) {
                            fifth_week_was_selected = true;
                            custom_day_radio.active = true;
                        } else {
                            fifth_week_was_selected = false;
                            week_day_radio.active = true;
                        }
                    }
                } else { // implicit by month day
                    day_radio.active = true;
                    fifth_week_was_selected = false;
                    break;
                }

                frequency_cbox.active_id = "monthly";

                break;
            case ICal.RecurrenceFrequency.YEARLY_RECURRENCE:
                var rrule_month = rrule.get_by_month (0);
                if (rrule_month != array_max) {
                    if (rrule.get_by_month (1) != array_max) {
                        custom_rrule = true;
                        break;
                    }
                    rrule_comp.set_by_month (0, rrule_month);
                    var month_day = rrule.get_by_month_day (0);
                    var month_week_day = rrule.get_by_day (0);

                    bool is_by_month_day = month_day != array_max;

                    if (is_by_month_day || month_week_day != array_max) {
                        if (is_by_month_day) {
                            if (rrule.get_by_month_day (1) != array_max) {
                                custom_rrule = true;
                                break;
                            }
                        } else {
                            if (rrule.get_by_day (1) != array_max) {
                                custom_rrule = true;
                                break;
                            }
                        }
                    }

                    due_date.get_ymd (out year, out month, out due_day);
                    var ical_date = new ICal.Time.null_date ();
                    int prev_year = ((int) year) - int.max (interval, 1);
                    ical_date.set_date (prev_year, 12, 31);
                    var rrule_iter = new ICal.RecurIterator (
                        rrule,
                        ical_date
                    );

                    ical_date = rrule_iter.next ();

                    int sched_y, sched_m, sched_d;
                    ical_date.get_date (out sched_y, out sched_m, out sched_d);

                    if (year != sched_y || month != sched_m || due_day != sched_d) {
                        fix_inconsistent_due_date (sched_y, sched_m, sched_d);
                        had_inconstent_due_date = true;
                    } else {
                        had_inconstent_due_date = false;
                    }

                    if (is_by_month_day) {
                        rrule_comp.set_by_month_day (0, month_day);
                        day_radio.active = true;
                    } else {
                        rrule_comp.set_by_day (0, month_week_day);
                        if (ICal.Recurrence.day_position (month_week_day) == 5) {
                            fifth_week_was_selected = true;
                            custom_day_radio.active = true;
                        } else {
                            fifth_week_was_selected = false;
                            week_day_radio.active = true;
                        }
                    }
                } else {
                    // implicit by month, by month day
                    day_radio.active = true;
                }
                frequency_cbox.active_id = "yearly";
                break;
            default:
                custom_rrule = true;
                break;
        }

        var rrule_str = rrule.to_string ();
        rrule_entry.text = rrule_str;

        if (!custom_rrule && rrule_str != rrule_comp.to_string ()) {
            custom_rrule = true;
        }

        if (custom_rrule) {
            frequency_cbox.active_id = "by_rrule";
        }
    }

    /*
     * From io.elementary.calendar (src/EventEdition/RepeatPanel.vala)
     * Replace it by ICal.Recurrence.encode_day once libical-glib 3.1 is available
     */
    private short encode_day (ICal.RecurrenceWeekday weekday, int position) {
        return (weekday + (8 * position.abs ())) * ((position < 0) ? -1 : 1);
    }

    private void fix_inconsistent_due_date (int year, int month, int day) {
        var hour = due_date.get_hour ();
        var minute = due_date.get_minute ();
        var seconds = due_date.get_seconds ();
        due_date = new GLib.DateTime.local (year, month, day, hour, minute, seconds);
    }

    private void setup_widgets () {
        layout_grid = new Gtk.Grid ();
        layout_grid.orientation = Gtk.Orientation.VERTICAL;

        rrule_grid = new Gtk.Grid ();
        rrule_grid.orientation = Gtk.Orientation.VERTICAL;

        native_recur_grid = new Gtk.Grid ();
        native_recur_grid.orientation = Gtk.Orientation.VERTICAL;

        due_label = new Gtk.Label (_("Due:"));
        date_picker = new Granite.Widgets.DatePicker ();

        time_mode_selector = new Gtk.ComboBoxText ();
        time_mode_selector.prepend ("end_of_day", _("End of the day"));
        time_mode_selector.prepend ("time", _("At"));
        time_picker = new Granite.Widgets.TimePicker ();
        time_picker_revealer = new Gtk.Revealer ();
        time_picker_revealer.add (time_picker);
        time_picker.margin_start = 6;

        var time_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        time_box.add (time_mode_selector);
        time_box.add (time_picker_revealer);

        repeat_label = new Gtk.Label (_("Repeat:"));
        repeat_switch = new Gtk.Switch ();
        repetition_kind_cbox = new Gtk.ComboBoxText ();

        repetition_kind_cbox.prepend ("by_completion", _("Repeat after completion"));
        repetition_kind_cbox.prepend ("by_due", _("Repeat periodically"));

        frequency_label = new Gtk.Label (_("Frequency:"));
        frequency_cbox = new Gtk.ComboBoxText ();

        frequency_cbox.prepend ("by_rrule", _("Custom"));
        frequency_cbox.prepend ("yearly", _("Yearly"));
        frequency_cbox.prepend ("monthly", _("Monthly"));
        frequency_cbox.prepend ("weekly", _("Weekly"));
        frequency_cbox.prepend ("daily", _("Daily"));

        interval_label = new Gtk.Label (_("Every:"));

        interval_spin = new Gtk.SpinButton.with_range (1, 999, 1);
        freq_unit_label = new Gtk.Label (null);

        week_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        mon_button = new Gtk.ToggleButton.with_label (_("Mon"));
        tue_button = new Gtk.ToggleButton.with_label (_("Tue"));
        wed_button = new Gtk.ToggleButton.with_label (_("Wed"));
        thu_button = new Gtk.ToggleButton.with_label (_("Thu"));
        fri_button = new Gtk.ToggleButton.with_label (_("Fri"));
        sat_button = new Gtk.ToggleButton.with_label (_("Sat"));
        sun_button = new Gtk.ToggleButton.with_label (_("Sun"));
        week_box_revealer = new Gtk.Revealer ();

        add_week_buttons (week_offset);
        week_box_revealer.add (week_box);

        day_radio = new Gtk.RadioButton.with_label_from_widget (null, "placeholder");
        week_day_radio = new Gtk.RadioButton.with_label_from_widget (day_radio, "placeholder");
        custom_day_radio = new Gtk.RadioButton.with_label_from_widget (day_radio, "placeholder"); // "Custom: %s"
        radio_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
        radio_revealer = new Gtk.Revealer ();
        radio_box.add (day_radio);
        radio_box.add (week_day_radio);
        radio_box.add (custom_day_radio);
        radio_revealer.add (radio_box);

        week_start_label = new Gtk.Label (_("Week starts at:"));
        week_start_cbox = new Gtk.ComboBoxText ();

        week_start_cbox.prepend ("sunday", _("Sunday"));
        week_start_cbox.prepend ("saturday", _("Saturday"));
        week_start_cbox.prepend ("friday", _("Friday"));
        week_start_cbox.prepend ("thursday", _("Thursday"));
        week_start_cbox.prepend ("wednesday", _("Wednesday"));
        week_start_cbox.prepend ("tuesday", _("Tuesday"));
        week_start_cbox.prepend ("monday", _("Monday"));

        var week_start_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        week_start_box.add (week_start_label);
        week_start_box.add (week_start_cbox);

        week_start_revealer = new Gtk.Revealer ();
        week_start_revealer.add (week_start_box);

        native_recur_grid.add (interval_label);
        var interval_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        interval_box.add (interval_spin);
        interval_box.add (freq_unit_label);
        native_recur_grid.add (interval_box);

        native_recur_grid.add (week_box_revealer);
        native_recur_grid.add (radio_revealer);
        native_recur_grid.add (week_start_revealer);

        rrule_info_label = new Gtk.Label (
            _("%s supports custom recurrence rules written in the iCalendar RRULE standard.").printf ("<i>Go For It!</i>")
        );
        rrule_info_label2 = new Gtk.Label (
            _("The current recurrence rule wasn't generated by %1$s. %1$s can only display the RRULE as text.").printf ("<i>Go For It!</i>")
        );

        rrule_entry = new Gtk.Entry ();

        rrule_grid.add (rrule_info_label);
        rrule_grid.add (rrule_info_label2);
        rrule_grid.add (rrule_entry);

        periodic_settings_stack.add (native_recur_grid);
        periodic_settings_stack.add (rrule_grid);

        layout_grid.add (due_label);
        layout_grid.add (date_picker);
        layout_grid.add (time_box);

        layout_grid.add (repeat_label);

        var repeat_kind_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        repeat_kind_box.add (repeat_switch);
        repeat_kind_box.add (repetition_kind_cbox);

        layout_grid.add (repeat_kind_box);

        layout_grid.add (frequency_label);
        layout_grid.add (frequency_cbox);

        layout_grid.add (periodic_settings_stack);
        this.get_content_area ().add (layout_grid);
    }

    private void connect_signals () {
        repetition_kind_cbox.changed.connect (on_repition_kind_changed);
        frequency_cbox.changed.connect (on_frequency_changed);
        interval_spin.value_changed.connect (set_freq_unit_label);
        week_start_cbox.changed.connect (on_week_start_changed);

        repeat_switch.notify["active"].connect (on_repeat_switch_changed);

        time_mode_selector.changed.connect (set_time_picker_visible);
    }

    private void on_repeat_switch_changed () {
        update_sensitive (repeat_switch.active);
    }

    private void set_time_picker_visible () {
        switch (time_mode_selector.active_id) {
            case "time":
                time_picker.sensitive = true;
                time_picker_revealer.reveal_child = true;
                break;
            default:
                time_picker.sensitive = false;
                time_picker_revealer.reveal_child = false;
                break;
        }
    }

    private void set_freq_unit_label () {
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

    private void on_week_start_changed () {
        switch (week_start_cbox.active_id) {
            case "monday":
                week_offset = 0;
                break;
            case "tuesday":
                week_offset = 1;
                break;
            case "wednesday":
                week_offset = 2;
                break;
            case "thursday":
                week_offset = 3;
                break;
            case "friday":
                week_offset = 4;
                break;
            case "saturday":
                week_offset = 5;
                break;
            default:
                week_offset = 6;
                break;
        }
        add_week_buttons (week_offset, true);
    }

    private void add_week_buttons (int week_offset, bool remove = false) {
        Gtk.ToggleButton[] week_buttons = {mon_button, tue_button, wed_button, thu_button, fri_button, sat_button, sun_button};
        for (int i = 0; remove && i < 7; i++) {
            week_box.remove (week_buttons[i]);
        }
        for (int i = 0; i < 7; i++) {
            week_box.add (week_buttons[i+week_offset % 7]);
        }
    }

    private void update_sensitive (bool sensitive) {
        repetition_kind_cbox.sensitive = sensitive;
        week_box.sensitive = sensitive;
        radio_box.sensitive = sensitive;
        week_start_cbox.sensitive = sensitive;
    }

    private void on_repition_kind_changed () {
        if (repetition_kind_cbox.active_id == "by_due") {
            on_frequency_changed ();
            interval_label.label = _("Every:");
        } else {
            radio_revealer.reveal_child = false;
            week_box_revealer.reveal_child = false;
            interval_label.label = _("Schedule next task after:");
        }
    }

    private void on_frequency_changed () {
        set_freq_unit_label ();
        switch (frequency_cbox.active_id) {
            case "daily":
                radio_revealer.reveal_child = false;
                week_box_revealer.reveal_child = false;
                break;
            case "weekly":
                radio_revealer.reveal_child = false;
                if (repetition_kind_cbox.active_id == "by_due") {
                    week_box_revealer.reveal_child = true;
                }
                break;
            default:
                update_radio_labels ();
                if (repetition_kind_cbox.active_id == "by_due") {
                    radio_revealer.reveal_child = true;
                }
                week_box_revealer.reveal_child = false;
                break;
        }
    }

    private void update_radio_labels () {
        if (due_date == null) {
            return;
        }

        int month_day, day_of_week, day_position;
        get_month_day (out month_day, out day_of_week, out day_position);

        var week_day = day_int_to_ical_week_day (day_of_week);

        if (frequency_cbox.active_id == "monthly") {

            if (month_day < 0) {
                day_radio.label = _("The last day of every month");
            } else {
                day_radio.label = _("Day %i of every month").printf (month_day);
            }

            week_day_radio.label = get_month_week_day (
                day_position, week_day
            );

            if (fifth_week_was_selected) {
                custom_day_radio.label = get_month_week_day (
                    5, week_day
                );
            }
        } else {
            var month_str = due_date.format ("%B");

            if (month_day < 0) {
                /// Translators: %s is replaced with localized month name.
                day_radio.label = _("The last day of %s").printf (month_str);
            } else {
                /// Translators: %2$s is replaced with localized month name.
                day_radio.label = _("Day %1$i of %2$s").printf (month_day, month_str);
            }

            var month_week_day_str = get_month_week_day_for_month (day_position, week_day);
            month_week_day_str.printf (month_str);
            week_day_radio.label = month_week_day_str.printf (month_str);

            if (fifth_week_was_selected) {
                month_week_day_str = get_month_week_day_for_month (5, week_day);
                month_week_day_str.printf (month_str);
                custom_day_radio.label = month_week_day_str.printf (month_str);
            }
        }

        radio_revealer.reveal_child = true;
        week_box_revealer.reveal_child = false;
    }

    private ICal.RecurrenceWeekday day_int_to_ical_week_day (int day_int) {
        switch (day_int) {
            case 1:
                return ICal.RecurrenceWeekday.MONDAY_WEEKDAY;
            case 2:
                return ICal.RecurrenceWeekday.TUESDAY_WEEKDAY;
            case 3:
                return ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY;
            case 4:
                return ICal.RecurrenceWeekday.THURSDAY_WEEKDAY;
            case 5:
                return ICal.RecurrenceWeekday.FRIDAY_WEEKDAY;
            case 6:
                return ICal.RecurrenceWeekday.SATURDAY_WEEKDAY;
            default:
                return ICal.RecurrenceWeekday.SUNDAY_WEEKDAY;
        }
    }

    private int ical_week_day_to_day_int (ICal.RecurrenceWeekday weekday) {
        switch (weekday) {
            case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                return 1;
            case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                return 2;
            case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                return 3;
            case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                return 4;
            case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                return 5;
            case ICal.RecurrenceWeekday.SATURDAY_WEEKDAY:
                return 6;
            default:
                return 7;
        }
    }

    /**
     * Adapted from Maya.View.EventEdition.RepeatPanel.set_every_day
     * The biggest advantage of this is that we can reuse translations
     *
     * This can't be simplified because of some problems with the translation.
     * see https://bugs.launchpad.net/maya/+bug/1405605 for reference.
     */
    private string get_month_week_day (int day_position, ICal.RecurrenceWeekday weekday) {
        switch (day_position) {
            case -1:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("Every last Sunday");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("Every last Monday");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("Every last Tuesday");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("Every last Wednesday");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("Every last Thursday");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("Every last Friday");
                    default:
                        return _("Every last Saturday");
                }
            case 1:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("Every first Sunday");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("Every first Monday");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("Every first Tuesday");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("Every first Wednesday");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("Every first Thursday");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("Every first Friday");
                    default:
                        return _("Every first Saturday");
                }
            case 2:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("Every second Sunday");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("Every second Monday");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("Every second Tuesday");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("Every second Wednesday");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("Every second Thursday");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("Every second Friday");
                    default:
                        return _("Every second Saturday");
                }
            case 3:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("Every third Sunday");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("Every third Monday");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("Every third Tuesday");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("Every third Wednesday");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("Every third Thursday");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("Every third Friday");
                    default:
                        return _("Every third Saturday");
                }
            case 4:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("Every fourth Sunday");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("Every fourth Monday");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("Every fourth Tuesday");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("Every fourth Wednesday");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("Every fourth Thursday");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("Every fourth Friday");
                    default:
                        return _("Every fourth Saturday");
                }
            default:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("Every fifth Sunday");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("Every fifth Monday");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("Every fifth Tuesday");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("Every fifth Wednesday");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("Every fifth Thursday");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("Every fifth Friday");
                    default:
                        return _("Every fifth Saturday");
                }
        }
    }
    private string get_month_week_day_for_month (int day_position, ICal.RecurrenceWeekday weekday) {
        switch (day_position) {
            case -1:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("The last Sunday of every %s");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("The last Monday of every %s");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("The last Tuesday of every %s");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("The last Wednesday of every %s");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("The last Thursday of every %s");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("The last Friday of every %s");
                    default:
                        return _("The last Saturday of every %s");
                }
            case 1:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("The first Sunday of every %s");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("The first Monday of every %s");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("The first Tuesday of every %s");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("The first Wednesday of every %s");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("The first Thursday of every %s");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("The first Friday of every %s");
                    default:
                        return _("The first Saturday of every %s");
                }
            case 2:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("The second Sunday of every %s");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("The second Monday of every %s");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("The second Tuesday of every %s");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("The second Wednesday of every %s");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("The second Thursday of every %s");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("The second Friday of every %s");
                    default:
                        return _("The second Saturday of every %s");
                }
            case 3:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("The third Sunday of every %s");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("The third Monday of every %s");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("The third Tuesday of every %s");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("The third Wednesday of every %s");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("The third Thursday of every %s");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("The third Friday of every %s");
                    default:
                        return _("The third Saturday of every %s");
                }
            case 4:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("The fourth Sunday of every %s");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("The fourth Monday of every %s");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("The fourth Tuesday of every %s");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("The fourth Wednesday of every %s");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("The fourth Thursday of every %s");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("The fourth Friday of every %s");
                    default:
                        return _("The fourth Saturday of every %s");
                }
            default:
                switch (weekday) {
                    case ICal.RecurrenceWeekday.SUNDAY_WEEKDAY:
                        return _("The fifth Sunday of every %s");
                    case ICal.RecurrenceWeekday.MONDAY_WEEKDAY:
                        return _("The fifth Monday of every %s");
                    case ICal.RecurrenceWeekday.TUESDAY_WEEKDAY:
                        return _("The fifth Tuesday of every %s");
                    case ICal.RecurrenceWeekday.WEDNESDAY_WEEKDAY:
                        return _("The fifth Wednesday of every %s");
                    case ICal.RecurrenceWeekday.THURSDAY_WEEKDAY:
                        return _("The fifth Thursday of every %s");
                    case ICal.RecurrenceWeekday.FRIDAY_WEEKDAY:
                        return _("The fifth Friday of every %s");
                    default:
                        return _("The fifth Saturday of every %s");
                }
        }
    }
}
