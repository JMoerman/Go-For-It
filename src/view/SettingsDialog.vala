/* Copyright 2015 Manuel Kehl (mank319)
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

namespace GOFI {

    /**
     * A dialog for changing the application's settings.
     */
    public class SettingsDialog : Gtk.Dialog {
        private SettingsManager settings;
        private PluginManager plugin_manager;
        
        /* GTK Widgets */
        private Gtk.Grid main_layout;
        private Gtk.Stack stack;
        private Gtk.StackSwitcher switcher;
        
        // timer settings
        private Gtk.Grid timer_layout;
        private Gtk.Label task_lbl;
        private Gtk.SpinButton task_spin;
        private Gtk.Label break_lbl;
        private Gtk.SpinButton break_spin;
        private Gtk.Label reminder_lbl;
        private Gtk.SpinButton reminder_spin;
        
        // plugin settings
        private Gtk.Box plugin_layout;
        private Gtk.Widget plugin_settings_widget;
        
        public SettingsDialog (Gtk.Window? parent, SettingsManager settings, 
                PluginManager plugin_manager) {
            this.set_transient_for (parent);
            this.settings = settings;
            this.plugin_manager = plugin_manager;
            
            /* General Settigns */
            // Default to minimum possible size
            this.set_default_size (1, 1);
            this.get_content_area ().margin = 10;
            this.get_content_area ().margin_top = 0;
            this.set_modal (true);
            
            this.title = _("Settings");
            setup_layouts ();
            setup_plugin_settings_widgets ();
            setup_timer_settings_widgets ();
            this.add_button (_("Close"), Gtk.ResponseType.CLOSE);
            
            apply_global_settings ();
            
            /* Action Handling */
            this.response.connect ((s, response) => {
                if (response == Gtk.ResponseType.CLOSE) {
                    this.destroy ();
                }
            });
            this.show_all ();
        }
        
        private void setup_layouts () {
            /* Initalization */
            main_layout = new Gtk.Grid ();
            stack = new Gtk.Stack ();
            switcher = new Gtk.StackSwitcher ();
            plugin_layout = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            timer_layout = new Gtk.Grid ();
            
            main_layout.orientation = Gtk.Orientation.VERTICAL;
            
            // Stack + Switcher
            switcher.set_stack (stack);
            switcher.halign = Gtk.Align.CENTER;
            switcher.margin = 5;
            switcher.vexpand = false;
            stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            
            timer_layout.orientation = Gtk.Orientation.VERTICAL;
            timer_layout.row_spacing = 15;
            
            stack.add_titled(plugin_layout, "plugins", _("Plugins"));
            stack.add_titled(timer_layout, "timer", _("Time"));
            
            main_layout.add (switcher);
            main_layout.add (stack);
            this.get_content_area ().pack_start (main_layout);
        }
        
        private void apply_global_settings () {
            /* Settings that apply for all widgets in the dialog */
            foreach (var child in plugin_layout.get_children ()) {
                child.halign = Gtk.Align.START;
            }
            foreach (var child in timer_layout.get_children ()) {
                child.halign = Gtk.Align.START;
            }
        }
        
        private void setup_plugin_settings_widgets () {
            
            plugin_settings_widget = plugin_manager.get_settings_widget ();
            plugin_settings_widget.expand = true;
            plugin_layout.pack_start (plugin_settings_widget, true, true, 15);
        }
        
        private void setup_timer_settings_widgets () {
            /* Instantiation */
            task_lbl = new Gtk.Label (_("Task duration (minutes)") + ":");
            break_lbl = new Gtk.Label (_("Break duration (minutes)") + ":");
            reminder_lbl = new Gtk.Label (_("Reminder before task ends (seconds)") +":");
            // No more than one day: 60 * 24 -1 = 1439
            task_spin = new Gtk.SpinButton.with_range (1, 1439, 1);
            break_spin = new Gtk.SpinButton.with_range (1, 1439, 1);
            // More than ten minutes would not make much sense
            reminder_spin = new Gtk.SpinButton.with_range (0, 600, 1);
            
            /* Configuration */
            task_spin.value = settings.task_duration / 60;
            break_spin.value = settings.break_duration / 60;
            reminder_spin.value = settings.reminder_time;
            
            /* Signal Handling */
            task_spin.value_changed.connect ((e) => {
                settings.task_duration = task_spin.get_value_as_int () * 60;
            });
            break_spin.value_changed.connect ((e) => {
                settings.break_duration = break_spin.get_value_as_int () * 60;
            });
            reminder_spin.value_changed.connect ((e) => {
                settings.reminder_time = reminder_spin.get_value_as_int ();
            });
            
            /* Add widgets */
            timer_layout.add (task_lbl);
            timer_layout.add (task_spin);
            timer_layout.add (break_lbl);
            timer_layout.add (break_spin);
            timer_layout.add (reminder_lbl);
            timer_layout.add (reminder_spin);
        }
    }
}
