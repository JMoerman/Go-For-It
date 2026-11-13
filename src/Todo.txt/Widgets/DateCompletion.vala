/* Copyright 2026 GoForIt! developers
*
* This file is part of GoForIt!.
*
* GoForIt! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* GoForIt! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with GoForIt!. If not, see http://www.gnu.org/licenses/.
*/

/**
 * Shows a calendar while the user types a "due:" or "t:" (threshold) date in
 * the new task entry.
 *
 * The calendar opens in a popover above the entry as soon as the last word
 * is "due:" or "t:", and follows a date that is typed in full. Clicking a
 * day inserts it.
 *
 * Keys while the calendar is shown: Left/Right move one day, Up/Down one
 * week, Page Up/Page Down one month, Enter or Tab insert the selected date,
 * Escape closes the calendar. Enter after a fully typed date, without
 * moving in the calendar, still adds the task.
 */
class GOFI.TXT.DateCompletion : Object {
    private unowned Gtk.Entry entry;
    private Gtk.Popover popover;
    private Gtk.Calendar calendar;

    // Set while the calendar is changed from code, so its signals are not
    // mistaken for clicks.
    private bool programmatic = false;
    private bool month_just_changed = false;
    // Whether the date was picked with the arrow keys since the last edit.
    private bool navigated = false;
    // The key of the word being completed ("due" or "t") and what follows ':'.
    private string? key = null;
    private string value_text = "";

    public DateCompletion (Gtk.Entry entry) {
        this.entry = entry;

        calendar = new Gtk.Calendar ();
        // Keep the keyboard focus in the entry, also when clicking.
        calendar.can_focus = false;
        calendar.margin = 4;
        calendar.month_changed.connect (() => {
            if (!programmatic) {
                month_just_changed = true;
            }
        });
        calendar.day_selected.connect (on_day_selected);

        popover = new Gtk.Popover (entry);
        popover.modal = false;
        popover.position = Gtk.PositionType.TOP;
        popover.add (calendar);
        calendar.show ();

        entry.changed.connect_after (on_entry_changed);
        entry.key_press_event.connect (on_key_press);
        entry.focus_out_event.connect (() => {
            popover.popdown ();
            return false;
        });
    }

    private static string last_word (string text) {
        int space = text.last_index_of_char (' ');
        return text.substring (space + 1);
    }

    /**
     * Parses a complete YYYY-MM-DD date, returns null for anything else.
     */
    private static DateTime? parse_date (string text) {
        int y = 0, m = 0, d = 0;
        if (text.length != 10 || text[4] != '-' || text[7] != '-' ||
            text.scanf ("%4d-%2d-%2d", out y, out m, out d) != 3) {
            return null;
        }
        if (m < 1 || m > 12 || d < 1 ||
            d > ((DateMonth) m).get_days_in_month ((DateYear) y)) {
            return null;
        }
        return new DateTime.local (y, m, d, 0, 0, 0);
    }

    private void on_entry_changed () {
        if (programmatic) {
            return;
        }
        navigated = false;
        string text = entry.text;
        string word = last_word (text);

        key = null;
        if (word.has_prefix ("due:")) {
            key = "due";
        } else if (word.has_prefix ("t:")) {
            key = "t";
        }
        if (key == null) {
            popover.popdown ();
            return;
        }
        value_text = word.substring (key.length + 1);

        // Follow a fully typed date; otherwise start at today, or keep the
        // date that is already shown.
        var typed = parse_date (value_text);
        if (typed != null) {
            set_calendar_date (typed);
        } else if (!popover.visible) {
            set_calendar_date (new DateTime.now_local ());
        }

        popover.pointing_to = word_rectangle (
            text.char_count () - word.char_count ());
        if (!popover.visible) {
            popover.popup ();
        }
    }

    private DateTime get_calendar_date () {
        uint y, m, d;
        calendar.get_date (out y, out m, out d);
        return new DateTime.local ((int) y, (int) m + 1, (int) d, 0, 0, 0);
    }

    private void set_calendar_date (DateTime date) {
        programmatic = true;
        // Select day 1 first, so the day is valid in the new month.
        calendar.select_day (1);
        calendar.select_month (date.get_month () - 1, date.get_year ());
        calendar.select_day (date.get_day_of_month ());
        programmatic = false;
    }

    /**
     * A click on a day inserts it. Clicks on the month and year arrows (or
     * on a day of the previous or next month, which first switches the
     * month) only change what is shown.
     */
    private void on_day_selected () {
        if (programmatic) {
            return;
        }
        Idle.add (() => {
            if (!month_just_changed && key != null) {
                insert_date ();
            }
            month_just_changed = false;
            return Source.REMOVE;
        });
    }

    private void insert_date () {
        string text = entry.text;
        int space = text.last_index_of_char (' ');
        string date = get_calendar_date ().format ("%Y-%m-%d");
        programmatic = true;
        entry.text = text.substring (0, space + 1) + key + ":" + date + " ";
        programmatic = false;
        key = null;
        popover.popdown ();
        entry.grab_focus_without_selecting ();
        entry.set_position (-1);
    }

    private void move_date (int days, int months = 0) {
        var date = get_calendar_date ();
        date = (months != 0) ? date.add_months (months) : date.add_days (days);
        set_calendar_date (date);
        navigated = true;
    }

    /**
     * The position of the start of the word in entry coordinates, so the
     * popover points at the date being typed.
     */
    private Gdk.Rectangle word_rectangle (int word_start) {
        int layout_x, layout_y;
        entry.get_layout_offsets (out layout_x, out layout_y);
        int index = entry.text_index_to_layout_index (
            entry.text.index_of_nth_char (word_start));
        Pango.Rectangle pos = entry.get_layout ().index_to_pos (index);

        Gtk.Allocation alloc;
        entry.get_allocation (out alloc);
        Gdk.Rectangle rect = { 0, 0, 1, alloc.height };
        rect.x = int.max (0, layout_x + pos.x / Pango.SCALE);
        return rect;
    }

    private bool on_key_press (Gdk.EventKey event) {
        if (!popover.visible || key == null) {
            return false;
        }
        switch (event.keyval) {
            case Gdk.Key.Left:
            case Gdk.Key.KP_Left:
                move_date (-1);
                return true;
            case Gdk.Key.Right:
            case Gdk.Key.KP_Right:
                move_date (1);
                return true;
            case Gdk.Key.Up:
            case Gdk.Key.KP_Up:
                move_date (-7);
                return true;
            case Gdk.Key.Down:
            case Gdk.Key.KP_Down:
                move_date (7);
                return true;
            case Gdk.Key.Page_Up:
            case Gdk.Key.KP_Page_Up:
                move_date (0, -1);
                return true;
            case Gdk.Key.Page_Down:
            case Gdk.Key.KP_Page_Down:
                move_date (0, 1);
                return true;
            case Gdk.Key.Escape:
                popover.popdown ();
                return true;
            case Gdk.Key.Return:
            case Gdk.Key.KP_Enter:
                // A date typed in full and not changed in the calendar:
                // Enter adds the task as usual.
                if (value_text != "" && !navigated) {
                    popover.popdown ();
                    return false;
                }
                insert_date ();
                return true;
            case Gdk.Key.Tab:
                insert_date ();
                return true;
            default:
                return false;
        }
    }
}
