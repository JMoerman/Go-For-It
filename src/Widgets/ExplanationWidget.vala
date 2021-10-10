public class GOFI.ExplanationWidget : Gtk.Button {
    private Gtk.Popover explanation_popover;
    private Gtk.Label popover_label;

    // To avoid clipping
    private ConstrWidthBin popover_contents;

    public string explanation {
        get {
            return popover_label.label;
        }
        set {
            popover_label.label = value;
            this.tooltip_text = value;
        }
    }

    public ExplanationWidget (string explanation) {
        Object (relief: Gtk.ReliefStyle.NONE, tooltip_text: explanation);
        var image_widget = new Gtk.Image.from_icon_name (
            "dialog-information-symbolic", Gtk.IconSize.BUTTON
        );
        image_widget.show ();
        this.add (image_widget);

        this.clicked.connect (on_clicked);
    }

    private void create_popover () {
        explanation_popover = new Gtk.Popover (this);
        popover_label = new Gtk.Label (this.tooltip_text);
        popover_label.wrap = true;
        popover_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        popover_label.margin = 10;
        popover_label.show ();

        popover_contents = new ConstrWidthBin (popover_label, 200);
        explanation_popover.add (popover_contents);
    }

    private void on_clicked () {
        var window = this.get_toplevel () as Gtk.Window;
        if (explanation_popover == null) {
            create_popover ();
        }
        int max_width = 200;
        if (window != null) {
            max_width = window.get_child ().get_allocated_width ();
        }
        popover_contents.max_width = max_width;
        Utils.popover_show (explanation_popover);
    }
}
