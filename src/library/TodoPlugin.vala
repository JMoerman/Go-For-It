/* Copyright 2016 Go For It! developers
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
    public abstract class TaskListProvider : Peas.ExtensionBase,  
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
         * Signal that is emited when this gets unloaded.
         */
        public signal void removed ();
        
        /**
         * ...
         */
        public signal void list_removed (TaskList list);
        
        /**
         * ...
         */
        public signal void list_added (TaskList list);
        
        /**
         * Implementation of Peas.Activatable.activate, this function should 
         * only be called by the main application.
         */
        public void activate () {
            plugin_iface = (Interface) object;
            on_activate ();
            plugin_iface.register_task_provider (this);
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
         * Function called when a TodoPluginProvider gets deactivated.
         */
        public abstract void on_deactivate ();
        
        /**
         * Function called when a TodoPluginProvider gets activated.
         */
        public abstract void on_activate ();
        
        /**
         * 
         */
        public abstract Gtk.Widget get_creation_widget ();
        
        public abstract unowned GLib.List<TaskList> get_lists ();
    }
    
    /**
     * This class is responsible for managing tasks and controlling the 
     * TaskTimer.
     */
    public abstract class TaskList : GLib.Object {
        public string name {
            public get;
            public set;
        }
        
        public string plugin_name {
            public get {
                return plugin_info.get_name ();
            }
        }
        
        public Peas.PluginInfo plugin_info {
            public get;
            construct set;
        }
        
        /**
         * TaskTimer for controlling the TimerView in MainLayout.
         */
        protected TaskTimer task_timer;
        
        /**
         * Signal that is emited when there are no tasks left.
         */
        public signal void cleared ();
        
        /**
         * 
         */
        public signal void remove ();
        
        /**
         * Constructor of TodoPlugin, should always be called by sub classes.
         */
        public TaskList (Peas.PluginInfo plugin_info) {
            this.plugin_info = plugin_info;
        }
        
        /**
         * ...
         */
        public abstract void activate (TaskTimer timer);
        
        /**
         * A function called when this TodoPlugin is about to get removed from 
         * the application. Stops all activity and saves all tasks.
         */
        public abstract void deactivate ();
        
        /**
         * List of menu items to be added to the application menu.
         */
        public virtual GLib.List<unowned Gtk.MenuItem> get_menu_items () {
            return new GLib.List<unowned Gtk.MenuItem> ();
        }
        
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
