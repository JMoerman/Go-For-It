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
    public class PluginManager : GLib.Object {
    
        private Peas.Engine engine;
        private Peas.ExtensionSet exts;

        private SettingsManager settings;
        
        public Interface plugin_iface { private set; public get; }
        
        public weak MainWindow window;
        
        public PluginManager (MainWindow window, SettingsManager settings) {
            this.window = window;
            this.settings = settings;

            plugin_iface = new Interface (window);

            engine = Peas.Engine.get_default ();
            engine.enable_loader ("python");
            engine.enable_loader ("gjs");
            engine.add_search_path (Constants.PLUGINDIR, null);
            engine.set_loaded_plugins (settings.enabled_plugins);
            
            Parameter param = Parameter ();
            param.value = plugin_iface;
            param.name = "object";
            exts = new Peas.ExtensionSet (engine, typeof (Peas.Activatable), "object", plugin_iface, null);
        }
        
        public void load_plugins () {
            exts.foreach (on_extension_foreach);
            exts.extension_added.connect (on_extension_added);
            exts.extension_removed.connect (on_extension_removed);
        }
        
        public Gtk.Widget get_settings_widget () {
            return new PeasGtk.PluginManager (engine);
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
