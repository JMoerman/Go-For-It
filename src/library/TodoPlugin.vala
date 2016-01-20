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
     * A TodoPluginProvider provides a TodoPlugin when it is needed.
     */
    public abstract class TodoPluginProvider : Peas.ExtensionBase,  
            Peas.Activatable {
        
        /**
         * The plugin interface, an allias of object.
         */
        public Interface plugin_iface;
        
        /**
         * The plugin interface.
         */
        public Object object { owned get; construct; }
        
        /**
         * Implementation of Peas.Activatable.activate, this function should 
         * only be called by the main application.
         */
        public void activate () {
            plugin_iface = (Interface) object;
            on_activate ();
            plugin_iface.register_launcher (this);
        }
        
        /**
         * Implementation of Peas.Activatable.deactivate, this function should 
         * only be called by the main application.
         */
        public void deactivate () {
            on_deactivate ();
            this.removed ();
        }
        
        /**
         * Implementation of Peas.Activatable.update_state, this function should 
         * only be called by the main application.
         */
        public void update_state () {

        }
        
        /**
         * Signal that is emited when this gets unloaded.
         */
        public signal void removed (); 
        
        /**
         * Returns a new TodoPlugin.
         */
        public abstract TodoPlugin get_plugin (TaskTimer timer);
        
        /**
         * Function called when a TodoPluginProvider gets deactivated.
         */
        public abstract void on_deactivate ();
        
        /**
         * Function called when a TodoPluginProvider gets activated.
         */
        public abstract void on_activate ();
    }
    
    /**
     * This class is responsible for managing tasks and controlling the 
     * TaskTimer.
     */
    public abstract class TodoPlugin : GLib.Object {
        
        /**
         * TaskTimer for controlling the TimerView in MainLayout.
         */
        protected TaskTimer task_timer;
        
        /**
         * List of menu items to be added to the application menu.
         */
        protected Gee.List<Gtk.MenuItem> menu_items;
        
        /**
         * Signal that is emited when there are no tasks left.
         */
        public signal void cleared ();
        
        /**
         * Constructor of TodoPlugin, should always be called by sub classes.
         */
        public TodoPlugin (TaskTimer timer) {
            this.task_timer = timer;
            this.menu_items = new Gee.LinkedList<Gtk.MenuItem> ();
        }
        
        /**
         * Returns a list of menu_items.
         */
        public Gee.List<Gtk.MenuItem> get_menu_items () {
            return menu_items;
        }
        
        /**
         * A function called when this TodoPlugin is about to get removed from 
         * the application. Stops all activity and saves all tasks.
         */
        public abstract void stop ();
        
        /**
         * Primary widget showing all tasks that need to be done.
         */
        public abstract Gtk.Widget get_primary_widget (out string page_name);
        
        /**
         * Secondary widget that can be used for things like showing all tasks
         * that have been done.
         */
        public abstract Gtk.Widget get_secondary_widget (out string page_name);
    }
}
