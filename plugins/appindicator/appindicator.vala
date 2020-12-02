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

using AppIndicator;

class GOFI.Plugins.AyatanaIndicator.PanelIndicator : Peas.ExtensionBase, Peas.Activatable {

    private Indicator indicator;
    private uint shown_hours = 0;
    private uint shown_minutes = 0;
    private uint shown_seconds = 0;
    private bool timer_running = false;
    private bool showing_break = false;
    private string? active_task_description = null;
    private Gtk.MenuItem task_descr_item;
    private Gtk.MenuItem show_item;
    private Gtk.MenuItem quit_item;
    private Gtk.MenuItem start_timer_item;
    private Gtk.MenuItem mark_done_item;
    private Gtk.MenuItem next_task_item;
    private Gtk.MenuItem prev_task_item;
    private Gtk.Menu menu;

    /**
     * The plugin interface.
     */
    public Object object { owned get; construct; }

    private GOFI.PluginInterface iface {
        owned get {
            return (GOFI.PluginInterface) object;
        }
    }

    public void activate () {
        if (indicator != null) {
            return;
        }
        var category = IndicatorCategory.APPLICATION_STATUS;
        if (ICONS_IN_DATA_DIR) {
            var icon_theme_path = GLib.Path.build_filename (this.data_dir, "icons");
            indicator = new Indicator.with_path (GOFI.APP_ID, STATUS_TASK_PANEL_ICON, category, icon_theme_path);
        } else {
            indicator = new Indicator (GOFI.APP_ID, STATUS_TASK_PANEL_ICON, category);
        }

        indicator.set_status(IndicatorStatus.ACTIVE);

        build_menu ();
        indicator.connection_changed.connect (on_connection_changed);
    }

    private void on_connection_changed (bool connected) {
        if (connected) {
            iface.set_provides_timer_controls (this);
        } else if (!connected) {
            iface.unset_provides_timer_controls (this);
        }
    }

    private void build_menu () {
        menu = new Gtk.Menu();

        show_item = new Gtk.MenuItem.with_label (_("Open %s").printf (GOFI.APP_NAME));
        show_item.activate.connect (show_application_window);
        show_item.show ();
        menu.append (show_item);

        quit_item = new Gtk.MenuItem.with_label (_("Close"));
        quit_item.activate.connect (queue_close);
        quit_item.show ();
        menu.append (quit_item);

        var separator_item = new Gtk.SeparatorMenuItem ();
        separator_item.show ();
        menu.append (separator_item);

        task_descr_item = new Gtk.MenuItem.with_label (_("No task has been selected"));
        task_descr_item.sensitive = false;
        task_descr_item.show ();
        menu.append (task_descr_item);

        separator_item = new Gtk.SeparatorMenuItem ();
        separator_item.show ();
        menu.append (separator_item);

        mark_done_item = new Gtk.MenuItem.with_label (_("Mark the task as complete"));
        mark_done_item.sensitive = false;
        mark_done_item.show ();
        mark_done_item.activate.connect (mark_done);
        menu.append (mark_done_item);

        next_task_item = new Gtk.MenuItem.with_label (_("Switch to next task"));
        next_task_item.sensitive = false;
        next_task_item.show ();
        next_task_item.activate.connect (switch_to_next);
        menu.append (next_task_item);

        prev_task_item = new Gtk.MenuItem.with_label (_("Switch to the previous task"));
        prev_task_item.sensitive = false;
        prev_task_item.show ();
        prev_task_item.activate.connect (switch_to_previous);
        menu.append (prev_task_item);

        start_timer_item = new Gtk.MenuItem.with_label (_("Start the timer"));
        start_timer_item.sensitive = false;
        start_timer_item.show ();
        start_timer_item.activate.connect (toggle_timer);
        menu.append (start_timer_item);

        indicator.set_menu (menu);
        indicator.set_secondary_activate_target (show_item);
        connect_timer_signals ();
    }

    private void switch_to_next () {
        iface.next_task ();
    }

    private void switch_to_previous () {
        iface.previous_task ();
    }

    private void mark_done () {
        iface.mark_task_as_done ();
    }

    private void toggle_timer () {
        var timer = iface.get_timer ();
        timer.toggle_running ();
    }

