namespace GOFI.DialogUtils {
    public const int SPACING_SETTINGS_ROW = 6;
    public const int SPACING_SETTINGS_COLUMN = 10;

    /**
     * Used to synchronize the width of the labels of settings options
     * This may not be the best way of doing this, but it is simple and it works
     */
    private class SynchronizedWCont {
        public List<SynchronizedWBin> controlled;
        public int current_width;
        public unowned SynchronizedWBin widest_widget;

        public SynchronizedWCont () {
            controlled = new List<SynchronizedWBin> ();
            current_width = 0;
            widest_widget = null;
        }

        public void update_width (SynchronizedWBin widget, int width) {
            if (current_width < width) {
                current_width = width;
                widest_widget = widget;

                queue_resize (widget);
            } else if (widest_widget == widget && current_width > width) {
                current_width = 0;
                refresh_current_width ();
                queue_resize (widget);
            }
        }

        private void refresh_current_width () {
            foreach (var widget in controlled) {
                if (widget.visible) {
                    var widget_width = widget.cached_natural_width;
                    if (widget_width > current_width) {
                        current_width = widget_width;
                        widest_widget = widget;
                    }
                }
            }
        }

        public void queue_resize (SynchronizedWBin? ignore) {
            foreach (var widget in controlled) {
                if (widget != ignore && widget.visible) {
                    widget.queue_resize ();
                }
            }
        }

        public void add (SynchronizedWBin widget) {
            controlled.prepend (widget);
        }

        public void remove (SynchronizedWBin widget) {
            bool was_widest = (widget == widest_widget);
            controlled.remove (widget);
            if (was_widest) {
                current_width = 0;
                foreach (var _widget in controlled) {
                    if (_widget.visible) {
                        var _widget_width = _widget.cached_natural_width;
                        if (_widget_width > current_width) {
                            current_width = _widget_width;
                            widest_widget = _widget;
                        }
                    }
                }
                queue_resize (null);
            }
        }
    }

    private class SynchronizedWBin : Gtk.Bin {
        public SynchronizedWCont width_controller {
            get {
                return controller;
            }
            set {
                controller.remove (this);
                controller = value;
                controller.add (this);
            }
        }
        SynchronizedWCont controller;
        public int cached_natural_width;

        public SynchronizedWBin (SynchronizedWCont controller) {
            this.controller = controller;
            width_controller.add (this);
            cached_natural_width = 0;
        }

        ~SynchronizedWBin () {
            width_controller.remove (this);
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void get_preferred_width (out int minimum_width, out int natural_width) {
            base.get_preferred_width (out minimum_width, out natural_width);
            width_controller.update_width (this, natural_width);
            cached_natural_width = natural_width;
            natural_width = int.max (width_controller.current_width, natural_width);
        }

        public override void size_allocate (Gtk.Allocation allocation) {
            int offset = allocation.width - controller.current_width;

            if (offset > 0) {
                allocation.x += offset;
                allocation.width = controller.current_width;
            }
            base.size_allocate (allocation);
        }

        public override void hide () {
            base.hide ();
            width_controller.update_width (this, 0);
        }
    }

    private class SynchronizedWLabel : SynchronizedWBin {
        public Gtk.Label label {
            get {
                return (Gtk.Label) this.get_child ();
            }
            set {
                remove (this.get_child ());
                this.add (value);
            }
        }

        public SynchronizedWLabel (SynchronizedWCont controller, string label) {
            base (controller);
            var lbl_widget = new Gtk.Label (label);
            lbl_widget.halign = Gtk.Align.END;
            this.add (lbl_widget);
        }
    }

    private Gtk.Label create_header_label (string label) {
#if USE_GRANITE
        return new Granite.HeaderLabel (label);
#else
        var lbl = new Gtk.Label ("<b>%s</b>".printf (label));
        lbl.use_markup = true;
        lbl.halign = Gtk.Align.START;
        return lbl;
#endif
    }

    private Gtk.Widget create_section_box (string? sect_title, Gtk.Widget contents) {
        contents.margin = 10;

        var section_frame = new Gtk.Frame (null);
        section_frame.add (contents);
        section_frame.get_style_context ().add_class ("settings-frame");

#if USE_GRANITE
        var section_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
#else
        var section_box = new Gtk.Box (Gtk.Orientation.VERTICAL, SPACING_SETTINGS_ROW);
#endif

        if (sect_title != null) {
            section_box.add (create_header_label (sect_title));
        }

        section_box.add (section_frame);
        return section_box;
    }

    private static void add_option (
        Gtk.Grid grid, ref int row, Gtk.Widget label, Gtk.Widget switcher,
        Gtk.Widget? label2 = null
    ) {
        label.halign = Gtk.Align.END;
        grid.attach (label, 0, row, 1, 1);

        switcher.halign = Gtk.Align.START;

        if (label2 != null) {
            label2.halign = Gtk.Align.START;
            label2.hexpand = true;
            grid.attach (switcher, 1, row, 1, 1);
            grid.attach (label2, 2, row, 1, 1);
        } else {
            if (switcher is Gtk.Switch || switcher is Gtk.Entry) {
                switcher.halign = Gtk.Align.START;
            } else {
                switcher.halign = Gtk.Align.FILL;
            }
            grid.attach (switcher, 1, row, 2, 1);
            switcher.hexpand = true;
        }
        row++;
    }

    private static void apply_grid_spacing (Gtk.Grid grid) {
        grid.row_spacing = SPACING_SETTINGS_ROW;
        grid.column_spacing = SPACING_SETTINGS_COLUMN;
    }

    private static Gtk.Grid create_page_grid () {
        var grid = new Gtk.Grid ();
        apply_grid_spacing (grid);
        return grid;
    }

    public static Gtk.Widget get_explanation_widget (string explanation) {
        var widget = new ExplanationWidget (explanation);
        widget.get_style_context ().add_class ("no-margin");
        return widget;
    }
}
