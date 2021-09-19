/**
 * Restricts the maximum natural_width value in height for width layouts
 */
private class ConstrWidthBin : Gtk.Bin {
    public int max_width {
        get { return _max_width; }
        set {
            _max_width = value;
            queue_resize ();
        }
    }
    int _max_width;

    public ConstrWidthBin (Gtk.Widget child, int max_width) {
        Object (child: child);
        this.max_width = max_width;
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);
        natural_width = int.min (max_width, natural_width);
    }
}
