namespace GOFI.API {
    public class Interface : GLib.Object {
        private MainWindow window;
        
        public void register_launcher(TodoPluginProvider plugin_provider) {
            window.add_plugin_provider(plugin_provider);
        }
        
        public static string config_dir{
            owned get {
                string config_dir = Constants.Utils.config_dir;
                return Path.build_filename (config_dir, "plugins");
            }
        }
        
        public Interface (MainWindow window) {
            this.window = window;
        }
    }
}
