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

using GOFI;

namespace GOFI.Application {
    
    private class TaskListCollection {
        private TaskListProvider provider;
        private GLib.List<TaskList> lists;
        
        public string module_name {
            get {
                return provider.plugin_info.get_module_name ();
            }
        }
        
        public virtual signal void remove () {
            foreach (TaskList list in lists) {
                list.remove ();
            }
        }
        
        public signal void new_list_added (TaskList list);
        
        public TaskListCollection (TaskListProvider provider) {
            this.provider = provider;
            foreach (TaskList list in provider.get_lists ()) {
                lists.append (list);
            }
            provider.list_removed.connect ( (list) => {
                lists.remove (list);
            });
        }
        
        public TaskList? get_list_by_name (string name) {
            foreach (TaskList list in lists) {
                if (list.name == name) {
                    return list;
                }
            }
            return null;
        }
        
        public GLib.List<TaskList> get_lists () {
            return lists.copy ();
        }
    }
    
    /**
     * PluginManager loads and controls all plugins.
     */
    public class PluginManager : GLib.Object {
    
        private Peas.Engine engine;
        private Peas.ExtensionSet exts;

        private SettingsManager settings;
        private Gee.HashMap<string, TaskListCollection> list_collections;
        
        public Interface plugin_iface { private set; public get; }
        
        public TaskTimer timer;
        
        public signal void task_lists_added (GLib.List<TaskList> task_lists);
        
        /**
         * Constructor of PluginManager
         */
        public PluginManager (SettingsManager settings, TaskTimer timer) {
            this.settings = settings;
            this.timer = timer;
            list_collections = new Gee.HashMap<string, TaskListCollection> ();

            plugin_iface = new Interface (this);

            engine = Peas.Engine.get_default ();
            engine.add_search_path (Constants.PLUGINDIR, null);
            engine.set_loaded_plugins (settings.enabled_plugins);
            
            Parameter param = Parameter ();
            param.value = plugin_iface;
            param.name = "object";
            exts = new Peas.ExtensionSet (engine, typeof (Peas.Activatable), 
                "object", plugin_iface, null);
            load_plugins ();
            connect_signals ();
        }
        
        /**
         * Activates the found plugins.
         */
        private void load_plugins () {
            exts.foreach (on_extension_foreach);
            exts.extension_added.connect (on_extension_added);
            exts.extension_removed.connect (on_extension_removed);
        }
        
        private void connect_signals () {
            timer.timer_updated.connect ( (remaining_duration) => {
                plugin_iface.timer_updated (remaining_duration);
            });
            timer.timer_updated_relative.connect ( (progress) => {
                plugin_iface.timer_updated_relative (progress);
            });
            timer.timer_running_changed.connect ( (running) => {
                plugin_iface.timer_running_changed (running);
            });
            timer.timer_almost_over.connect ( (remaining_duration) => {
                plugin_iface.timer_almost_over (remaining_duration);
            });
            timer.timer_finished.connect ( (break_active) => {
                plugin_iface.timer_finished (break_active);
            });
        }
        
        public Gtk.Widget get_settings_widget () {
            return new PeasGtk.PluginManager (engine);
        }
        
        /**
         * Adds plugin_provider to the known TodoPluginProviders.
         */
        public void add_task_provider (TaskListProvider task_provider) {
            TaskListCollection collection;
            Peas.PluginInfo plugin_info = task_provider.get_plugin_info();
            string plugin_name = plugin_info.get_module_name();
            
            if (!list_collections.has_key (plugin_name)) {
                collection = new TaskListCollection (task_provider);
                list_collections.set (plugin_name, collection);
                task_lists_added (collection.get_lists ());
                collection.remove.connect_after (on_collection_remove);
            }
        }
        
        private void on_collection_remove (TaskListCollection collection) {
            list_collections.unset (collection.module_name);
        }
        
        /**
         * Attempts to load the last used TaskList.
         */
        public TaskList? get_last_opened_list () {
            string[] names = settings.last_list;
            if (names.length == 2) {
                return get_list_by_name (names[0], names[1]);
            }
            return null;
        }
        
        public TaskList? get_list_by_name (string plugin_name, string list_name) {
            TaskListCollection collection;
            
            collection = list_collections.get(plugin_name);
            if (collection != null) {
                return collection.get_list_by_name (list_name);
            }
            return null;
        }
        
        /**
         * Returns a list of available TodoPluginProvider instances.
         */
        public GLib.List<TaskList> get_lists () {
            var temp = new GLib.List<TaskList> ();
            foreach (TaskListCollection collection in list_collections.values) {
                temp.concat (collection.get_lists());
            }
            return temp;
        }
        
        /**
         * Cant call this from on_extension_removed, as loaded_plugins is 
         * updated after giving off the extension_removed signal.
         */
        public void save_loaded () {
            settings.enabled_plugins = engine.get_loaded_plugins ();
        }
        
        private void on_extension_foreach (Peas.ExtensionSet set, 
                                           Peas.PluginInfo info, 
                                           Peas.Extension extension)
        {
            ((Peas.Activatable)extension).activate ();
        }
        
        private void on_extension_added (Peas.PluginInfo info, 
                                         Object extension)
        {
            ((Peas.Activatable)extension).activate ();
        }

        private void on_extension_removed (Peas.PluginInfo info, 
                                           Object extension) 
        {
            ((Peas.Activatable) extension).deactivate ();
        }
    }
}
