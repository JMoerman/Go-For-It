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

using GOFI.Todo;

namespace GOFI.API {
    
    public interface TodoPluginProvider : GLib.Object {
        
        public signal void removed (); 
        
        public abstract string get_name ();
        
        public abstract TodoPlugin get_plugin (TaskTimer timer);
    }
    
    public abstract class TodoPlugin : GLib.Object {
        
        protected TaskTimer task_timer;
        protected List<Gtk.MenuItem> menu_items;
        
        public signal void cleared ();
        
        public TodoPlugin (TaskTimer timer) {
            this.task_timer = timer;
            this.menu_items = new List<Gtk.MenuItem> ();
        }
        
        public List<Gtk.MenuItem> get_menu_items () {
            return menu_items.copy ();
        }
        
        public abstract void stop ();
        
        public abstract Gtk.Widget get_primary_widget (out string page_name);
        
        public abstract Gtk.Widget get_secondary_widget (out string page_name);
    }
}
