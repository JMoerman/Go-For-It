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
     * The main window of Go For It!.
     */
    class MainWindow : Gtk.ApplicationWindow {
        /* Various Variables */
        private TaskTimer task_timer;
        private SettingsManager settings;
        private bool use_header_bar;
        
        /* Various GTK Widgets */
        private Gtk.Grid main_layout;
        private TaskView task_view;
        private Gtk.StackSwitcher activity_switcher;
        private Gtk.HeaderBar header_bar;
        private Gtk.Box hb_replacement;
        private Gtk.ToggleToolButton menu_btn;
        // Application Menu
        private Gtk.Menu app_menu;
        private Gtk.MenuItem config_item;
        private Gtk.MenuItem clear_done_item;
        private Gtk.MenuItem refresh_item;
        private Gtk.MenuItem contribute_item;
        private Gtk.MenuItem about_item;
        /**
         * Used to determine if a notification should be sent.
         */
        private bool break_previously_active { get; set; default = false; }
        
        /**
         * The constructor of the MainWindow class.
         */
        public MainWindow (Gtk.Application app_context,
                TaskTimer task_timer, SettingsManager settings, 
                bool use_header_bar) {
            // Pass the applicaiton context via GObject-based construction, because
            // constructor chaining is not possible for Gtk.ApplicationWindow
            Object (application: app_context);
            this.task_timer = task_timer;
            this.settings = settings;
            this.use_header_bar = use_header_bar;

            setup_window ();
            setup_menu ();
            setup_widgets ();
            load_css ();
            setup_notifications ();
            // Enable Notifications for the App
            Notify.init (GOFI.APP_NAME);
        }
        
        public override bool delete_event (Gdk.EventAny event) {
            bool dont_exit = false;
            
            // Save window state upon deleting the window
            save_win_geometry ();
            
            if (task_timer.running) {
                this.show.connect (restore_win_geometry);
                hide ();
                dont_exit = true;
            }
            
            if (dont_exit == false) Notify.uninit ();
                
            return dont_exit;
        }
        
        /**
         * Configures the window's properties.
         */
        private void setup_window () {
            this.title = Constants.APP_NAME;
            this.set_border_width (0);
            restore_win_geometry ();
        }
        
        /** 
         * Initializes GUI elements and configures their look and behavior.
         */
        private void setup_widgets () {
            /* Instantiation of the Widgets */
            main_layout = new Gtk.Grid ();
            
            /* Widget Settings */
            // Main Layout
            main_layout.orientation = Gtk.Orientation.VERTICAL;
            
            setup_task_view ();
            setup_top_bar ();
            
            
            if (use_header_bar)
                main_layout.add (activity_switcher);
            else
                main_layout.add (hb_replacement);
            main_layout.add (task_view);
            
            // Add main_layout to the window
            this.add (main_layout);
        }
        
        private void setup_task_view () {
            activity_switcher = new Gtk.StackSwitcher ();
            activity_switcher.halign = Gtk.Align.CENTER;
            task_view = new TaskView (task_timer, settings);
            task_view.add_to_switcher (activity_switcher);
            task_view.margin = 5;
        }
        
        private void setup_top_bar () {
            // ToolButons and their corresponding images
            var menu_img = Constants.Utils.load_image_fallback (
                Gtk.IconSize.LARGE_TOOLBAR, "open-menu", "open-menu-symbolic", 
                "go-for-it-open-menu-fallback");
            menu_btn = new Gtk.ToggleToolButton ();
            // Headerbar Items
            menu_btn.icon_widget = menu_img;
            menu_btn.label_widget = new Gtk.Label (_("Menu"));
            menu_btn.toggled.connect (menu_btn_toggled);

            if (use_header_bar) {
                header_bar = new Gtk.HeaderBar ();
            
                // GTK Header Bar
                header_bar.set_show_close_button (true);
                header_bar.title = Constants.APP_NAME;
                this.set_titlebar (header_bar);
            
                // Add headerbar Buttons here
                header_bar.pack_end (menu_btn);
            }
            else {
                use_header_bar = false;
                hb_replacement = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                hb_replacement.pack_start (activity_switcher, true, true); 
                hb_replacement.pack_end (menu_btn, false, false);
            }
        }
        
        
        private void menu_btn_toggled (Gtk.ToggleToolButton source) {
            if (source.active) {
                app_menu.popup (null, null, calc_menu_position, 0,
                                Gtk.get_current_event_time ());
                app_menu.select_first (true);
            } else {
                app_menu.popdown ();
            }
        }
        
        private void calc_menu_position (Gtk.Menu menu, out int x, out int y) {
            /* Get relevant position values */
            int win_x, win_y;
            this.get_position (out win_x, out win_y);
            Gtk.Allocation btn_alloc, menu_alloc;
            menu_btn.get_allocation (out btn_alloc);
            app_menu.get_allocation (out menu_alloc);
            
            /*
             * The menu located below the app menu button.
             * Its right border is algined to the right side of the menu button,
             * because the button is the rightmost element of the toolbar.
             * This way the menu never overlaps the right side of the app's window.
             */
            x = win_x + btn_alloc.x - menu_alloc.width + btn_alloc.width;
            y = win_y + btn_alloc.y + btn_alloc.height;
        }
        
        private void setup_menu () {
            /* Initialization */
            app_menu = new Gtk.Menu ();
            config_item = new Gtk.MenuItem.with_label (_("Settings"));
            clear_done_item = new Gtk.MenuItem.with_label (_("Clear Done List"));
            refresh_item = new Gtk.MenuItem.with_label (_("Refresh"));
            contribute_item = new Gtk.MenuItem.with_label (_("Contribute / Donate"));
            about_item = new Gtk.MenuItem.with_label (_("About"));
            
            /* Signal and Action Handling */
            // Untoggle menu button, when menu is hidden
            app_menu.hide.connect ((e) => {
                menu_btn.active = false;
            });
            
            config_item.activate.connect ((e) => {
                var dialog = new SettingsDialog (this, settings);
                dialog.show ();
            });
            contribute_item.activate.connect ((e) => {
                var dialog = new ContributeDialog (this);
                dialog.show ();
            });
            about_item.activate.connect ((e) => {
                var app = get_application () as Main;
                app.show_about (this);
            });
            
            /* Add Items to Menu */
            app_menu.add (config_item);
            app_menu.add (clear_done_item);
            app_menu.add (refresh_item);
            app_menu.add (contribute_item);
            app_menu.add (about_item);
            
            /* And make all children visible */
            foreach (var child in app_menu.get_children ()) {
                child.visible = true;
            }
        }
        
        /**
         * Configures the emission of notifications when tasks/breaks are over
         */
        private void setup_notifications () {
            task_timer.active_task_changed.connect (task_timer_activated);
            task_timer.timer_almost_over.connect (display_almost_over_notification);
        }
        
        private void task_timer_activated (TodoTask task,
                                           bool break_active) {
            
            if (break_previously_active != break_active) {
                Notify.Notification notification;
                if (break_active) {
                    notification = new Notify.Notification (
                        _("Take a Break"), 
                        _("Relax and stop thinking about your current task for a while") 
                        + " :-)",
                        Constants.APP_SYSTEM_NAME);
                } else {
                    notification = new Notify.Notification (
                        _("The Break is Over"), 
                        _("Your next task is") + ": " + task.title, 
                        Constants.APP_SYSTEM_NAME);
                }
                
                try {
                    notification.show ();
                } catch (GLib.Error err){
                    GLib.stderr.printf(
                        "Error in notify! (break_active notification)\n");
                }
            }
            break_previously_active = break_active;
        }
        
        private void display_almost_over_notification (DateTime remaining_time) {
            int64 secs = remaining_time.to_unix ();
            Notify.Notification notification = new Notify.Notification (
                _("Prepare for your break"),
                _(@"You have $secs seconds left"), Constants.APP_SYSTEM_NAME);
            try {
                notification.show ();
            } catch (GLib.Error err){
                GLib.stderr.printf(
                    "Error in notify! (remaining_time notification)\n");
            }
        }
        
        /**
         * Searches the system for a css stylesheet, that corresponds to go-for-it.
         * If it has been found in one of the potential data directories, it gets
         * applied to the application.
         */
        private void load_css () {
            var screen = this.get_screen();
            var css_provider = new Gtk.CssProvider();
            // Scan all potential data dirs for the corresponding css file
            foreach (var dir in Environment.get_system_data_dirs ()) {
                // The path where the file is to be located
                var path = Path.build_filename (dir, Constants.APP_SYSTEM_NAME, 
                    "style", "go-for-it.css");
                // Only proceed, if file has been found
                if (FileUtils.test (path, FileTest.EXISTS)) {
                    try {
                        css_provider.load_from_path(path);
                        Gtk.StyleContext.add_provider_for_screen(
                            screen,css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
                    } catch (Error e) {
                        warning ("Cannot load CSS stylesheet: %s", e.message);
                    }
                }
            }
        }
        
        /**
         * Restores the window geometry from settings
         */
        private void restore_win_geometry () {
            if (settings.win_x == -1 || settings.win_y == -1) {
                // Center if no position have been saved yet
                this.set_position (Gtk.WindowPosition.CENTER);
            } else {
                this.move (settings.win_x, settings.win_y);
            }
            this.set_default_size (settings.win_width, settings.win_height);
        }
        
        /**
         * Persistently store the window geometry
         */
        private void save_win_geometry () {
            int x, y, width, height;
            this.get_position (out x, out y);
            this.get_size (out width, out height);
            
            // Store values in SettingsManager
            settings.win_x = x;
            settings.win_y = y;
            settings.win_width = width;
            settings.win_height = height;
        }
    }
}
