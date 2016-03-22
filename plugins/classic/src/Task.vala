namespace GOFI.Plugins.Classic {
    public class TXTTask : GOFI.TodoTask {
        
        public Gtk.TreeRowReference reference;
        
        public TXTTask (string title, bool done, Gtk.TreeRowReference reference) {
            base ();
            this.title = title;
            this.done = done;
            this.reference = reference;
        }
        
        public override bool is_valid () {
            if (base.is_valid ()) {
                return reference.valid ();
            }
            return false;
        }
        
    }
}