    private void show_application_window () {
        var win = iface.get_window ();
        win.show ();
        win.present ();
    }

    private void queue_close () {
        this.deactivate ();
        GLib.Idle.add (close_application_window_source_func);
    }

    private bool close_application_window_source_func () {
        close_application_window ();
        return GLib.Source.REMOVE;
    }

    private void close_application_window () {
        iface.quit_application ();
    }

    private void update_timer_label (uint timer_value) {
        if (!timer_running) {
            return;
        }
        uint hours, minutes, seconds;
        GOFI.Utils.uint_to_time (timer_value, out hours, out minutes, out seconds);
        if (hours > 0 || minutes > 0) {
            if (seconds >= 30) {
                minutes += 1;
            }
            if (minutes == 60) {
                minutes = 59;
                hours += 1;
            }
            if (hours > 0) {
                if (hours != shown_hours || minutes != shown_minutes) {
                    indicator.label = "%uh-%um".printf(hours, minutes);
                }
            } else if (minutes > 0) {
                if (minutes != shown_minutes) {
                    indicator.label = "%um".printf(minutes);
                }
            }
            seconds = 0;
        } else if (shown_seconds != seconds) {
            indicator.label = "%us".printf(seconds);
        }
        shown_minutes = minutes;
        shown_seconds = seconds;
        shown_hours = hours;
    }

    private void on_active_task_updated (TodoTask? task) {
        if (task == null) {
            task_descr_item.label = _("No task has been selected");
            active_task_description = null;
            start_timer_item.sensitive = false;
            mark_done_item.sensitive = false;
            next_task_item.sensitive = false;
            prev_task_item.sensitive = false;
        } else {
            active_task_description = task.description;
            var timer = iface.get_timer ();
            if (timer.break_active) {
                if (!showing_break) {
                    indicator.icon_name = STATUS_BREAK_PANEL_ICON;
                    task_descr_item.label = GOFI.Utils.string_to_exclamation (_("Take a Break"));
                    showing_break = true;
                }
            } else {
                if (showing_break) {
                    indicator.icon_name = STATUS_TASK_PANEL_ICON;
                    showing_break = false;
                }
                var description = active_task_description;
                if (description.char_count () > 30) {
                    task_descr_item.label = description.substring (0, 27) + "...";
                } else {
                    task_descr_item.label = description;
                }
            }
            start_timer_item.sensitive = true;
            next_task_item.sensitive = true;
            prev_task_item.sensitive = true;
            mark_done_item.sensitive = true;
        }
    }

    private void on_timer_started () {
        timer_running = true;
        update_timer_label (iface.get_timer ().remaining_duration);
        start_timer_item.label = _("Stop the timer");
    }

    private void on_timer_stopped () {
        timer_running = false;
        indicator.label = "";
        shown_hours = 0;
        shown_minutes = 0;
        shown_seconds = 0;
        start_timer_item.label = _("Start the timer");
    }

    private void connect_timer_signals () {
        var timer = iface.get_timer ();
        timer_running = timer.running;
        on_active_task_updated (timer.active_task);
        timer.timer_updated.connect (update_timer_label);
        timer.timer_started.connect (on_timer_started);
        timer.timer_stopped.connect (on_timer_stopped);
        timer.active_task_changed.connect (on_active_task_updated);
        timer.active_task_description_changed.connect (on_active_task_updated);
    }

    private void disconnect_timer_signals () {
        var timer = iface.get_timer ();
        timer.timer_updated.disconnect (update_timer_label);
        timer.timer_started.disconnect (on_timer_started);
        timer.timer_stopped.disconnect (on_timer_stopped);
        timer.active_task_changed.disconnect (on_active_task_updated);
        timer.active_task_description_changed.disconnect (on_active_task_updated);
    }

    private void free_menu () {
        disconnect_timer_signals ();
        menu = null;
        task_descr_item = null;
        show_item = null;
        quit_item = null;
        start_timer_item = null;
        mark_done_item = null;
        next_task_item = null;
        prev_task_item = null;
    }

    public void deactivate () {
        if (indicator.connected) {
            iface.unset_provides_timer_controls (this);
        }
        free_menu ();
        indicator = null;
    }

    public void update_state () {}
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (GOFI.Plugins.AyatanaIndicator.PanelIndicator));
}
