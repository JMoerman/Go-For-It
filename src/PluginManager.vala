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
using GOFI.Todo;

namespace GOFI {
    
    /**
     * PluginManager loads and controls all plugins.
     */
    public class PluginManager : GLib.Object {
    
        private Peas.Engine engine;
        private Peas.ExtensionSet exts;

        private SettingsManager settings;
        private Gee.HashMap<string, TodoPluginProvider> providers;
        
        public Interface plugin_iface { private set; public get; }
        
        public signal void todo_plugin_load (TodoPluginProvider provider);
        public signal void todo_plugin_added (TodoPluginProvider provider);
        public signal void todo_plugin_removed (TodoPluginProvider provider);
        
        /**
         * Constructor of PluginManager
         */
        public PluginManager (SettingsManager settings) {
            this.settings = settings;
            providers = new Gee.HashMap<string, TodoPluginProvider> ();

            plugin_iface = new Interface (this);

            engine = Peas.Engine.get_default ();
            engine.enable_loader ("python");
            engine.enable_loader ("gjs");
            engine.add_search_path (Constants.PLUGINDIR, null);
            engine.set_loaded_plugins (settings.enabled_plugins);
            
            Parameter param = Parameter ();
            param.value = plugin_iface;
            param.name = "object";
            exts = new Peas.ExtensionSet (engine, typeof (Peas.Activatable), "object", plugin_iface, null);
            load_plugins ();
        }
        
        /**
         * Activates the found plugins.
         */
        private void load_plugins () {
            exts.foreach (on_extension_foreach);
            exts.extension_added.connect (on_extension_added);
            exts.extension_removed.connect (on_extension_removed);
        }
        
        public Gtk.Widget get_settings_widget () {
            return new PeasGtk.PluginManager (engine);
        }
        
        /**
         * Adds plugin_provider to the known TodoPluginProviders.
         */
        public void add_plugin_provider (TodoPluginProvider plugin_provider) {
            providers.set (
                plugin_provider.plugin_info.get_module_name (), 
                plugin_provider
            );
            todo_plugin_added (plugin_provider);
            plugin_provider.removed.connect ( () => {
                todo_plugin_removed (plugin_provider);
            });
        }
        
        /**
         * Attempts to load the last uses TodoPlugin.
         */
        public bool load_last_todo_plugin () {
            string identifier = settings.last_plugin;
            return load_todo_plugin (identifier);
        }
        
        /**
         * Loads the specified TodoPlugin.
         */
        public bool load_todo_plugin (string identifier) {
            if (providers.has_key (identifier)) {
                todo_plugin_load (providers.get (identifier));
                settings.last_plugin = identifier;
                return true;
            }
            return false;
        }
        
        /**
         * Returns a list of available TodoPluginProvider instances.
         */
        public Gee.List<TodoPluginProvider> get_plugins () {
            var temp = new Gee.LinkedList<TodoPluginProvider> ();
            foreach (TodoPluginProvider provider in providers.values) {
                temp.add (provider);
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
        
        private void on_extension_foreach (Peas.ExtensionSet set, Peas.PluginInfo info, Peas.Extension extension) {
            ((Peas.Activatable)extension).activate ();
        }
        
        private void on_extension_added (Peas.PluginInfo info, Object extension) {
            ((Peas.Activatable)extension).activate ();
        }

        private void on_extension_removed (Peas.PluginInfo info, Object extension) {
            ((Peas.Activatable) extension).deactivate ();
        }
    }
}
