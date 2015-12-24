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
     * A class that handles access to settings in a transparent manner.
     * Its main motivation is the option of easily replacing Glib.KeyFile with 
     * another settings storage mechanism in the future.
     */
    protected class SettingsManager {
        private KeyFile key_file;
        
        /*
         * A list of constants that define settings group names
         */
        
        private const string GROUP_PLUGINS = "Plugins";
        private const string GROUP_TIMER = "Timer";
        private const string GROUP_UI = "Interface";
        
        // Whether or not Go For It! has been started for the first time
        public bool first_start = false;
        
        /*
         * A list of settings values with their corresponding access methods.
         * The "heart" of the SettingsManager class.
         */
        /*---GROUP:Plugins---------------------------------------------------------*/
        public string[] enabled_plugins {
            owned get {
                var plugins = get_value (GROUP_PLUGINS, "enabled_plugins", "");
                return plugins.split(":");
            }
            set {
                string plugins = "";
                for (int i = 0; value[i] != null; i++) {
                    plugins = plugins.concat (value[i], ":");
                }
                if (plugins.length > 2) {
                    set_value (GROUP_PLUGINS, "enabled_plugins", plugins.slice(0, plugins.length-1));
                } else {
                    set_value (GROUP_PLUGINS, "enabled_plugins", "");
                }
            }
        }
        public string last_plugin {
            owned get {
                return get_value (GROUP_PLUGINS, "last_plugin", "");
            }
            set {
                set_value (GROUP_PLUGINS, "last_plugin", value);
            }
        }
        /*---GROUP:Timer---------------------------------------------------------*/
        public int task_duration {
            owned get {
                var duration = get_value (GROUP_TIMER, "task_duration", "1500");
                return int.parse (duration);
            }
            set {
                set_value (GROUP_TIMER, "task_duration", value.to_string ());
                timer_duration_changed ();
            }
        }
        public int break_duration {
            owned get {
                var duration = get_value (GROUP_TIMER, "break_duration", "300");
                return int.parse (duration);
            }
            set {
                set_value (GROUP_TIMER, "break_duration", value.to_string ());
                timer_duration_changed ();
            }
        }
        public int reminder_time {
            owned get {
                var time = get_value (GROUP_TIMER, "reminder_time", "60");
                return int.parse (time);
            }
            set {
                set_value (GROUP_TIMER, "reminder_time", value.to_string ());
            }
        }
        public bool reminder_active {
            owned get {
                return (reminder_time > 0);
            }
        }
        /*---GROUP:UI-------------------------------------------------------------*/
        public int win_x {
            owned get {
                var x = get_value (GROUP_UI, "win_x", "-1");
                return int.parse (x);
            }
            set {
                set_value (GROUP_UI, "win_x", value.to_string ());
            }
        }
        public int win_y {
            owned get {
                var y = get_value (GROUP_UI, "win_y", "-1");
                return int.parse (y);
            }
            set {
                set_value (GROUP_UI, "win_y", value.to_string ());
            }
        }
        public int win_width {
            owned get {
                var width = get_value (GROUP_UI, "win_width", "350");
                return int.parse (width);
            }
            set {
                set_value (GROUP_UI, "win_width", value.to_string ());
            }
        }
        public int win_height {
            owned get {
                var height = get_value (GROUP_UI, "win_height", "650");
                return int.parse (height);
            }
            set {
                set_value (GROUP_UI, "win_height", value.to_string ());
            }
        }
        public bool use_header_bar {
            owned get {
                var use_header_bar = get_value (GROUP_UI, "use_header_bar", header_bar_default());
                return bool.parse (use_header_bar);
            }
            set {
                set_value (GROUP_UI, "use_header_bar", value.to_string ());
            }
        }
        
        /* Signals */
        public signal void timer_duration_changed ();
        
        /**
         * Constructs a SettingsManager object from a configuration file.
         * Reads the corresponding file and creates it, if necessary.
         */
        public SettingsManager.load_from_key_file () {
            // Instantiate the key_file object
            key_file = new KeyFile ();
            
            if (!FileUtils.test (Constants.Utils.config_file, FileTest.EXISTS)) {
                // Fill with default values, if it does not exist yet
                first_start = true;
            } else {
                // If it does exist, read existing values
                try {
                    key_file.load_from_file (Constants.Utils.config_file,
                       KeyFileFlags.KEEP_COMMENTS | KeyFileFlags.KEEP_TRANSLATIONS);
                } catch (Error e) {
                    stderr.printf("Reading %s failed", Constants.Utils.config_file);
                    error ("%s", e.message);
                }
            }
        }
        
        private string header_bar_default () {
            string desktop = Environment.get_variable ("DESKTOP_SESSION");
            
            switch (desktop) {
                case "ubuntu":
                    return "false";
                case "kde":
                    return "false";
                case "plasma":
                    return "false";
                default:
                    return "true";
            }
        }
        
        /**
         * Provides read access to a setting, given a certain group and key.
         * Public access is granted via the SettingsManager's attributes, so this
         * function has been declared private
         */
        private string get_value (string group, string key, string default = "") {
            try {
                // use key_file, if it has been assigned
                if (key_file != null
                    && key_file.has_group (group)
                    && key_file.has_key (group, key)) {
                        return key_file.get_value(group, key);
                } else {
                    return default;
                }
            } catch (Error e) {
                    error ("An error occured while reading the setting"
                        +" %s.%s: %s", group, key, e.message);
            }
        }
        
        /**
         * Provides write access to a setting, given a certain group key and value.
         * Public access is granted via the SettingsManager's attributes, so this
         * function has been declared private
         */
        private void set_value (string group, string key, string value) {
            if (key_file != null) {
                try {
                    key_file.set_value (group, key, value);
                    write_key_file ();
                } catch (Error e) {
                    error ("An error occured while setting the setting"
                        +" %s.%s to %s: %s", group, key, value, e.message);
                }
            }
        }
        
        /**
         * Function made for compability with older versions of GLib.
         */
        private void write_key_file () throws Error {
            key_file.save_to_file (Constants.Utils.config_file);
        }
    }
}
