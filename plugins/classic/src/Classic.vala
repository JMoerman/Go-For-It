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

namespace GOFI.Plugins.Classic {
    
    private SettingsManager _settings;
    
    public class ClassicPluginProvider : GOFI.TaskListProvider,
             PeasGtk.Configurable {
        
        private GLib.List<ClassicPlugin> lists;
        
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
            lists = new GLib.List<ClassicPlugin> ();
            lists.append (new ClassicPlugin (this.get_plugin_info (),settings));
        }
        
        public override void on_deactivate () {
            lists = null;
        }
        
        public Gtk.Widget create_configure_widget () {
            return new SettingsWidget (settings);
        }
        
        /**
         * 
         */
        public override Gtk.Widget get_creation_widget () {
            return new Gtk.Label ("WIP");
        }
        
        public override unowned GLib.List<GOFI.TaskList> get_lists () {
            return lists;
        }
    }
    
    public class ClassicPlugin : GOFI.TaskList {
        private TaskManager task_manager;
        private SettingsManager settings;
        
        private TaskList todo_list;
        private TaskList done_list;
        
        // Menu items for this plugin
        private Gtk.MenuItem clear_done_item;
        private GLib.List<Gtk.MenuItem> menu_items;
        
        private Gtk.TreeSelection todo_selection;
        
        public ClassicPlugin (Peas.PluginInfo plugin_info, 
                              SettingsManager settings)
        {
            base (plugin_info);
            this.settings = settings;
            
            this.name = "Classic";
        }
        
        public override void activate () {
            task_manager = new TaskManager(settings);
            
            setup_widgets ();
            setup_menu ();
            connect_signals ();
        }
        
        public override void deactivate () {
            active_task = null;
            selected_task = null;
            clear_done_item = null;
            todo_selection = null;
            todo_list = null;
            done_list = null;
            task_manager = null;
        }
        
        private void setup_widgets () {
            todo_list = new TaskList (this.task_manager.todo_store, true);
            done_list = new TaskList (this.task_manager.done_store, false);
            todo_selection = todo_list.task_view.get_selection ();
            if (active_task != null) {
                todo_selection.select_path (
                    ((TXTTask)active_task).reference.get_path ()
                );
            }
            
            /* 
             * If either the selection or the data itself changes, it is 
             * necessary to check if a different task is to be displayed
             * in the timer widget and thus todo_selection_changed is to be called
             */
            todo_selection.changed.connect (todo_selection_changed);
            task_manager.done_store.task_data_changed.connect (todo_selection_changed);
            // Call once to refresh view on startup
            todo_selection_changed ();
        }
        
        private void setup_menu () {
            /* Initialization */
            menu_items = new GLib.List<Gtk.MenuItem> ();
            clear_done_item = new Gtk.MenuItem.with_label (_("Clear Done List"));
            
            /* Add Items to Menu */
            menu_items.append (clear_done_item);
        }
        
        public static string tree_row_ref_to_task (Gtk.TreeRowReference reference) {
            // Get Gtk.TreeIterator from reference
            var path = reference.get_path ();
            var model = reference.get_model ();
            Gtk.TreeIter iter;
            model.get_iter (out iter, path);
            
            string description;
            model.get (iter, 1, out description, -1);
            return description;
        }
        
        private void todo_selection_changed () {
            Gtk.TreeModel model;
            Gtk.TreePath path;
            todo_selection = todo_list.task_view.get_selection ();
            
            // If no row has been selected, select the first in the list
            if (todo_selection.count_selected_rows () == 0) {
                todo_selection.select_path (new Gtk.TreePath.first ());
            }
            
            // Check if TodoStore is empty or not
            if (task_manager.todo_store.is_empty ()) {
                if (!task_manager.refreshing) {
                    cleared ();
                }
                return;
            }
            
            // Take the first selected row
            path = todo_selection.get_selected_rows (out model).nth_data (0);
            var reference = new Gtk.TreeRowReference (model, path);
            
            var task = new TXTTask(tree_row_ref_to_task(reference), false, reference);
            
            this.selected_task = task;
        }
        
        private void connect_signals () {
            todo_list.add_new_task.connect ( (task) => {
               task_manager.add_new_task (task); 
            });
            clear_done_item.activate.connect ((e) => {
                task_manager.clear_done_store ();
            });
            task_manager.refreshed.connect (on_refresh);
        }
        
        /**
         * Fix the TXTTask used by task_timer if necessary
         */
        private void on_refresh () {
            if (task_manager.fix_task ()) {
                return;
            } else {
                stdout.printf ("Unable to restore running task!\n");
                this.active_task = this.selected_task;
            }
        }
        
        public override void set_active_task_done () {
            active_task.done = true;
            task_manager.mark_task_done (active_task);
        }
        
        public override TodoTask? get_next () {
            return this.selected_task;
        }
        
        public override Gtk.Widget get_primary_widget (out string page_name) {
            page_name = _("To-Do");
            return todo_list;
        }
        
        public override Gtk.Widget get_secondary_widget (out string page_name) {
            page_name = _("Done");
            return done_list;
        }
        
        /**
         * List of menu items to be added to the application menu.
         */
        public override GLib.List<unowned Gtk.MenuItem> get_menu_items () {
            return menu_items.copy ();
        }
    }
}
    
[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (GOFI.Plugins.Classic.ClassicPluginProvider));
    objmodule.register_extension_type (typeof (PeasGtk.Configurable),
                                       typeof (GOFI.Plugins.Classic.ClassicPluginProvider));
}
