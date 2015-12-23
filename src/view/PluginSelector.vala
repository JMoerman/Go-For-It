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
        
        public signal void plugin_selected (TodoPluginProvider plugin_provider);
        
        public PluginSelector () {
            setup_layout ();
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
        
        public void add_plugin (TodoPluginProvider plugin_provider) {
            var new_row = new PluginSelectorRow (plugin_provider);
            layout.add(new_row);
            
            new_row.clicked.connect ( () => {
                plugin_selected (new_row.plugin_provider);
            });
        }
        
        public void remove_plugin (TodoPluginProvider plugin_provider) {
            var plugins = layout.get_children();
            foreach (Gtk.Widget plugin in plugins) {
                if (((PluginSelectorRow)plugin).plugin_provider == plugin_provider) {
                    plugin.destroy ();
                    break;
                }
            }
        }
        
        /**
         * Removes all plugins.
         */
        public void reset () {
            var plugins = layout.get_children();
            foreach (Gtk.Widget plugin in plugins) {
                plugin.destroy ();
            }
            plugins = new GLib.List<PluginSelectorRow> ();
        }
        
        private int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
            if (((PluginSelectorRow) row1).plugin_provider.get_name () > ((PluginSelectorRow) row2).plugin_provider.get_name ())
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
        private GOFI.API.TodoPluginProvider _plugin_provider;
        
        public signal void clicked ();

        public PluginSelectorRow (GOFI.API.TodoPluginProvider plugin_provider) {
            _plugin_provider = plugin_provider;
            setup_layout ();
            connect_signals ();
            
            this.show_all ();
        }
        
        /**
         * Initializes GUI elements.
         */
        private void setup_layout () {
            layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            
            button = new Gtk.Button.with_label(plugin_provider.get_name ());
            
            layout.pack_start (button);
            
            this.add (layout);
        }
        
        private void connect_signals () {
            button.clicked.connect ( () => {
                clicked ();
            });
            _plugin_provider.removed.connect ( () => {
                destroy ();
            });
        }
        
        public GOFI.API.TodoPluginProvider plugin_provider {
            get { return _plugin_provider; }
        }
    }
}
