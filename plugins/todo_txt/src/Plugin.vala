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

namespace GOFI.Plugins.TodoTXT {
    
    private SettingsManager _settings;
    
    /**
     * ...
     */
    public class TXTPluginProvider : GOFI.TodoPluginProvider {
        
        private SettingsManager settings {
            get {
                if (_settings == null) {
                    _settings = new SettingsManager.load_from_key_file ();
                }
                return _settings;
            }
            set {
                _settings = value;
            }
        }

        public override void on_activate () {
            
        }
        
        public override void on_deactivate () {
            
        }
        
        public override TodoPlugin get_plugin (TaskTimer timer) {
            return new TXTPlugin (timer, settings);
        }
    }
    
    /**
     * ...
     */
    public class TXTPlugin : TodoPlugin {
        
        private SettingsManager settings;
        private TaskManager task_manager;
        
        private TodoView todo_list_view;
        private DoneView done_list_view;
        
        public TXTPlugin (TaskTimer timer, SettingsManager settings) {
            base (timer);
            
            this.settings = settings;
            task_manager = new TaskManager (settings);
            setup_widgets ();
            connect_signals ();
        }
        
        private void setup_widgets () {
            todo_list_view = new TodoView ();
            done_list_view = new DoneView ();
            
            bind_models ();
        }
        
        private void connect_signals () {
            task_manager.refreshed.connect (bind_models);
            todo_list_view.task_selected.connect ( (task) => {
                this.task_timer.active_task = task;
                this.task_manager.active_task = task;
            });
            
            task_manager.active_task_completed.connect (() => {
                task_timer.remove_task ();
            });
        }
        
        private void bind_models () {
            todo_list_view.set_store (task_manager.todo_store);
            done_list_view.set_store (task_manager.done_store);
        }
        
        public override void stop () {
            if (task_timer.active_task != null) {
                task_timer.remove_task ();
            }
        }
        
        public override Gtk.Widget get_primary_widget (out string page_name) {
            page_name = _("To-Do");
            return todo_list_view;
        }
        
        public override Gtk.Widget get_secondary_widget (out string page_name) {
            page_name = _("Done");
            return done_list_view;
        }
    }
}
    
[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (GOFI.Plugins.TodoTXT.TXTPluginProvider));
}
