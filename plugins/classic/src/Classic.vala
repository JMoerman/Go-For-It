using GOFI.API;
using GOFI.Todo;

namespace GOFI.Plugins.Classic {
    public class ClassicPluginProvider : Peas.ExtensionBase,  Peas.Activatable, 
            GOFI.API.TodoPluginProvider, PeasGtk.Configurable {
        
        GOFI.API.Interface plugins;
        public Object object { owned get; construct; }
        
        const string GETTEXT_PACKAGE = "go-for-it-classic";
        
        private SettingsManager settings;

        public void activate ()
        {
            plugins = (GOFI.API.Interface) object;
            
            Intl.setlocale(LocaleCategory.MESSAGES, "");
            Intl.textdomain(GETTEXT_PACKAGE); 
            Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8"); 
            Intl.bindtextdomain(GETTEXT_PACKAGE, "./locale");
            
            settings = new SettingsManager.load_from_key_file ();
            
            plugins.register_launcher (this);
        }

        public void deactivate () {
            this.removed ();
        }
        
        public void update_state () {

        }
        
        public Gtk.Widget create_configure_widget () {
            return new SettingsWidget (settings);
        }
        
        public string get_name () {
            return "Classic";
        }
        
        public TodoPlugin get_plugin (TaskTimer timer) {
            return new ClassicPlugin (timer, settings);
        }
    }
    
    public class ClassicPlugin : TodoPlugin {
        private TaskManager task_manager;
        private SettingsManager settings;
        
        private TaskList todo_list;
        private TaskList done_list;
        
        // Menu items for this plugin
        private Gtk.MenuItem clear_done_item;
        private Gtk.MenuItem refresh_item;
        
        private Gtk.TreeSelection todo_selection;
        
        public ClassicPlugin (TaskTimer timer, SettingsManager settings) {
            base (timer);
            this.settings = settings;
            task_manager = new TaskManager(settings);
            this.task_timer.active_task_done.connect (task_manager.mark_task_done);
            
            setup_widgets ();
            setup_menu ();
            connect_signals ();
        }
        
        private void setup_widgets () {
            todo_list = new TaskList (this.task_manager.todo_store, true);
            done_list = new TaskList (this.task_manager.done_store, false);
            todo_selection = todo_list.task_view.get_selection ();
            var active_task = (TXTTask)task_timer.active_task;
            if (active_task != null)
                todo_selection.select_path (active_task.reference.get_path ());
            
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
            clear_done_item = new Gtk.MenuItem.with_label (_("Clear Done List"));
            refresh_item = new Gtk.MenuItem.with_label (_("Refresh"));
            
            /* Add Items to Menu */
            menu_items.append (clear_done_item);
            menu_items.append (refresh_item);
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
                cleared ();
                return;
            }
            
            // Take the first selected row
            path = todo_selection.get_selected_rows (out model).nth_data (0);
            var reference = new Gtk.TreeRowReference (model, path);
            this.task_timer.active_task = new TXTTask(tree_row_ref_to_task(reference), false, reference);
        }
        
        private void connect_signals () {
            todo_list.add_new_task.connect ( (task) => {
               task_manager.add_new_task (task); 
            });
            clear_done_item.activate.connect ((e) => {
                task_manager.clear_done_store ();
            });
            refresh_item.activate.connect ((e) => {
                task_manager.refresh ();
            });
        }
        
        public override void stop () {
            //task_manager.save_tasks ();
        }
        
        public override Gtk.Widget get_primary_widget (out string page_name) {
            page_name = _("To-Do");
            return todo_list;
        }
        
        public override Gtk.Widget get_secondary_widget (out string page_name) {
            page_name = _("Done");
            return done_list;
        }
    }
}
    
[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                       typeof (GOFI.Plugins.Classic.ClassicPluginProvider));
//    objmodule.register_extension_type (typeof (PeasGtk.Configurable),
//                                       typeof (GOFI.Plugins.Classic.ClassicPluginProvider));
}
