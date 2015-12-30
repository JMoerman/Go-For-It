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

using GOFI.API;

namespace GOFI {
    
    /**
     * A list of available plugins the user can choose from.
     */
    public class PluginSelector : Gtk.ScrolledWindow {
        
        private Gtk.ListBox layout;
        private Gtk.Label place_holder;
        private PluginManager plugin_manager;
        
        public PluginSelector (PluginManager plugin_manager) {
            this.plugin_manager = plugin_manager;
            setup_layout ();
            update ();
            plugin_manager.todo_plugin_added.connect ( (provider) => {
                add_plugin (provider);
            });
        }
        
        private void setup_layout () {
            layout = new Gtk.ListBox ();
            layout.set_sort_func(sort_func);
            layout.expand = true;
            
            place_holder = new Gtk.Label ("No plugins are currently loaded");
            // else it won't be shown, even if this.show_all () is called.
            place_holder.show ();
            
            layout.set_placeholder (place_holder);
            
            this.add (layout);
        }
        
        public void update () {
            reset ();
            var plugins = plugin_manager.get_plugins ();
            foreach (TodoPluginProvider plugin_provider in plugins) {
                add_plugin (plugin_provider);
            }
        }
        
        public void add_plugin (TodoPluginProvider plugin_provider) {
            var new_row = new PluginSelectorRow (plugin_provider.plugin_info);
            layout.add(new_row);
            
            new_row.clicked.connect ( () => {
                plugin_manager.load_todo_plugin (new_row.plugin_info.get_module_name ());
            });
            plugin_provider.removed.connect ( () => {
                new_row.destroy ();
            });
        }
        
        /**
         * Removes all plugins.
         */
        public void reset () {
            var plugins = layout.get_children();
            foreach (Gtk.Widget plugin in plugins) {
                plugin.destroy ();
            }
        }
        
        private int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
            if (((PluginSelectorRow) row1).plugin_info.get_name () > ((PluginSelectorRow) row2).plugin_info.get_name ())
                return 1;
            return -1;
        }
    }
    
    /**
     * A row in PluginSelector, used to select a TodoPlugin to load, also stores
     * a TodoPluginProvider for the timebeing.
     */
    class PluginSelectorRow : Gtk.ListBoxRow {
        private Gtk.Box layout;
        
        private Gtk.Button button;
        public Peas.PluginInfo plugin_info;
        
        public signal void clicked ();

        public PluginSelectorRow (Peas.PluginInfo plugin_info) {
            this.plugin_info = plugin_info;
            setup_layout ();
            connect_signals ();
            
            this.show_all ();
        }
        
        /**
         * Initializes GUI elements.
         */
        private void setup_layout () {
            layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            
            button = new Gtk.Button.with_label(plugin_info.get_name ());
            
            layout.pack_start (button);
            
            this.add (layout);
        }
        
        private void connect_signals () {
            button.clicked.connect ( () => {
                clicked ();
            });
        }
    }
}
