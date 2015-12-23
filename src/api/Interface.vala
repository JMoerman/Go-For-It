namespace GOFI.API {
    public class Interface : GLib.Object {
        private MainWindow window;
        
        public void register_launcher(TodoPluginProvider plugin_provider) {
            window.add_plugin_provider(plugin_provider);
        }
        
        public void remove_launcher(TodoPluginProvider plugin_provider) {
            //window.remove_plugin_provider(plugin_provider);
        }
        
        public Interface (MainWindow window) {
            this.window = window;
        }
    }
}
