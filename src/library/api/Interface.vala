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

namespace GOFI.API {
    
    /**
     * Interface to be used by plugins.
     */
    public class Interface : GLib.Object {
        
        private weak PluginManager plugin_manager;
        
        /**
         * The timer_updated signal is emitted when ...
         */
        public signal void timer_updated (DateTime remaining_duration);
        
        /**
         * The timer_updated_relative signal is emitted when the ...
         */
        public signal void timer_updated_relative (double progress);
        
        /**
         * The timer_running_changed signal is emitted when the timer is either
         * stopped or started.
         */
        public signal void timer_running_changed (bool running);
        
        /**
         * The timer_almost_over signal is emitted when ...
         */
        public signal void timer_almost_over (DateTime remaining_duration);
        
        /**
         * The timer_finished signal is emitted when ...
         */
        public signal void timer_finished (bool break_active);
        
        public Interface (PluginManager plugin_manager) {
            this.plugin_manager = plugin_manager;
        }
        
        /**
         * Adds a TodoPluginProvider to the list of known the list of available 
         * TodoPluginProvider instances.
         */
        public void register_launcher (TodoPluginProvider plugin_provider) {
            plugin_manager.add_plugin_provider(plugin_provider);
        }
        
        /**
         * Returns a location to store plugin related configuration files in.
         */
        public static string config_dir{
            owned get {
                string config_dir = Constants.Utils.config_dir;
                return Path.build_filename (config_dir, "plugins");
            }
        }
    }
}
