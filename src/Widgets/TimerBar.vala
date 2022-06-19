class GOFI.TimerBar : Gtk.ActionBar {
    private Gtk.Box layout;

    private TaskTimer timer;

    private Gtk.ProgressBar progress_bar;
    private Gtk.Label progress_label;
    private Gtk.Label title_label;
    private Gtk.Button start_button;
    private Gtk.Button skip_button;

    private Gtk.Button timer_page_button;

    private Gtk.Image start_icon;
    private Gtk.Image pause_icon;
    private Gtk.Image skip_icon;
    private Gtk.Stack start_button_stack;

    private Gtk.Grid top_layout;

    public signal void timer_page_btn_clicked ();

    public TimerBar(TaskTimer timer) {
        layout = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);

        this.timer = timer;
        setup_widgets ();

        timer.timer_updated.connect (set_time);
        timer.timer_started.connect (on_timer_started);
        timer.timer_stopped.connect (on_timer_stopped);
        timer.active_task_changed.connect (timer_active_task_changed);
        timer.timer_updated_relative.connect (on_timer_updated_relative);
        timer.active_task_description_changed.connect (update_description);

        timer_page_button.clicked.connect (() => timer_page_btn_clicked());
        start_button.clicked.connect (() => timer.toggle_running ());
        skip_button.clicked.connect (() => timer.end_iteration ());
    }

    private void setup_widgets () {
        progress_bar = new Gtk.ProgressBar ();
        progress_bar.hexpand = true;

        start_icon = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
        pause_icon = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
        skip_icon = new Gtk.Image.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.BUTTON);

        start_button_stack = new Gtk.Stack ();

        start_button = new Gtk.Button ();
        skip_button = new Gtk.Button ();
        timer_page_button = new Gtk.Button ();

        start_button_stack.add (start_icon);
        start_button_stack.add (pause_icon);
        start_button.add (start_button_stack);

        skip_button.add (skip_icon);

        title_label = new Gtk.Label (null);
        title_label.ellipsize = Pango.EllipsizeMode.END;
        title_label.hexpand = true;
        title_label.halign = Gtk.Align.START;
        progress_label = new Gtk.Label ("00:00 (0/0)");

        top_layout = new Gtk.Grid ();
        top_layout.column_spacing = 3;
        top_layout.orientation = Gtk.Orientation.HORIZONTAL;

        top_layout.add (title_label);
        top_layout.add (progress_label);

        skip_button.valign = Gtk.Align.CENTER;
        start_button.valign = Gtk.Align.CENTER;

        layout.pack_start(top_layout);
        layout.pack_end (progress_bar);
        timer_page_button.add (layout);
        timer_page_button.hexpand = true;

        pack_start (start_button);
        pack_start (timer_page_button);
        pack_end (skip_button);
    }

    private void set_time (uint timer_value) {
        uint hours, minutes, seconds;
        Utils.uint_to_time (timer_value, out hours, out minutes, out seconds);
        progress_label.label = Utils.seconds_to_separated_timer_string (timer_value);
    }

    private void on_timer_started () {
        start_button_stack.visible_child = pause_icon;
    }

    private void on_timer_stopped () {
        start_button_stack.visible_child = start_icon;
    }

    private void timer_active_task_changed (TodoTask? task) {
        if (task != null) {
            title_label.label = task.description;
        }
    }

    private void on_timer_updated_relative (double p) {

    }

    private void update_description (TodoTask task) {
        title_label.label = task.description;
    }
}
