namespace GOFI.Plugins.Classic {
    public class TXTTask : GOFI.TodoTask {
        
        public Gtk.TreeRowReference reference;
        
        public TXTTask (string title, bool done, Gtk.TreeRowReference reference) {
            base (title, done);
            this.reference = reference;
        }
    }
}
