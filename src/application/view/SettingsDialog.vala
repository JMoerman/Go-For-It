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

namespace GOFI.Application {

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
        
        // Plugin page
        private Gtk.Grid plugin_layout;
        private Gtk.Widget plugin_settings_widget;
        
        // Behavior page
        private Gtk.Grid behavior_layout;
        // timer
        private Gtk.Label timer_sect_lbl;
        private Gtk.Label task_lbl;
        private Gtk.SpinButton task_spin;
        private Gtk.Label break_lbl;
        private Gtk.SpinButton break_spin;
        private Gtk.Label reminder_lbl;
        private Gtk.SpinButton reminder_spin;
        
        // Appearance page
        private Gtk.Grid appearance_layout;
        // headerbar
        private Gtk.Label headerbar_sect_lbl;
        private Gtk.Label headerbar_lbl;
        private Gtk.Switch headerbar_switch;
        
        private Gtk.Align label_alignment = Gtk.Align.START;
        
        public SettingsDialog (Gtk.Window? parent, SettingsManager settings,
                               PluginManager plugin_manager)
        {
            this.set_transient_for (parent);
            this.settings = settings;
            this.plugin_manager = plugin_manager;
            
            /* General Settigns */
            // Default to minimum possible size
            this.set_default_size (1, 1);
            this.set_modal (true);
            
            this.title = _("Settings");
            setup_layouts ();
            setup_plugin_page ();
            setup_behavior_page ();
            setup_appearance_page ();
            this.add_button (_("Close"), Gtk.ResponseType.CLOSE);
            
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
            plugin_layout = new Gtk.Grid ();
            behavior_layout = new Gtk.Grid ();
            appearance_layout = new Gtk.Grid ();
            
            main_layout.orientation = Gtk.Orientation.VERTICAL;
            
            // Stack + Switcher
            switcher.set_stack (stack);
            switcher.halign = Gtk.Align.CENTER;
            switcher.vexpand = false;
            stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            
            apply_layout_settings (plugin_layout);
            apply_layout_settings (behavior_layout);
            apply_layout_settings (appearance_layout);
            
            stack.add_titled (plugin_layout, "plugins", _("Plugins"));
            stack.add_titled (behavior_layout, "behavior", _("Behavior"));
            stack.add_titled (appearance_layout, "appearance", _("Appearance"));
            
            main_layout.add (switcher);
            main_layout.add (stack);
            this.get_content_area ().pack_start (main_layout);
        }
        
        private void apply_layout_settings (Gtk.Grid grid) {
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.row_spacing = 5;
            grid.column_spacing = 5;
            grid.margin = 12;
        }
        
        private void setup_plugin_page () {
            /* Instantiation */
            plugin_settings_widget = plugin_manager.get_settings_widget ();
            
            /* Configuration */
            plugin_settings_widget.expand = true;
            
            /* Add widgets */
            plugin_layout.add (plugin_settings_widget);
        }
        
        private void setup_behavior_page () {
            /* Instantiation */
            timer_sect_lbl = new Gtk.Label (_("Timer"));
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
            int row = 0;
            add_section (behavior_layout, timer_sect_lbl, ref row);
            add_option (behavior_layout, task_lbl, task_spin, ref row);
            add_option (behavior_layout, break_lbl, break_spin, ref row);
            add_option (behavior_layout, reminder_lbl, reminder_spin, ref row);
        }
        
        private void add_section (Gtk.Grid grid, Gtk.Label name, ref int row) {
            name.use_markup = true;
            name.set_markup ("<b>%s</b>".printf (name.get_text ()));
            name.halign = Gtk.Align.START;
            grid.attach (name, 0, row, 1, 1);
            row++;
        }
        
        private void add_option (Gtk.Grid grid, Gtk.Widget label, 
                                 Gtk.Widget switcher, ref int row)
        {
            label.hexpand = true;
            switcher.hexpand = true;
            label.margin_left = 20; // indentation
            label.halign = label_alignment;
            switcher.halign = Gtk.Align.FILL;
            
            if (switcher is Gtk.Switch || switcher is Gtk.Entry) {
                switcher.halign = Gtk.Align.START;
            }
            
            grid.attach (label, 0, row);
            grid.attach (switcher, 1, row);
            row++;
        }
        
        private void setup_appearance_page () {
            /* Instantiation */
            headerbar_sect_lbl = new Gtk.Label (_("Client side decorations"));
            headerbar_lbl = new Gtk.Label (_("Use a header bar") + (":"));
            headerbar_switch = new Gtk.Switch ();
            
            /* Configuration */
            headerbar_switch.active = settings.use_header_bar;
            
            /* Signal Handling */
            headerbar_switch.notify["active"].connect ( () => {
                settings.use_header_bar = headerbar_switch.active;
            });
            
            /* Add widgets */
            int row = 0;
            add_section (appearance_layout, headerbar_sect_lbl, ref row);
            add_option (appearance_layout, headerbar_lbl, headerbar_switch, ref row);
        }
        
        public override void show_all () {
            base.show_all ();
            plugin_settings_widget.set_halign (Gtk.Align.BASELINE);
        }
    }
}
